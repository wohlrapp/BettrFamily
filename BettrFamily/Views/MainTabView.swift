import SwiftUI
import SwiftData

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var screenTimeService: ScreenTimeService
    @EnvironmentObject var vpnMonitor: VPNStatusMonitor
    @EnvironmentObject var familyMonitor: FamilyMonitorService
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var activityConfigService: ActivityConfigService
    @EnvironmentObject var syncService: FirebaseSyncService
    @EnvironmentObject var pointsEngine: PointsEngine
    @EnvironmentObject var badgeEngine: BadgeEngine
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var missingPrerequisites: [Prerequisite] = []

    var body: some View {
        TabView {
            ScoreTabView()
                .tabItem {
                    Label("Health", systemImage: "heart.fill")
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
        .safeAreaInset(edge: .top) {
            if !missingPrerequisites.isEmpty {
                prerequisiteBanner
            }
        }
        .task {
            await activatePrerequisites()
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

            // Full data refresh: HealthKit, Screen Time, remote RAVEs/badges/scores
            await refreshAllData()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await activatePrerequisites()
                    await refreshAllData()
                    await syncAll()
                }
            }
        }
    }

    // MARK: - Prerequisites

    enum Prerequisite: String, CaseIterable {
        case screenTime = "Screen Time"
        case healthKit = "HealthKit"
        case location = "Standort"
        case vpn = "VPN"

        var icon: String {
            switch self {
            case .screenTime: return "hourglass"
            case .healthKit: return "heart.fill"
            case .location: return "location.fill"
            case .vpn: return "network.badge.shield.half.filled"
            }
        }
    }

    private func activatePrerequisites() async {
        // 1. VPN — load config and auto-start if previously enabled
        await vpnMonitor.loadAndMonitor()
        if UserDefaults.shared.bool(forKey: AppConstants.UserDefaultsKeys.vpnEnabled) && !vpnMonitor.isVPNActive {
            vpnMonitor.startVPN()
        }

        // 2. Screen Time — check status, start monitoring if authorized
        screenTimeService.checkAuthorizationStatus()
        if screenTimeService.isAuthorized {
            screenTimeService.loadSelectedApps()
            screenTimeService.startMonitoring()
        }

        // 3. HealthKit — request authorization if not yet granted
        if !healthKitService.isAuthorized && healthKitService.isAvailable {
            if UserDefaults.shared.bool(forKey: AppConstants.UserDefaultsKeys.healthKitAuthorized) {
                // Was previously authorized, re-request silently (iOS shows no dialog if already granted)
                await healthKitService.requestAuthorization()
            }
        }

        // 4. Location — start monitoring if authorized
        if locationService.isLocationAuthorized || UserDefaults.shared.bool(forKey: AppConstants.UserDefaultsKeys.locationAuthorized) {
            if locationService.locationManager == nil {
                locationService.requestLocationAuthorization()
            }
            locationService.startSignificantLocationMonitoring()
            locationService.startBluetoothProximity()
        }

        // Update missing prerequisites list
        updateMissingPrerequisites()
    }

    private func updateMissingPrerequisites() {
        var missing: [Prerequisite] = []
        if !screenTimeService.isAuthorized { missing.append(.screenTime) }
        if !healthKitService.isAuthorized { missing.append(.healthKit) }
        if !locationService.isLocationAuthorized { missing.append(.location) }
        if !vpnMonitor.isVPNActive { missing.append(.vpn) }
        missingPrerequisites = missing
    }

    private var prerequisiteBanner: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                Text("Nicht alle Dienste aktiv")
                    .font(.caption.bold())
            }

            HStack(spacing: 12) {
                ForEach(Prerequisite.allCases, id: \.self) { prereq in
                    let active = !missingPrerequisites.contains(prereq)
                    HStack(spacing: 3) {
                        Image(systemName: prereq.icon)
                            .font(.caption2)
                        Image(systemName: active ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(active ? .green : .red)
                    }
                }
            }

            HStack(spacing: 8) {
                ForEach(missingPrerequisites, id: \.self) { prereq in
                    Button(prereq.rawValue) {
                        Task { await activatePrerequisite(prereq) }
                    }
                    .font(.caption2)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    private func activatePrerequisite(_ prereq: Prerequisite) async {
        switch prereq {
        case .screenTime:
            await screenTimeService.requestAuthorization()
            if screenTimeService.isAuthorized {
                screenTimeService.startMonitoring()
            }
        case .healthKit:
            await healthKitService.requestAuthorization()
        case .location:
            locationService.requestLocationAuthorization()
        case .vpn:
            await vpnMonitor.loadAndMonitor()
            vpnMonitor.startVPN()
        }
        // Brief delay to let state update
        try? await Task.sleep(for: .milliseconds(500))
        updateMissingPrerequisites()
    }

    // MARK: - Full Data Refresh

    private func refreshAllData() async {
        guard let memberID = authService.memberID,
              let memberName = authService.memberName else { return }

        let calendar = Calendar.current
        let config = activityConfigService.config

        // 1. Fetch remote data from Firestore (RAVEs, badges, scores from family)
        if let familyGroupID = authService.familyGroupID {
            await syncService.fetchAndStoreRemoteRaves(familyGroupID: familyGroupID, modelContext: modelContext)
            await syncService.fetchAndStoreRemoteBadges(familyGroupID: familyGroupID, memberID: memberID, modelContext: modelContext)
            await syncService.fetchAndStoreRemoteDailyScores(familyGroupID: familyGroupID, modelContext: modelContext)
        }

        // 2. Process last 7 days of HealthKit + Screen Time data
        for dayOffset in (0...6).reversed() {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!
            let startOfDay = calendar.startOfDay(for: date)

            // Query HealthKit for this day
            if healthKitService.isAuthorized {
                let hkRecords = await healthKitService.queryDailyActivities(
                    for: date,
                    memberID: memberID,
                    config: config,
                    modelContext: modelContext
                )

                // Insert/update HealthKit records (don't overwrite manual records)
                for record in hkRecords {
                    let activityType = record.activityType
                    let recordDate = record.date
                    let descriptor = FetchDescriptor<ActivityRecord>(
                        predicate: #Predicate {
                            $0.memberID == memberID && $0.date == recordDate && $0.activityType == activityType
                        }
                    )
                    if let existing = try? modelContext.fetch(descriptor).first {
                        if existing.source == "healthkit" {
                            existing.rawValue = record.rawValue
                            existing.points = record.points
                            existing.syncedToFirebase = false
                        }
                    } else {
                        modelContext.insert(record)
                    }
                }
            }

            // Process screen time records for this day
            let usageDescriptor = FetchDescriptor<UsageRecord>(
                predicate: #Predicate { $0.memberID == memberID && $0.date == startOfDay }
            )
            if let usageRecords = try? modelContext.fetch(usageDescriptor), !usageRecords.isEmpty {
                pointsEngine.processScreenTimeRecords(
                    usageRecords: usageRecords,
                    memberID: memberID,
                    date: date,
                    config: config,
                    modelContext: modelContext
                )
            }

            // Process domain records (VPN/DNS) for this day
            pointsEngine.processDomainRecords(
                memberID: memberID,
                memberName: memberName,
                date: date,
                config: config,
                modelContext: modelContext
            )

            // Calculate daily score (includes RAVE points)
            pointsEngine.calculateDailyScore(
                for: date,
                memberID: memberID,
                memberName: memberName,
                modelContext: modelContext
            )

            // Recalculate DailyScores for other family members (picks up RAVEs, synced records)
            let members = (try? modelContext.fetch(FetchDescriptor<FamilyMember>())) ?? []
            for member in members where member.id != memberID {
                pointsEngine.calculateDailyScore(
                    for: date,
                    memberID: member.id,
                    memberName: member.name,
                    modelContext: modelContext
                )
            }
        }

        try? modelContext.save()

        // 3. Update streak
        pointsEngine.updateStreak(for: Date(), memberID: memberID, modelContext: modelContext)

        // 4. Check and award badges
        badgeEngine.checkAndAwardBadges(memberID: memberID, modelContext: modelContext)

        // 5. Sync local changes back to Firebase
        if let familyGroupID = authService.familyGroupID {
            await syncService.syncActivityRecords(from: modelContext, familyGroupID: familyGroupID)
            await syncService.syncDailyScores(from: modelContext, familyGroupID: familyGroupID)
            await syncService.syncStreakRecords(from: modelContext, familyGroupID: familyGroupID)
            await syncService.syncBadges(from: modelContext, familyGroupID: familyGroupID)
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
