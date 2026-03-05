import NetworkExtension
import SwiftData
import Foundation

class PacketTunnelProvider: NEPacketTunnelProvider {

    private var modelContainer: ModelContainer? {
        try? ModelContainer(
            for: DomainRecord.self, ComplianceEvent.self,
            configurations: ModelConfiguration(
                groupContainer: .identifier(AppConstants.appGroupID)
            )
        )
    }

    private let dnsServerAddress = "1.1.1.1" // Cloudflare DNS as upstream
    private var pendingDomains: Set<String> = []
    private let domainQueue = DispatchQueue(label: "com.bettrfamily.domainlog")
    private var udpSession: NWUDPSession?

    // MARK: - Tunnel Lifecycle

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let settings = createTunnelSettings()

        setTunnelNetworkSettings(settings) { [weak self] error in
            if let error {
                completionHandler(error)
                return
            }
            // Create UDP session to real DNS server for forwarding queries
            self?.udpSession = self?.createUDPSession(to: NWHostEndpoint(hostname: "1.1.1.1", port: "53"), from: nil)
            self?.startReadingPackets()
            completionHandler(nil)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        udpSession?.cancel()
        udpSession = nil
        completionHandler()
    }

    // MARK: - Network Settings

    private func createTunnelSettings() -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: dnsServerAddress)

        // DNS settings — intercept DNS queries
        let dnsSettings = NEDNSSettings(servers: ["198.18.0.1"]) // fake local DNS
        dnsSettings.matchDomains = [""] // match all domains
        settings.dnsSettings = dnsSettings

        // IPv4 settings — route only DNS traffic through tunnel
        let ipv4 = NEIPv4Settings(addresses: ["198.18.0.1"], subnetMasks: ["255.255.255.0"])
        // Only route DNS through tunnel, not all traffic
        ipv4.includedRoutes = [NEIPv4Route(destinationAddress: "198.18.0.1", subnetMask: "255.255.255.255")]
        settings.ipv4Settings = ipv4

        return settings
    }

    // MARK: - Packet Reading

    private func startReadingPackets() {
        packetFlow.readPackets { [weak self] packets, protocols in
            self?.handlePackets(packets, protocols: protocols)
            self?.startReadingPackets() // continue reading
        }
    }

    private func handlePackets(_ packets: [Data], protocols: [NSNumber]) {
        for (index, packet) in packets.enumerated() {
            if let domain = extractDNSQuery(from: packet) {
                logDomain(domain, queryType: "DNS")
                // Forward DNS query to real DNS server and relay response
                forwardDNSQuery(originalPacket: packet, protocol: protocols[index])
            } else {
                if let domain = extractSNI(from: packet) {
                    logDomain(domain, queryType: "SNI")
                }
                // Non-DNS packets: write back so the system handles them normally
                packetFlow.writePackets([packet], withProtocols: [protocols[index]])
            }
        }
    }

    // MARK: - DNS Forwarding

    private func forwardDNSQuery(originalPacket: Data, protocol proto: NSNumber) {
        guard let udpSession else {
            // No session — pass packet through as-is
            packetFlow.writePackets([originalPacket], withProtocols: [proto])
            return
        }

        let ipHeaderLength = Int(originalPacket[0] & 0x0F) * 4
        let udpStart = ipHeaderLength
        let dnsPayload = originalPacket.subdata(in: (udpStart + 8)..<originalPacket.count)

        udpSession.writeDatagram(dnsPayload) { error in
            if let error {
                NSLog("BettrFamily DNS forward error: \(error)")
                return
            }
        }

        udpSession.setReadHandler({ [weak self] datagrams, error in
            guard let self, let datagrams, let responseDNS = datagrams.first else { return }

            // Build a UDP/IP response packet from the DNS response
            if let responsePacket = self.buildDNSResponsePacket(
                originalPacket: originalPacket,
                dnsResponse: responseDNS
            ) {
                self.packetFlow.writePackets([responsePacket], withProtocols: [proto])
            }
        }, maxDatagrams: 1)
    }

    private func buildDNSResponsePacket(originalPacket: Data, dnsResponse: Data) -> Data? {
        let ipHeaderLength = Int(originalPacket[0] & 0x0F) * 4

        // Extract original IP src/dst and UDP src port to build the reply
        let origSrcIP = originalPacket.subdata(in: 12..<16)
        let origDstIP = originalPacket.subdata(in: 16..<20)
        let udpStart = ipHeaderLength
        let origSrcPort = originalPacket.subdata(in: udpStart..<(udpStart + 2))
        let origDstPort = originalPacket.subdata(in: (udpStart + 2)..<(udpStart + 4))

        let udpLength = UInt16(8 + dnsResponse.count)
        let totalLength = UInt16(ipHeaderLength + Int(udpLength))

        // Build IP header (copy original, swap src/dst, update length)
        var ipHeader = Data(originalPacket.prefix(ipHeaderLength))
        ipHeader[2] = UInt8(totalLength >> 8)
        ipHeader[3] = UInt8(totalLength & 0xFF)
        // Swap src and dst IP
        ipHeader.replaceSubrange(12..<16, with: origDstIP)
        ipHeader.replaceSubrange(16..<20, with: origSrcIP)
        // Zero out checksum, then recalculate
        ipHeader[10] = 0
        ipHeader[11] = 0
        let checksum = ipChecksum(ipHeader)
        ipHeader[10] = UInt8(checksum >> 8)
        ipHeader[11] = UInt8(checksum & 0xFF)

        // Build UDP header (swap ports, set length, zero checksum)
        var udpHeader = Data(count: 8)
        udpHeader.replaceSubrange(0..<2, with: origDstPort) // src port = original dst
        udpHeader.replaceSubrange(2..<4, with: origSrcPort) // dst port = original src
        udpHeader[4] = UInt8(udpLength >> 8)
        udpHeader[5] = UInt8(udpLength & 0xFF)
        udpHeader[6] = 0 // checksum (optional for IPv4 UDP)
        udpHeader[7] = 0

        return ipHeader + udpHeader + dnsResponse
    }

    private func ipChecksum(_ header: Data) -> UInt16 {
        var sum: UInt32 = 0
        let count = header.count
        var i = 0
        while i < count - 1 {
            sum += UInt32(header[i]) << 8 | UInt32(header[i + 1])
            i += 2
        }
        if count % 2 != 0 {
            sum += UInt32(header[count - 1]) << 8
        }
        while sum >> 16 != 0 {
            sum = (sum & 0xFFFF) + (sum >> 16)
        }
        return ~UInt16(sum & 0xFFFF)
    }

    // MARK: - DNS Parsing

    private func extractDNSQuery(from packet: Data) -> String? {
        // Minimum IP header + UDP header + DNS header = 20 + 8 + 12 = 40 bytes
        guard packet.count > 40 else { return nil }

        // Check IP protocol (byte 9) is UDP (17)
        guard packet[9] == 17 else { return nil }

        let ipHeaderLength = Int(packet[0] & 0x0F) * 4

        // Check UDP destination port is 53 (DNS)
        let udpStart = ipHeaderLength
        guard packet.count > udpStart + 4 else { return nil }

        let destPort = UInt16(packet[udpStart + 2]) << 8 | UInt16(packet[udpStart + 3])
        guard destPort == 53 else { return nil }

        // Parse DNS query
        let dnsStart = udpStart + 8 // UDP header is 8 bytes
        guard packet.count > dnsStart + 12 else { return nil }

        // Question count (bytes 4-5 of DNS header)
        let questionCount = UInt16(packet[dnsStart + 4]) << 8 | UInt16(packet[dnsStart + 5])
        guard questionCount > 0 else { return nil }

        // Parse domain name starting at DNS header + 12
        return parseDNSName(from: packet, offset: dnsStart + 12)
    }

    private func parseDNSName(from data: Data, offset: Int) -> String? {
        var labels: [String] = []
        var position = offset

        while position < data.count {
            let length = Int(data[position])
            if length == 0 { break }

            // Check for DNS compression pointer
            if length & 0xC0 == 0xC0 { break }

            position += 1
            guard position + length <= data.count else { return nil }

            let labelData = data[position..<position + length]
            guard let label = String(data: labelData, encoding: .utf8) else { return nil }
            labels.append(label)
            position += length
        }

        let domain = labels.joined(separator: ".")
        return domain.isEmpty ? nil : domain
    }

    // MARK: - TLS SNI Extraction

    private func extractSNI(from packet: Data) -> String? {
        // Check for TCP (protocol 6)
        guard packet.count > 40, packet[9] == 6 else { return nil }

        let ipHeaderLength = Int(packet[0] & 0x0F) * 4
        let tcpStart = ipHeaderLength
        guard packet.count > tcpStart + 20 else { return nil }

        // Check destination port is 443 (HTTPS)
        let destPort = UInt16(packet[tcpStart]) << 8 | UInt16(packet[tcpStart + 1])
        guard destPort == 443 else { return nil }

        let tcpHeaderLength = Int((packet[tcpStart + 12] >> 4)) * 4
        let tlsStart = tcpStart + tcpHeaderLength

        guard packet.count > tlsStart + 5 else { return nil }

        // Check TLS handshake (0x16) and ClientHello (0x01)
        guard packet[tlsStart] == 0x16 else { return nil }

        let handshakeStart = tlsStart + 5
        guard packet.count > handshakeStart + 1, packet[handshakeStart] == 0x01 else { return nil }

        // Parse ClientHello for SNI extension
        return parseSNIFromClientHello(data: packet, offset: handshakeStart)
    }

    private func parseSNIFromClientHello(data: Data, offset: Int) -> String? {
        var pos = offset + 4 // skip handshake type + length

        guard data.count > pos + 34 else { return nil }

        // Skip client version (2) + random (32)
        pos += 34

        // Skip session ID
        guard data.count > pos + 1 else { return nil }
        let sessionIDLength = Int(data[pos])
        pos += 1 + sessionIDLength

        // Skip cipher suites
        guard data.count > pos + 2 else { return nil }
        let cipherSuitesLength = Int(data[pos]) << 8 | Int(data[pos + 1])
        pos += 2 + cipherSuitesLength

        // Skip compression methods
        guard data.count > pos + 1 else { return nil }
        let compressionLength = Int(data[pos])
        pos += 1 + compressionLength

        // Extensions
        guard data.count > pos + 2 else { return nil }
        let extensionsLength = Int(data[pos]) << 8 | Int(data[pos + 1])
        pos += 2

        let extensionsEnd = min(pos + extensionsLength, data.count)

        while pos + 4 < extensionsEnd {
            let extType = UInt16(data[pos]) << 8 | UInt16(data[pos + 1])
            let extLength = Int(data[pos + 2]) << 8 | Int(data[pos + 3])
            pos += 4

            if extType == 0x0000 { // SNI extension
                guard pos + 5 < data.count else { return nil }

                let nameListLength = Int(data[pos]) << 8 | Int(data[pos + 1])
                _ = nameListLength
                let nameType = data[pos + 2]
                let nameLength = Int(data[pos + 3]) << 8 | Int(data[pos + 4])

                guard nameType == 0, pos + 5 + nameLength <= data.count else { return nil }

                let nameData = data[(pos + 5)..<(pos + 5 + nameLength)]
                return String(data: nameData, encoding: .utf8)
            }

            pos += extLength
        }

        return nil
    }

    // MARK: - Domain Logging

    private func logDomain(_ domain: String, queryType: String) {
        // Skip internal/system domains
        let skipPrefixes = ["apple.com", "icloud.com", "mzstatic.com", "cdn-apple.com"]
        if skipPrefixes.contains(where: { domain.hasSuffix($0) }) { return }

        domainQueue.async { [weak self] in
            guard let self else { return }

            // Deduplicate within short window
            let key = "\(domain)_\(queryType)"
            guard !self.pendingDomains.contains(key) else { return }
            self.pendingDomains.insert(key)

            // Clear dedup after 60 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                self.domainQueue.async {
                    self.pendingDomains.remove(key)
                }
            }

            // Save to shared container
            guard let container = self.modelContainer else { return }
            let context = ModelContext(container)
            let memberID = UserDefaults.shared.string(forKey: AppConstants.UserDefaultsKeys.memberID) ?? "unknown"

            let record = DomainRecord(
                memberID: memberID,
                domain: domain,
                queryType: queryType
            )

            context.insert(record)
            try? context.save()
        }
    }
}
