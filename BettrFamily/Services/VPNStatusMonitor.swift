import Foundation
import NetworkExtension
import SwiftData
import Combine
import UIKit

@MainActor
final class VPNStatusMonitor: ObservableObject {
    @Published var isVPNActive = false
    @Published var vpnStatus: NEVPNStatus = .disconnected

    private var vpnManager: NETunnelProviderManager?
    private var statusObservation: NSObjectProtocol?

    func loadAndMonitor() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            vpnManager = managers.first

            if vpnManager == nil {
                vpnManager = await createVPNConfiguration()
            }

            observeStatus()
        } catch {
            print("Failed to load VPN configuration: \(error)")
        }
    }

    private func createVPNConfiguration() async -> NETunnelProviderManager? {
        let manager = NETunnelProviderManager()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = "com.bettrfamily.app.PacketTunnel"
        proto.serverAddress = "localhost"
        proto.providerConfiguration = [:]

        manager.protocolConfiguration = proto
        manager.localizedDescription = "BettrFamily DNS Monitor"
        manager.isEnabled = true

        do {
            try await manager.saveToPreferences()
            try await manager.loadFromPreferences()
            return manager
        } catch {
            print("Failed to create VPN configuration: \(error)")
            return nil
        }
    }

    func startVPN() {
        guard let manager = vpnManager else { return }
        do {
            try manager.connection.startVPNTunnel()
            UserDefaults.shared.set(true, forKey: AppConstants.UserDefaultsKeys.vpnEnabled)
        } catch {
            print("Failed to start VPN: \(error)")
        }
    }

    func stopVPN() {
        vpnManager?.connection.stopVPNTunnel()
        UserDefaults.shared.set(false, forKey: AppConstants.UserDefaultsKeys.vpnEnabled)
    }

    private func observeStatus() {
        guard let manager = vpnManager else { return }

        updateStatus(manager.connection.status)

        statusObservation = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: manager.connection,
            queue: .main
        ) { [weak self] _ in
            guard let self, let manager = self.vpnManager else { return }
            Task { @MainActor in
                let previouslyActive = self.isVPNActive
                self.updateStatus(manager.connection.status)

                // Detect VPN deactivation — compliance event
                if previouslyActive && !self.isVPNActive {
                    await self.reportVPNDisabled()
                }
            }
        }
    }

    private func updateStatus(_ status: NEVPNStatus) {
        vpnStatus = status
        isVPNActive = status == .connected
        UserDefaults.shared.set(isVPNActive, forKey: AppConstants.UserDefaultsKeys.vpnEnabled)
    }

    private func reportVPNDisabled() async {
        guard let memberID = UserDefaults.shared.string(forKey: AppConstants.UserDefaultsKeys.memberID),
              let memberName = UserDefaults.shared.string(forKey: AppConstants.UserDefaultsKeys.memberName)
        else { return }

        let event = ComplianceEvent(
            memberID: memberID,
            memberName: memberName,
            eventType: .vpnDisabled,
            details: "VPN wurde deaktiviert auf \(UIDevice.current.name)"
        )

        // Save locally via shared container
        if let container = try? ModelContainer(
            for: ComplianceEvent.self,
            configurations: ModelConfiguration(
                groupContainer: .identifier(AppConstants.appGroupID)
            )
        ) {
            let context = ModelContext(container)
            context.insert(event)
            try? context.save()
        }

        // Sync to Firebase immediately
        let syncService = FirebaseSyncService()
        if let familyGroupID = UserDefaults.shared.string(forKey: AppConstants.UserDefaultsKeys.familyGroupID),
           let container = try? ModelContainer(
               for: ComplianceEvent.self,
               configurations: ModelConfiguration(
                   groupContainer: .identifier(AppConstants.appGroupID)
               )
           ) {
            let context = ModelContext(container)
            await syncService.syncComplianceEvents(from: context, familyGroupID: familyGroupID)
        }
    }
}
