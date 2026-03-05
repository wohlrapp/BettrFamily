import NetworkExtension
import SwiftData
import Foundation

class PacketTunnelProvider: NEPacketTunnelProvider {

    private var modelContainer: ModelContainer? {
        try? SharedModelContainer.create()
    }

    private let upstreamDNS = "1.1.1.1"
    private var udpSession: NWUDPSession?

    /// Tracks pending DNS queries by transaction ID so responses can be
    /// matched back to the original packet for correct IP/port rewriting.
    private var pendingQueries: [UInt16: Data] = [:]
    private let pendingLock = NSLock()

    /// Domain deduplication
    private var recentDomains: Set<String> = []
    private let domainQueue = DispatchQueue(label: "com.bettrfamily.domainlog")

    // MARK: - Tunnel Lifecycle

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let settings = createTunnelSettings()

        setTunnelNetworkSettings(settings) { [weak self] error in
            if let error {
                completionHandler(error)
                return
            }
            guard let self else {
                completionHandler(nil)
                return
            }

            // Create UDP session to real DNS server for forwarding queries
            self.udpSession = self.createUDPSession(
                to: NWHostEndpoint(hostname: self.upstreamDNS, port: "53"),
                from: nil
            )

            // Set read handler ONCE — it will receive ALL responses
            self.setupResponseHandler()
            self.startReadingPackets()
            completionHandler(nil)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        udpSession?.cancel()
        udpSession = nil
        pendingLock.lock()
        pendingQueries.removeAll()
        pendingLock.unlock()
        completionHandler()
    }

    // MARK: - Network Settings

