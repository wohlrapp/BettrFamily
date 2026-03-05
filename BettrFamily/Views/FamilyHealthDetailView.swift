import SwiftUI
import SwiftData
import Charts

struct FamilyHealthDetailView: View {
    let todayScores: [DailyScore]
    let familyMembers: [FamilyMember]
    let todayActivityRecords: [ActivityRecord]

    @Environment(\.dismiss) private var dismiss

    private var memberContributions: [(name: String, positive: Double, negative: Double, bonus: Double, total: Double)] {
        familyMembers.map { member in
            let score = todayScores.first(where: { $0.memberID == member.id })
            return (
                name: member.name,
                positive: score?.positivePoints ?? 0,
                negative: score?.negativePoints ?? 0,
                bonus: score?.bonusPoints ?? 0,
                total: score?.finalScore ?? 0
            )
        }
        .sorted { $0.total > $1.total }
    }

    private var familyTotal: Double {
        todayScores.reduce(0) { $0 + $1.finalScore }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Total
                    VStack(spacing: 4) {
                        Text("Family Health Heute")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(Int(familyTotal))")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(familyTotal >= 0 ? .green : .red)
                    }
                    .padding(.top)

                    // Bar chart: contribution per member
                    memberBarChart
                        .padding(.horizontal)

                    // Breakdown per member
                    memberBreakdownSection
                        .padding(.horizontal)

                    // Top activities across family
                    topActivitiesSection
                        .padding(.horizontal)
                }
                .padding(.bottom)
            }
            .navigationTitle("Health Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    // MARK: - Member Bar Chart

    private var memberBarChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Beitraege pro Mitglied")
                .font(.headline)

            Chart {
                ForEach(memberContributions, id: \.name) { member in
                    if member.positive > 0 {
                        BarMark(
                            x: .value("Name", member.name),
                            y: .value("Punkte", member.positive)
                        )
                        .foregroundStyle(.green)
                        .position(by: .value("Typ", "Positiv"))
                    }

                    if member.negative < 0 {
                        BarMark(
                            x: .value("Name", member.name),
                            y: .value("Punkte", member.negative)
                        )
                        .foregroundStyle(.red)
                        .position(by: .value("Typ", "Negativ"))
                    }

                    if member.bonus > 0 {
                        BarMark(
                            x: .value("Name", member.name),
                            y: .value("Punkte", member.bonus)
                        )
                        .foregroundStyle(.orange)
                        .position(by: .value("Typ", "Bonus"))
                    }
                }
            }
            .chartForegroundStyleScale([
                "Positiv": .green,
                "Negativ": .red,
                "Bonus": .orange
            ])
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 220)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Member Breakdown

    private var memberBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Detail pro Mitglied")
                .font(.headline)

            ForEach(memberContributions, id: \.name) { member in
                VStack(spacing: 6) {
                    HStack {
                        Text(member.name)
                            .font(.subheadline.bold())
                        Spacer()
                        Text("\(Int(member.total))")
                            .font(.subheadline.bold())
                            .foregroundStyle(member.total >= 0 ? .green : .red)
                    }

                    HStack(spacing: 16) {
                        Label("+\(Int(member.positive))", systemImage: "arrow.up")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Label("\(Int(member.negative))", systemImage: "arrow.down")
                            .font(.caption)
                            .foregroundStyle(.red)
                        Label("+\(Int(member.bonus))", systemImage: "star")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Spacer()
                    }

                    // Mini horizontal bar
                    GeometryReader { geo in
                        let maxVal = max(memberContributions.map { max($0.positive + $0.bonus, abs($0.negative)) }.max() ?? 1, 1)
                        HStack(spacing: 0) {
                            if member.positive + member.bonus > 0 {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(.green)
                                    .frame(width: geo.size.width * ((member.positive + member.bonus) / maxVal / 2))
                            }
                            if member.negative < 0 {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(.red)
                                    .frame(width: geo.size.width * (abs(member.negative) / maxVal / 2))
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(height: 6)

                    if member.name != memberContributions.last?.name {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Top Activities

    private var topActivitiesSection: some View {
        let grouped = Dictionary(grouping: todayActivityRecords) { $0.activityType }
        let topTypes = grouped.map { (type: $0.key, total: $0.value.reduce(0) { $0 + $1.points }, count: $0.value.count) }
            .sorted { abs($0.total) > abs($1.total) }
            .prefix(10)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Top Aktivitaeten heute")
                .font(.headline)

            ForEach(Array(topTypes), id: \.type) { activity in
                HStack {
                    Image(systemName: iconForActivity(activity.type))
                        .foregroundStyle(activity.total >= 0 ? .green : .red)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(displayName(for: activity.type))
                            .font(.subheadline)
                        Text("\(activity.count) Eintr\(activity.count == 1 ? "ag" : "aege")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(activity.total >= 0 ? "+\(Int(activity.total))" : "\(Int(activity.total))")
                        .font(.subheadline.bold())
                        .foregroundStyle(activity.total >= 0 ? .green : .red)
                }
            }

            if topTypes.isEmpty {
                Text("Noch keine Aktivitaeten heute.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

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
        case "streaming": return "play.tv"
        case "socialMediaDomain": return "globe"
        case "streamingDomain": return "globe"
        case "gamingDomain": return "globe"
        default:
            if type.hasPrefix("manual_") { return "hand.thumbsup.fill" }
            return "circle"
        }
    }

    private func displayName(for type: String) -> String {
        if type.hasPrefix("manual_") {
            return String(type.dropFirst("manual_".count))
        }
        let configs = ActivityPointConfig.defaults
        return configs.first { $0.activityType == type }?.displayName ?? type
    }
}
