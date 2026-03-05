import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var vpnMonitor: VPNStatusMonitor
    @EnvironmentObject var familyMonitor: FamilyMonitorService
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var activityConfigService: ActivityConfigService
    @EnvironmentObject var syncService: FirebaseSyncService
    @EnvironmentObject var pointsEngine: PointsEngine
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            ScoreTabView()
                .tabItem {
                    Label("Punkte", systemImage: "star.fill")
                }

            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }

            DomainsView()
                .tabItem {
                    Label("Domains", systemImage: "globe")
                }

            ComplianceView()
                .tabItem {
                    Label("Compliance", systemImage: "shield.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Einstellungen", systemImage: "gear")
                }
        }
        .task {
            await vpnMonitor.loadAndMonitor()
            HeartbeatService.shared.startHeartbeat()

            // Start listening for other family members' events
            if let familyGroupID = authService.familyGroupID {
                familyMonitor.startListening(familyGroupID: familyGroupID)
                activityConfigService.loadConfig(familyGroupID: familyGroupID)

                // Configure location service
                if let memberID = authService.memberID {
                    locationService.configure(
                        memberID: memberID,
                        familyGroupID: familyGroupID,
                        modelContext: modelContext
                    )
                }
            }

            // Start location & BLE if authorized
            if UserDefaults.shared.bool(forKey: AppConstants.UserDefaultsKeys.locationAuthorized) {
                locationService.startSignificantLocationMonitoring()
                locationService.startBluetoothProximity()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Sync and refresh when app comes to foreground
                Task {
                    await syncAll()
                }
            }
        }
    }

    private func syncAll() async {
        guard let familyGroupID = authService.familyGroupID else { return }

        // Sync all local data to Firebase
        await syncService.syncUsageRecords(from: modelContext, familyGroupID: familyGroupID)
        await syncService.syncDomainRecords(from: modelContext, familyGroupID: familyGroupID)
        await syncService.syncComplianceEvents(from: modelContext, familyGroupID: familyGroupID)
        await syncService.syncActivityRecords(from: modelContext, familyGroupID: familyGroupID)
        await syncService.syncDailyScores(from: modelContext, familyGroupID: familyGroupID)
        await syncService.syncStreakRecords(from: modelContext, familyGroupID: familyGroupID)
        await syncService.syncRaveEvents(from: modelContext, familyGroupID: familyGroupID)
        await syncService.syncLocationSnapshots(from: modelContext, familyGroupID: familyGroupID)
    }
}