    private func createTunnelSettings() -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: upstreamDNS)

        // DNS settings — intercept DNS queries by pointing at our tunnel address
        let dnsSettings = NEDNSSettings(servers: ["198.18.0.1"])
        dnsSettings.matchDomains = [""] // match all domains
        settings.dnsSettings = dnsSettings

        // IPv4 settings — route ONLY DNS traffic through tunnel
        let ipv4 = NEIPv4Settings(addresses: ["198.18.0.1"], subnetMasks: ["255.255.255.0"])
        ipv4.includedRoutes = [NEIPv4Route(destinationAddress: "198.18.0.1", subnetMask: "255.255.255.255")]
        settings.ipv4Settings = ipv4

        return settings
    }

    // MARK: - Packet Reading

    private func startReadingPackets() {
        packetFlow.readPackets { [weak self] packets, protocols in
            self?.handlePackets(packets, protocols: protocols)
            self?.startReadingPackets()
        }
    }

    private func handlePackets(_ packets: [Data], protocols: [NSNumber]) {
        for (index, packet) in packets.enumerated() {
            guard let dnsInfo = extractDNSQuery(from: packet) else {
                // Only DNS packets should arrive (routing is limited to 198.18.0.1/32).
                // Drop anything else — writing it back would create a loop.
                continue
            }

            logDomain(dnsInfo.domain, queryType: "DNS")
            forwardDNSQuery(originalPacket: packet, transactionID: dnsInfo.transactionID, protocol: protocols[index])
        }
    }

    // MARK: - DNS Forwarding

    private func forwardDNSQuery(originalPacket: Data, transactionID: UInt16, protocol proto: NSNumber) {
        guard let udpSession else { return }

        // Store the original packet keyed by DNS transaction ID
        pendingLock.lock()
        pendingQueries[transactionID] = originalPacket
        pendingLock.unlock()

        // Extract DNS payload (skip IP header + 8 byte UDP header)
        let ipHeaderLength = Int(originalPacket[0] & 0x0F) * 4
        let dnsPayload = originalPacket.subdata(in: (ipHeaderLength + 8)..<originalPacket.count)

        udpSession.writeDatagram(dnsPayload) { error in
            if let error {
                NSLog("BettrFamily DNS forward error: \(error)")
                // Remove pending query on write failure
                self.pendingLock.lock()
                self.pendingQueries.removeValue(forKey: transactionID)
                self.pendingLock.unlock()
            }
        }

        // Clean up stale queries after 10 seconds to prevent memory leaks
        DispatchQueue.global().asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self else { return }
            self.pendingLock.lock()
            self.pendingQueries.removeValue(forKey: transactionID)
            self.pendingLock.unlock()
        }
    }

    /// Set up a single read handler that continuously receives DNS responses
    /// and matches them back to the original query packets.
    private func setupResponseHandler() {
        guard let udpSession else { return }

        udpSession.setReadHandler({ [weak self] datagrams, error in
            guard let self, let datagrams else {
                if let error {
                    NSLog("BettrFamily DNS read error: \(error)")
                }
                return
            }

            for dnsResponse in datagrams {
                guard dnsResponse.count >= 2 else { continue }

                // Extract transaction ID from DNS response (first 2 bytes)
                let txID = UInt16(dnsResponse[0]) << 8 | UInt16(dnsResponse[1])

                // Find the matching original packet
                self.pendingLock.lock()
                let originalPacket = self.pendingQueries.removeValue(forKey: txID)
                self.pendingLock.unlock()

                guard let originalPacket else {
                    NSLog("BettrFamily DNS response for unknown txID: \(txID)")
                    continue
                }

                // Build the IP/UDP response and send it back through the tunnel
                if let responsePacket = self.buildDNSResponsePacket(
                    originalPacket: originalPacket,
                    dnsResponse: dnsResponse
                ) {
                    // Use AF_INET (2) as protocol number for IPv4
                    self.packetFlow.writePackets([responsePacket], withProtocols: [AF_INET as NSNumber])
                }
            }
        }, maxDatagrams: NSIntegerMax) // Read as many datagrams as available
    }

    // MARK: - DNS Response Packet Building

    private func buildDNSResponsePacket(originalPacket: Data, dnsResponse: Data) -> Data? {
        let ipHeaderLength = Int(originalPacket[0] & 0x0F) * 4
        guard originalPacket.count >= ipHeaderLength + 8 else { return nil }

        // Extract original addresses and ports
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
        // Zero TTL-related fields that might cause issues — keep protocol as UDP
        // Recalculate checksum
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
        udpHeader[6] = 0 // checksum optional for IPv4 UDP
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

    private struct DNSQueryInfo {
        let domain: String
        let transactionID: UInt16
    }

    private func extractDNSQuery(from packet: Data) -> DNSQueryInfo? {
        // Minimum: IP header (20) + UDP header (8) + DNS header (12) = 40 bytes
        guard packet.count > 40 else { return nil }

        // Check IP protocol (byte 9) is UDP (17)
        guard packet[9] == 17 else { return nil }

        let ipHeaderLength = Int(packet[0] & 0x0F) * 4

        // Check UDP destination port is 53 (DNS)
        let udpStart = ipHeaderLength
        guard packet.count > udpStart + 8 else { return nil }

        let destPort = UInt16(packet[udpStart + 2]) << 8 | UInt16(packet[udpStart + 3])
        guard destPort == 53 else { return nil }

        // Extract DNS transaction ID (first 2 bytes of DNS payload)
        let dnsStart = udpStart + 8
        guard packet.count > dnsStart + 12 else { return nil }

        let transactionID = UInt16(packet[dnsStart]) << 8 | UInt16(packet[dnsStart + 1])

        // Question count (bytes 4-5 of DNS header)
        let questionCount = UInt16(packet[dnsStart + 4]) << 8 | UInt16(packet[dnsStart + 5])
        guard questionCount > 0 else { return nil }

        // Parse domain name starting at DNS header + 12
        guard let domain = parseDNSName(from: packet, offset: dnsStart + 12) else { return nil }

        return DNSQueryInfo(domain: domain, transactionID: transactionID)
    }

    private func parseDNSName(from data: Data, offset: Int) -> String? {
        var labels: [String] = []
        var position = offset

        while position < data.count {
            let length = Int(data[position])
            if length == 0 { break }
            if length & 0xC0 == 0xC0 { break } // compression pointer

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

    // MARK: - Domain Logging

    private func logDomain(_ domain: String, queryType: String) {
        // Skip internal/system domains
        let skipSuffixes = [
            "apple.com", "icloud.com", "mzstatic.com", "cdn-apple.com",
            "apple-dns.net", "push.apple.com", "aaplimg.com"
        ]
        if skipSuffixes.contains(where: { domain.hasSuffix($0) }) { return }

        domainQueue.async { [weak self] in
            guard let self else { return }

            // Deduplicate within 60-second window
            let key = "\(domain)_\(queryType)"
            guard !self.recentDomains.contains(key) else { return }
            self.recentDomains.insert(key)

            DispatchQueue.global().asyncAfter(deadline: .now() + 60) { [weak self] in
                self?.domainQueue.async {
                    self?.recentDomains.remove(key)
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
