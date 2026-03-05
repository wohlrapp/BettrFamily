import SwiftUI
import SwiftData

struct ScoreTabView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var pointsEngine: PointsEngine
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var activityConfigService: ActivityConfigService
    @EnvironmentObject var syncService: FirebaseSyncService
    @EnvironmentObject var badgeEngine: BadgeEngine
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \DailyScore.finalScore, order: .reverse) private var allScores: [DailyScore]
    @Query(sort: \RaveEvent.timestamp, order: .reverse) private var recentRaves: [RaveEvent]
    @Query private var allBadges: [Badge]

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

                        // Family Leaderboard
                        if todayScores.count > 1 {
                            leaderboardSection
                        }

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

    // MARK: - Leaderboard

    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Familie heute")
                .font(.headline)
                .padding(.horizontal)

            ForEach(todayScores.sorted(by: { $0.finalScore > $1.finalScore }), id: \.id) { score in
                HStack {
                    Text(score.memberName)
                        .font(.subheadline)
                    Spacer()
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
                        .foregroundStyle(score.finalScore > 0 ? .green : .red)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Refresh

    private func refreshScore() async {
        guard let memberID = authService.memberID,
              let memberName = authService.memberName else { return }

        // Query HealthKit
        let hkRecords = await healthKitService.queryDailyActivities(
            for: Date(),
            memberID: memberID,
            config: activityConfigService.config,
            modelContext: modelContext
        )

        // Insert HealthKit records
        for record in hkRecords {
            let activityType = record.activityType
            let date = record.date
            let descriptor = FetchDescriptor<ActivityRecord>(
                predicate: #Predicate {
                    $0.memberID == memberID && $0.date == date && $0.activityType == activityType
                }
            )
            if let existing = try? modelContext.fetch(descriptor).first {
                existing.rawValue = record.rawValue
                existing.points = record.points
                existing.syncedToFirebase = false
            } else {
                modelContext.insert(record)
            }
        }
        try? modelContext.save()

        // Process screen time records
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let usageDescriptor = FetchDescriptor<UsageRecord>(
            predicate: #Predicate { $0.memberID == memberID && $0.date == startOfDay }
        )
        if let usageRecords = try? modelContext.fetch(usageDescriptor) {
            pointsEngine.processScreenTimeRecords(
                usageRecords: usageRecords,
                memberID: memberID,
                date: Date(),
                config: activityConfigService.config,
                modelContext: modelContext
            )
        }

        // Calculate score
        pointsEngine.calculateDailyScore(
            for: Date(),
            memberID: memberID,
            memberName: memberName,
            modelContext: modelContext
        )

        // Update streak
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
