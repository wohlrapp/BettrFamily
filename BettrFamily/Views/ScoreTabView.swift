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
    @Query(sort: \ActivityRecord.points, order: .reverse) private var allActivityRecords: [ActivityRecord]

    @State private var showActivityBreakdown = false
    @State private var showRaveSheet = false
    @State private var showBadges = false
    @State private var showHealthDetail = false
    @State private var earnedBadge: BadgeDefinition?

    private var todayScores: [DailyScore] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return allScores.filter { $0.date == startOfDay }
    }

    private var familyHealthScore: Double {
        todayScores.reduce(0) { $0 + $1.finalScore }
    }

    private var familyPositivePoints: Double {
        todayScores.reduce(0) { $0 + $1.positivePoints }
    }

    private var familyNegativePoints: Double {
        todayScores.reduce(0) { $0 + $1.negativePoints }
    }

    private var familyBonusPoints: Double {
        todayScores.reduce(0) { $0 + $1.bonusPoints }
    }

    private var myBadgeCount: Int {
        guard let memberID = authService.memberID else { return 0 }
        return allBadges.filter { $0.memberID == memberID }.count
    }

    private var todayActivityRecords: [ActivityRecord] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return allActivityRecords.filter { $0.date == startOfDay }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                        // Family Health Score Card (tap for detail)
                        familyHealthCard
                            .onTapGesture { showHealthDetail = true }

                        // Contributors
                        contributorsSection

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
                        if !weekRaves.isEmpty {
                            recentRavesSection
                        }

                        // Weekly Chart
                        WeeklyChartView()

                        // Family Calendar
                        calendarSection

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
            .navigationTitle("Family Health")
            .sheet(isPresented: $showActivityBreakdown) {
                ActivityBreakdownView()
            }
            .sheet(isPresented: $showRaveSheet) {
                RaveView()
            }
            .sheet(isPresented: $showBadges) {
                BadgesView()
            }
            .sheet(isPresented: $showHealthDetail) {
                FamilyHealthDetailView(
                    todayScores: todayScores,
                    familyMembers: familyMembers,
                    todayActivityRecords: todayActivityRecords
                )
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

    // MARK: - Family Health Card

    private var familyHealthCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                Text("Family Health")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("\(Int(familyHealthScore))")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(familyScoreColor)

            // Health bar
            healthBar

            HStack(spacing: 24) {
                VStack {
                    Text("+\(Int(familyPositivePoints))")
                        .foregroundStyle(.green)
                        .font(.headline)
                    Text("Positiv")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(Int(familyNegativePoints))")
                        .foregroundStyle(.red)
                        .font(.headline)
                    Text("Negativ")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("+\(Int(familyBonusPoints))")
                        .foregroundStyle(.orange)
                        .font(.headline)
                    Text("Bonus")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if !familyMembers.isEmpty {
                Text("\(familyMembers.count) Mitglieder")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var healthBar: some View {
        let maxExpected = max(Double(familyMembers.count) * 30.0, 1.0)
        let progress = min(max(familyHealthScore / maxExpected, -1.0), 1.0)

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.gray.opacity(0.2))
                    .frame(height: 8)

                if progress >= 0 {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.green.opacity(0.7), .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 8)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.red, .red.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * abs(progress), height: 8)
                }
            }
        }
        .frame(height: 8)
        .padding(.horizontal, 8)
    }

    private var familyScoreColor: Color {
        if familyHealthScore > 0 { return .green }
        if familyHealthScore < 0 { return .red }
        return .primary
    }

    // MARK: - Contributors

    private var contributorsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Beitraege")
                .font(.headline)
                .padding(.horizontal)

            let sorted = familyMembers.sorted { memberScore($0.id) > memberScore($1.id) }

            ForEach(sorted, id: \.id) { member in
                contributorRow(member)
            }

            if familyMembers.isEmpty {
                Text("Keine Familienmitglieder gefunden.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func contributorRow(_ member: FamilyMember) -> some View {
        let score = todayScores.first(where: { $0.memberID == member.id })
        let memberActivities = todayActivityRecords.filter { $0.memberID == member.id }
        let topPositive = memberActivities
            .filter { $0.category == "positive" && $0.points > 0 }
            .sorted { $0.points > $1.points }
            .prefix(3)
        let topNegative = memberActivities
            .filter { $0.category == "bad" && $0.points < 0 }
            .sorted { $0.points < $1.points }
            .prefix(2)

        return VStack(spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(member.name)
                            .font(.subheadline.bold())
                        if member.id == authService.memberID {
                            Text("(Du)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let streak = score, streak.streakDay > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            Text("\(streak.streakDay) Tage Streak")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                Text("\(Int(score?.finalScore ?? 0))")
                    .font(.title3.bold())
                    .foregroundStyle(scoreColor(for: score?.finalScore ?? 0))
            }
            .padding(.horizontal)

            // Top activities for this contributor
            if !topPositive.isEmpty || !topNegative.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(topPositive), id: \.id) { activity in
                            activityChip(activity)
                        }
                        ForEach(Array(topNegative), id: \.id) { activity in
                            activityChip(activity)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            if member.id != familyMembers.sorted(by: { memberScore($0.id) > memberScore($1.id) }).last?.id {
                Divider()
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 2)
    }

    private func activityChip(_ record: ActivityRecord) -> some View {
        let isPositive = record.points >= 0
        return HStack(spacing: 3) {
            Image(systemName: iconForActivity(record.activityType))
                .font(.caption2)
            Text(shortDisplayName(for: record.activityType))
                .font(.caption2)
            Text(isPositive ? "+\(Int(record.points))" : "\(Int(record.points))")
                .font(.caption2.bold())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isPositive ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
        .foregroundStyle(isPositive ? .green : .red)
        .clipShape(Capsule())
    }

    private func scoreColor(for score: Double) -> Color {
        if score > 0 { return .green }
        if score < 0 { return .red }
        return .primary
    }

    // MARK: - Activity Helpers

    private func iconForActivity(_ type: String) -> String {
        switch type {
        case "steps": return "figure.walk"
        case "distanceWalking": return "figure.run"
        case "distanceCycling": return "figure.outdoor.cycle"
        case "activeEnergy": return "flame"
        case "exerciseTime": return "timer"
        case "workouts": return "dumbbell"
        case "flightsClimbed": return "stairs"
        case "mindfulSession": return "brain.head.profile"
        case "goodSleep": return "bed.double.fill"
        case "shortSleep": return "bed.double"
        case "timeInDaylight": return "sun.max"
        case "standHours": return "figure.stand"
        case "toothbrushing": return "mouth"
        case "excessiveScreenTime": return "iphone"
        case "socialMedia": return "app.badge"
        case "gaming": return "gamecontroller"
        case "lateNightScreen": return "moon.fill"
        case "alcohol": return "wineglass"
        case "proximity": return "person.2"
        case "coLocation": return "location"
        case "sharedWorkout": return "figure.2.and.child.holdinghands"
        case "streaming": return "play.tv"
        case "socialMediaDomain": return "globe"
        case "streamingDomain": return "globe"
        case "gamingDomain": return "globe"
        case "rave": return "star.fill"
        default:
            if type.hasPrefix("manual_") { return "hand.thumbsup.fill" }
            return "circle"
        }
    }

    private func shortDisplayName(for type: String) -> String {
        if type.hasPrefix("manual_") {
            return String(type.dropFirst("manual_".count))
        }
        switch type {
        case "steps": return "Schritte"
        case "distanceWalking": return "Gehen"
        case "distanceCycling": return "Rad"
        case "activeEnergy": return "Energie"
        case "exerciseTime": return "Training"
        case "workouts": return "Workout"
        case "flightsClimbed": return "Stockwerke"
        case "mindfulSession": return "Achtsamkeit"
        case "goodSleep": return "Schlaf"
        case "shortSleep": return "Schlaf"
        case "timeInDaylight": return "Tageslicht"
        case "standHours": return "Stehen"
        case "toothbrushing": return "Zaehne"
        case "excessiveScreenTime": return "Bildschirm"
        case "socialMedia": return "Social Media"
        case "gaming": return "Gaming"
        case "lateNightScreen": return "Nachts"
        case "alcohol": return "Alkohol"
        case "proximity": return "Zusammen"
        case "streaming": return "Streaming"
        case "socialMediaDomain": return "Social (Web)"
        case "streamingDomain": return "Streaming (Web)"
        case "gamingDomain": return "Gaming (Web)"
        default: return type
        }
    }

    // MARK: - Recent RAVEs

    private var weekRaves: [RaveEvent] {
        let calendar = Calendar.current
        let weekAgo = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -6, to: Date())!)
        return recentRaves.filter { $0.date >= weekAgo }
    }

    private var recentRavesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RAVEs (letzte 7 Tage)")
                .font(.headline)
                .padding(.horizontal)

            ForEach(weekRaves.prefix(10), id: \.id) { rave in
                HStack {
                    Text(rave.emoji)
                    VStack(alignment: .leading) {
                        Text("\(rave.fromMemberName) → \(rave.toMemberName)")
                            .font(.subheadline)
                        HStack(spacing: 4) {
                            Text(rave.reason)
                            Text("·")
                            Text(rave.timestamp, style: .relative)
                        }
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

    private func memberScore(_ memberID: String) -> Double {
        todayScores.first(where: { $0.memberID == memberID })?.finalScore ?? 0
    }

    // MARK: - Refresh

    private func refreshScore() async {
        guard let memberID = authService.memberID,
              let memberName = authService.memberName else { return }

        let calendar = Calendar.current
        let config = activityConfigService.config

        // Recalculate scores for last 7 days
        for dayOffset in (0...6).reversed() {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!

            if healthKitService.isAuthorized {
                let hkRecords = await healthKitService.queryDailyActivities(
                    for: date,
                    memberID: memberID,
                    config: config,
                    modelContext: modelContext
                )

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

            // Process domain records (VPN/DNS) for this day
            pointsEngine.processDomainRecords(
                memberID: memberID,
                memberName: memberName,
                date: date,
                config: config,
                modelContext: modelContext
            )

            pointsEngine.calculateDailyScore(
                for: date,
                memberID: memberID,
                memberName: memberName,
                modelContext: modelContext
            )

            // Recalculate DailyScores for other family members (picks up RAVEs, synced records)
            for member in familyMembers where member.id != memberID {
                pointsEngine.calculateDailyScore(
                    for: date,
                    memberID: member.id,
                    memberName: member.name,
                    modelContext: modelContext
                )
            }
        }

        try? modelContext.save()

        pointsEngine.updateStreak(for: Date(), memberID: memberID, modelContext: modelContext)
        badgeEngine.checkAndAwardBadges(memberID: memberID, modelContext: modelContext)
    }
}
