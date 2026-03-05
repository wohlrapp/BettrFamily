import SwiftUI
import SwiftData

struct ScoreTabView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var pointsEngine: PointsEngine
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var activityConfigService: ActivityConfigService
    @EnvironmentObject var syncService: FirebaseSyncService
    @EnvironmentObject var badgeEngine: BadgeEngine
    @EnvironmentObject var calendarService: CalendarService
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \DailyScore.finalScore, order: .reverse) private var allScores: [DailyScore]
    @Query(sort: \RaveEvent.timestamp, order: .reverse) private var recentRaves: [RaveEvent]
    @Query private var allBadges: [Badge]
    @Query private var familyMembers: [FamilyMember]

    @State private var showActivityBreakdown = false
    @State private var showRaveSheet = false
    @State private var showBadges = false
    @State private var earnedBadge: BadgeDefinition?

    private var todayScores: [DailyScore] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return allScores.filter { $0.date == startOfDay }
    }

    private var myScore: DailyScore? {
        guard let memberID = authService.memberID else { return nil }
        return todayScores.first { $0.memberID == memberID }
    }

    private var myBadgeCount: Int {
        guard let memberID = authService.memberID else { return 0 }
        return allBadges.filter { $0.memberID == memberID }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                        // Today's Score Card
                        scoreCard

                        // Streak Banner
                        if let streak = pointsEngine.currentStreak, streak.currentStreak > 0 {
                            streakBanner(streak)
                        }

                        // Action buttons row
                        HStack(spacing: 12) {
                            Button {
                                showRaveSheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "star.circle.fill")
                                    Text("RAVE")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)

                            Button {
                                showBadges = true
                            } label: {
                                HStack {
                                    Image(systemName: "medal.fill")
                                    Text("Badges")
                                    if myBadgeCount > 0 {
                                        Text("\(myBadgeCount)")
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.white.opacity(0.3))
                                            .clipShape(Capsule())
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)
                        }
                        .padding(.horizontal)

                        // Recent RAVEs
                        if !todayRaves.isEmpty {
                            recentRavesSection
                        }

                        // Weekly Chart
                        WeeklyChartView()

                        // Family Calendar
                        calendarSection

                        // Family Members
                        familyMembersSection

                        // Activity Breakdown Link
                        Button {
                            showActivityBreakdown = true
                        } label: {
                            HStack {
                                Image(systemName: "list.bullet")
                                Text("Aktivitaeten-Details")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }

                // Badge earned overlay
                if let badge = earnedBadge {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { earnedBadge = nil }

                    BadgeEarnedToast(badge: badge) {
                        earnedBadge = nil
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring, value: earnedBadge != nil)
            .navigationTitle("Punkte")
            .sheet(isPresented: $showActivityBreakdown) {
                ActivityBreakdownView()
            }
            .sheet(isPresented: $showRaveSheet) {
                RaveView()
            }
            .sheet(isPresented: $showBadges) {
                BadgesView()
            }
            .task {
                await refreshScore()
            }
            .refreshable {
                await refreshScore()
            }
            .onChange(of: badgeEngine.newBadge?.id) { _, newID in
                if let newID, let badge = BadgeDefinition.find(newID) {
                    earnedBadge = badge
                    badgeEngine.newBadge = nil
                }
            }
        }
    }

    // MARK: - Score Card

    private var scoreCard: some View {
        VStack(spacing: 8) {
            Text("Heute")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("\(Int(myScore?.finalScore ?? 0))")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(scoreColor)

            if let score = myScore, score.streakMultiplier > 1.0 {
                Text("\(Int(score.rawTotal)) × \(String(format: "%.1f", score.streakMultiplier))x")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 24) {
                VStack {
                    Text("+\(Int(myScore?.positivePoints ?? 0))")
                        .foregroundStyle(.green)
                        .font(.headline)
                    Text("Positiv")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(Int(myScore?.negativePoints ?? 0))")
                        .foregroundStyle(.red)
                        .font(.headline)
                    Text("Negativ")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("+\(Int(myScore?.bonusPoints ?? 0))")
                        .foregroundStyle(.orange)
                        .font(.headline)
                    Text("Bonus")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var scoreColor: Color {
        guard let score = myScore else { return .primary }
        if score.finalScore > 0 { return .green }
        if score.finalScore < 0 { return .red }
        return .primary
    }

    // MARK: - Streak Banner

    private func streakBanner(_ streak: StreakRecord) -> some View {
        HStack {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(streak.currentStreak) Tage Streak")
                    .font(.headline)
                Text("Multiplikator: \(String(format: "%.1f", streak.streakMultiplier))x")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(streak.totalAccumulatedPoints))")
                    .font(.headline)
                Text("Gesamt")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            LinearGradient(colors: [.orange.opacity(0.2), .red.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Recent RAVEs

    private var todayRaves: [RaveEvent] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return recentRaves.filter { $0.date == startOfDay }
    }

    private var recentRavesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Heutige RAVEs")
                .font(.headline)
                .padding(.horizontal)

            ForEach(todayRaves.prefix(5), id: \.id) { rave in
                HStack {
                    Text(rave.emoji)
                    VStack(alignment: .leading) {
                        Text("\(rave.fromMemberName) → \(rave.toMemberName)")
                            .font(.subheadline)
                        Text(rave.reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("+\(Int(rave.points))")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Calendar

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.blue)
                Text("Familienkalender")
                    .font(.headline)
            }
            .padding(.horizontal)

            if !calendarService.isAuthorized {
                Button("Kalender-Zugriff erlauben") {
                    Task { await calendarService.requestAccess() }
                }
                .font(.subheadline)
                .padding(.horizontal)
            } else if calendarService.upcomingEvents.isEmpty {
                Text("Keine anstehenden Termine.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(calendarService.upcomingEvents.prefix(5)) { event in
                    HStack(alignment: .top, spacing: 10) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.blue)
                            .frame(width: 4)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.subheadline)
                            if event.isAllDay {
                                Text(event.startDate, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(formatEventTime(event))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let location = event.location, !location.isEmpty {
                                Text(location)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .task {
            if calendarService.isAuthorized {
                calendarService.loadUpcomingEvents()
            }
        }
    }

    private func formatEventTime(_ event: CalendarEvent) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(event.startDate) {
            formatter.dateFormat = "'Heute,' HH:mm"
        } else if calendar.isDateInTomorrow(event.startDate) {
            formatter.dateFormat = "'Morgen,' HH:mm"
        } else {
            formatter.dateFormat = "E d. MMM, HH:mm"
        }
        formatter.locale = Locale(identifier: "de_DE")

        let endFormatter = DateFormatter()
        endFormatter.dateFormat = "HH:mm"

        return "\(formatter.string(from: event.startDate)) - \(endFormatter.string(from: event.endDate))"
    }

    // MARK: - Family Members

    private var familyMembersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Familie")
                .font(.headline)
                .padding(.horizontal)

            ForEach(familyMembers.sorted(by: { memberScore($0.id) > memberScore($1.id) }), id: \.id) { member in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(member.name)
                                .font(.subheadline)
                            if member.id == authService.memberID {
                                Text("(Du)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let heartbeat = member.lastHeartbeat {
                            Text(heartbeat, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if let score = todayScores.first(where: { $0.memberID == member.id }) {
                        if score.streakDay > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                Text("\(score.streakDay)")
                                    .font(.caption2)
                            }
                        }
                        Text("\(Int(score.finalScore))")
                            .font(.subheadline.bold())
                            .foregroundStyle(score.finalScore > 0 ? .green : (score.finalScore < 0 ? .red : .primary))
                    } else {
                        Text("0")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
            }

            if familyMembers.isEmpty {
                Text("Keine Familienmitglieder gefunden.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func memberScore(_ memberID: String) -> Double {
        todayScores.first(where: { $0.memberID == memberID })?.finalScore ?? 0
    }

    // MARK: - Refresh

    private func refreshScore() async {
        guard let memberID = authService.memberID,
              let memberName = authService.memberName else { return }

        let calendar = Calendar.current
        let config = activityConfigService.config

        // Process last 7 days
        for dayOffset in (0...6).reversed() {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!
            let startOfDay = calendar.startOfDay(for: date)

            // Query HealthKit for this day
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

            // Calculate daily score
            pointsEngine.calculateDailyScore(
                for: date,
                memberID: memberID,
                memberName: memberName,
                modelContext: modelContext
            )
        }

        try? modelContext.save()

        // Update streak (based on full history)
        pointsEngine.updateStreak(for: Date(), memberID: memberID, modelContext: modelContext)

        // Check badges
        badgeEngine.checkAndAwardBadges(memberID: memberID, modelContext: modelContext)

        // Sync to Firebase
        if let familyGroupID = authService.familyGroupID {
            await syncService.syncActivityRecords(from: modelContext, familyGroupID: familyGroupID)
            await syncService.syncDailyScores(from: modelContext, familyGroupID: familyGroupID)
            await syncService.syncStreakRecords(from: modelContext, familyGroupID: familyGroupID)
            await syncService.syncBadges(from: modelContext, familyGroupID: familyGroupID)
        }
    }
}
