import SwiftUI
import SwiftData

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

            // Ensure current user exists as FamilyMember in local SwiftData
            ensureLocalFamilyMember()

            // Sync family members from Firestore to local SwiftData
            if let familyGroupID = authService.familyGroupID {
                await syncFamilyMembers(familyGroupID: familyGroupID)
            }

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

    private func ensureLocalFamilyMember() {
        guard let memberID = authService.memberID,
              let memberName = authService.memberName,
              let familyGroupID = authService.familyGroupID else { return }

        let descriptor = FetchDescriptor<FamilyMember>(
            predicate: #Predicate { $0.id == memberID }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.lastHeartbeat = Date()
        } else {
            let member = FamilyMember(
                id: memberID,
                name: memberName,
                email: authService.currentUser?.email ?? "",
                familyGroupID: familyGroupID,
                isCurrentDevice: true
            )
            member.lastHeartbeat = Date()
            modelContext.insert(member)
        }
        try? modelContext.save()
    }

    private func syncFamilyMembers(familyGroupID: String) async {
        let membersData = await syncService.fetchFamilyMembers(familyGroupID: familyGroupID)

        for data in membersData {
            guard let uid = data["uid"] as? String else { continue }
            let name = data["name"] as? String ?? "Unbekannt"
            let email = data["email"] as? String ?? ""

            let descriptor = FetchDescriptor<FamilyMember>(
                predicate: #Predicate { $0.id == uid }
            )
            if (try? modelContext.fetch(descriptor).first) == nil {
                let member = FamilyMember(
                    id: uid,
                    name: name,
                    email: email,
                    familyGroupID: familyGroupID,
                    deviceName: data["deviceName"] as? String ?? ""
                )
                modelContext.insert(member)
            }
        }
        try? modelContext.save()
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
        await syncService.syncBadges(from: modelContext, familyGroupID: familyGroupID)
    }
}
