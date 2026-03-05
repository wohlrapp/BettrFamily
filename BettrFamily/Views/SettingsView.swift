import SwiftUI
import SwiftData
import FamilyControls

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var screenTimeService: ScreenTimeService
    @EnvironmentObject var vpnMonitor: VPNStatusMonitor
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var locationService: LocationService
    @Environment(\.modelContext) private var modelContext
    @State private var showFamilyCode = false
    @State private var showAppPicker = false
    @State private var showSignOutConfirm = false
    @State private var showActivityConfig = false
    @State private var showInviteSheet = false
    @State private var mockDataInserted = false

    var body: some View {
        NavigationStack {
            List {
                // Profile
                Section("Profil") {
                    LabeledContent("Name", value: authService.memberName ?? "—")
                    LabeledContent("E-Mail", value: authService.currentUser?.email ?? "—")
                    LabeledContent("Geraet", value: UIDevice.current.name)
                }

                // Family
                Section("Familie") {
                    if let code = authService.familyGroupID {
                        HStack {
                            LabeledContent("Family-Code", value: showFamilyCode ? code : "••••••••")
                            Button(showFamilyCode ? "Verbergen" : "Anzeigen") {
                                showFamilyCode.toggle()
                            }
                            .font(.caption)
                        }
                    }
                    Button("Familienmitglied einladen") {
                        showInviteSheet = true
                    }
                }

                // Monitoring
                Section("Monitoring") {
                    HStack {
                        Text("Screen Time")
                        Spacer()
                        Text(screenTimeService.isAuthorized ? "Aktiv" : "Inaktiv")
                            .foregroundStyle(screenTimeService.isAuthorized ? .green : .red)
                    }

                    Button("Ueberwachte Apps aendern") {
                        showAppPicker = true
                    }

                    HStack {
                        Text("VPN (DNS-Monitoring)")
                        Spacer()
                        Text(vpnMonitor.isVPNActive ? "Aktiv" : "Inaktiv")
                            .foregroundStyle(vpnMonitor.isVPNActive ? .green : .red)
                    }

                    if vpnMonitor.isVPNActive {
                        Button("VPN deaktivieren", role: .destructive) {
                            vpnMonitor.stopVPN()
                        }
                    } else {
                        Button("VPN aktivieren") {
                            vpnMonitor.startVPN()
                        }
                    }
                }

                // Punkte-System
                Section("Punkte-System") {
                    HStack {
                        Text("HealthKit")
                        Spacer()
                        Text(healthKitService.isAuthorized ? "Aktiv" : "Inaktiv")
                            .foregroundStyle(healthKitService.isAuthorized ? .green : .red)
                    }

                    if !healthKitService.isAuthorized {
                        Button("HealthKit aktivieren") {
                            Task { await healthKitService.requestAuthorization() }
                        }
                    }

                    HStack {
                        Text("Standort")
                        Spacer()
                        Text(locationService.isLocationAuthorized ? "Aktiv" : "Inaktiv")
                            .foregroundStyle(locationService.isLocationAuthorized ? .green : .red)
                    }

                    if !locationService.isLocationAuthorized {
                        Button("Standort aktivieren") {
                            locationService.requestLocationAuthorization()
                        }
                    }

                    Button("Aktivitaeten konfigurieren") {
                        showActivityConfig = true
                    }
                }

                // Debug
                #if DEBUG
                Section("Debug") {
                    Button(mockDataInserted ? "Testdaten eingefuegt!" : "Testdaten generieren (7 Tage)") {
                        insertMockData()
                        mockDataInserted = true
                    }
                    .disabled(mockDataInserted)
                }
                #endif

                // Account
                Section {
                    Button("Abmelden", role: .destructive) {
                        showSignOutConfirm = true
                    }
                }
            }
            .navigationTitle("Einstellungen")
            .sheet(isPresented: $showAppPicker) {
                NavigationStack {
                    FamilyActivityPicker(selection: $screenTimeService.selectedApps)
                        .navigationTitle("Apps auswaehlen")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Fertig") {
                                    screenTimeService.saveSelectedApps()
                                    screenTimeService.startMonitoring()
                                    showAppPicker = false
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showActivityConfig) {
                ActivityConfigView()
            }
            .sheet(isPresented: $showInviteSheet) {
                if let code = authService.familyGroupID, let name = authService.memberName {
                    let message = "\(name) laedt dich zu BettrFamily ein! Nutze diesen Family-Code beim Registrieren:\n\n\(code)"
                    ShareSheet(activityItems: [message])
                }
            }
            .confirmationDialog("Abmelden?", isPresented: $showSignOutConfirm) {
                Button("Abmelden", role: .destructive) {
                    try? authService.signOut()
                }
                Button("Abbrechen", role: .cancel) {}
            }
        }
    }

    // MARK: - Mock Data

    #if DEBUG
    private func insertMockData() {
        guard let memberID = authService.memberID,
              let memberName = authService.memberName else { return }

        let calendar = Calendar.current

        for dayOffset in (0...6).reversed() {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!
            let startOfDay = calendar.startOfDay(for: date)

            // -- Activity Records --
            let steps = Double.random(in: 4000...14000)
            let stepsPoints = floor(steps / 1000)
            modelContext.insert(ActivityRecord(
                memberID: memberID, date: date,
                activityType: "steps", category: .positive,
                rawValue: steps, unit: "steps",
                points: stepsPoints, source: "healthkit"
            ))

            let walkKm = Double.random(in: 1.5...8.0)
            modelContext.insert(ActivityRecord(
                memberID: memberID, date: date,
                activityType: "distanceWalking", category: .positive,
                rawValue: walkKm, unit: "km",
                points: floor(walkKm) * 2, source: "healthkit"
            ))

            let activeEnergy = Double.random(in: 150...500)
            modelContext.insert(ActivityRecord(
                memberID: memberID, date: date,
                activityType: "activeEnergy", category: .positive,
                rawValue: activeEnergy, unit: "kcal",
                points: floor(activeEnergy / 100), source: "healthkit"
            ))

            if Bool.random() {
                modelContext.insert(ActivityRecord(
                    memberID: memberID, date: date,
                    activityType: "workouts", category: .positive,
                    rawValue: 1, unit: "count",
                    points: 3, source: "healthkit"
                ))
            }

            if Bool.random() {
                let exerciseMin = Double.random(in: 20...60)
                modelContext.insert(ActivityRecord(
                    memberID: memberID, date: date,
                    activityType: "exerciseTime", category: .positive,
                    rawValue: exerciseMin, unit: "minutes",
                    points: floor(exerciseMin / 30) * 2, source: "healthkit"
                ))
            }

            // Manual household activities (some days)
            if dayOffset % 2 == 0 {
                let chores = ["manual_Kochen", "manual_Spuelmaschine ausraeumen", "manual_Staubsaugen", "manual_Einkaufen"]
                let chore = chores.randomElement()!
                modelContext.insert(ActivityRecord(
                    memberID: memberID, date: date,
                    activityType: chore, category: .positive,
                    rawValue: 1, unit: "count",
                    points: Double.random(in: 3...5), source: "manual"
                ))
            }

            // Negative: screen time
            let screenMin = Double.random(in: 0...90)
            if screenMin > 0 {
                modelContext.insert(ActivityRecord(
                    memberID: memberID, date: date,
                    activityType: "excessiveScreenTime", category: .bad,
                    rawValue: screenMin, unit: "minutes",
                    points: -floor(screenMin / 30), source: "screentime"
                ))
            }

            let socialMin = Double.random(in: 0...45)
            if socialMin > 15 {
                modelContext.insert(ActivityRecord(
                    memberID: memberID, date: date,
                    activityType: "socialMedia", category: .bad,
                    rawValue: socialMin, unit: "minutes",
                    points: -floor(socialMin / 30) * 2, source: "screentime"
                ))
            }

            // -- Usage Records (app usage) --
            let apps: [(String, String, Int)] = [
                ("com.apple.mobilesafari", "Safari", Int.random(in: 300...1800)),
                ("com.apple.MobileSMS", "Nachrichten", Int.random(in: 120...600)),
                ("com.burbn.instagram", "Instagram", Int.random(in: 0...1200)),
                ("com.google.ios.youtube", "YouTube", Int.random(in: 0...900)),
                ("com.netflix.Netflix", "Netflix", Int.random(in: 0...2400)),
                ("com.whatsapp.WhatsApp", "WhatsApp", Int.random(in: 300...1500)),
            ]
            for (bundleID, name, duration) in apps where duration > 120 {
                let start = startOfDay.addingTimeInterval(Double.random(in: 28800...72000))
                modelContext.insert(UsageRecord(
                    memberID: memberID,
                    appBundleID: bundleID,
                    appName: name,
                    startTime: start,
                    endTime: start.addingTimeInterval(Double(duration)),
                    durationSeconds: duration
                ))
            }

            // -- Domain Records --
            let domains = ["google.com", "youtube.com", "instagram.com", "whatsapp.net",
                           "netflix.com", "reddit.com", "github.com", "stackoverflow.com"]
            for domain in domains.shuffled().prefix(Int.random(in: 3...6)) {
                let record = DomainRecord(memberID: memberID, domain: domain, queryType: "DNS")
                record.timestamp = startOfDay.addingTimeInterval(Double.random(in: 28800...79200))
                modelContext.insert(record)
            }

            // -- Daily Score --
            let positivePoints = stepsPoints + floor(walkKm) * 2 + floor(activeEnergy / 100) + Double.random(in: 0...6)
            let negativePoints = -(floor(screenMin / 30) + floor(socialMin / 30) * 2)
            let bonusPoints = dayOffset < 3 ? Double.random(in: 0...5) : 0
            let streakDay = max(0, 7 - dayOffset)
            let multiplier: Double = streakDay >= 7 ? 2.0 : (streakDay >= 2 ? 1.5 : 1.0)

            modelContext.insert(DailyScore(
                memberID: memberID,
                memberName: memberName,
                date: date,
                positivePoints: positivePoints,
                negativePoints: negativePoints,
                bonusPoints: bonusPoints,
                streakMultiplier: multiplier,
                streakDay: streakDay
            ))

            // -- RAVE events (a few days) --
            if dayOffset == 1 || dayOffset == 3 || dayOffset == 5 {
                let reasons = RaveEvent.presetReasons
                let preset = reasons.randomElement()!
                let rave = RaveEvent(
                    fromMemberID: "mock_partner",
                    fromMemberName: "Partner",
                    toMemberID: memberID,
                    toMemberName: memberName,
                    reason: preset.reason,
                    points: Double(Int.random(in: 3...8)),
                    emoji: preset.emoji
                )
                rave.timestamp = startOfDay.addingTimeInterval(Double.random(in: 36000...72000))
                rave.date = startOfDay
                modelContext.insert(rave)
            }
        }

        // -- Streak Record --
        let streak = StreakRecord(memberID: memberID)
        streak.currentStreak = 7
        streak.longestStreak = 7
        streak.lastPositiveDate = calendar.startOfDay(for: Date())
        streak.totalAccumulatedPoints = Double.random(in: 120...250)
        modelContext.insert(streak)

        // -- A couple of badges --
        modelContext.insert(Badge(memberID: memberID, badgeType: "first_day"))
        modelContext.insert(Badge(memberID: memberID, badgeType: "streak_3"))
        modelContext.insert(Badge(memberID: memberID, badgeType: "streak_7"))
        modelContext.insert(Badge(memberID: memberID, badgeType: "points_100"))
        modelContext.insert(Badge(memberID: memberID, badgeType: "rave_first"))

        // -- Compliance events --
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: Date())!
        let event = ComplianceEvent(memberID: memberID, memberName: memberName, eventType: .vpnDisabled, details: "VPN wurde deaktiviert")
        event.timestamp = twoDaysAgo
        modelContext.insert(event)

        let event2 = ComplianceEvent(memberID: memberID, memberName: memberName, eventType: .vpnEnabled, details: "VPN wieder aktiviert")
        event2.timestamp = twoDaysAgo.addingTimeInterval(1800)
        modelContext.insert(event2)

        // -- Mock family member --
        let partnerExists = (try? modelContext.fetch(FetchDescriptor<FamilyMember>(
            predicate: #Predicate { $0.id == "mock_partner" }
        )))?.isEmpty ?? true

        if partnerExists, let familyGroupID = authService.familyGroupID {
            let partner = FamilyMember(
                id: "mock_partner",
                name: "Partner",
                email: "partner@example.com",
                familyGroupID: familyGroupID,
                deviceName: "iPhone von Partner"
            )
            partner.lastHeartbeat = Date().addingTimeInterval(-600)
            modelContext.insert(partner)

            // Partner scores for past days
            for dayOffset in (0...6).reversed() {
                let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!
                modelContext.insert(DailyScore(
                    memberID: "mock_partner",
                    memberName: "Partner",
                    date: date,
                    positivePoints: Double.random(in: 8...20),
                    negativePoints: Double.random(in: -6...0),
                    bonusPoints: Double.random(in: 0...4),
                    streakMultiplier: 1.5,
                    streakDay: max(0, 5 - dayOffset)
                ))
            }
        }

        try? modelContext.save()
    }
    #endif
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
