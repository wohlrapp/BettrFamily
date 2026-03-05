import SwiftUI
import SwiftData

struct MemberDayDetailView: View {
    let memberID: String
    let memberName: String
    let date: Date

    @Query(sort: \ActivityRecord.points, order: .reverse) private var allRecords: [ActivityRecord]
    @Query(sort: \RaveEvent.timestamp, order: .reverse) private var allRaves: [RaveEvent]
    @Environment(\.dismiss) private var dismiss

    private var dayRecords: [ActivityRecord] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return allRecords.filter { $0.memberID == memberID && $0.date == startOfDay }
    }

    private var dayRaves: [RaveEvent] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return allRaves.filter { $0.toMemberID == memberID && $0.date == startOfDay }
    }

    private var positiveRecords: [ActivityRecord] {
        dayRecords.filter { $0.category == "positive" && $0.points > 0 }
            .sorted { $0.points > $1.points }
    }

    private var badRecords: [ActivityRecord] {
        dayRecords.filter { $0.category == "bad" }
            .sorted { $0.points < $1.points }
    }

    private var bonusRecords: [ActivityRecord] {
        dayRecords.filter { $0.category == "bonus" }
            .sorted { $0.points > $1.points }
    }

    private var totalPositive: Double { positiveRecords.reduce(0) { $0 + $1.points } }
    private var totalNegative: Double { badRecords.reduce(0) { $0 + $1.points } }
    private var totalBonus: Double { bonusRecords.reduce(0) { $0 + $1.points } + dayRaves.reduce(0) { $0 + $1.points } }
    private var total: Double { totalPositive + totalNegative + totalBonus }

    var body: some View {
        NavigationStack {
            List {
                // Summary
                Section {
                    HStack(spacing: 20) {
                        VStack {
                            Text("+\(Int(totalPositive))")
                                .font(.headline)
                                .foregroundStyle(.green)
                            Text("Positiv")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        VStack {
                            Text("\(Int(totalNegative))")
                                .font(.headline)
                                .foregroundStyle(.red)
                            Text("Negativ")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        VStack {
                            Text("+\(Int(totalBonus))")
                                .font(.headline)
                                .foregroundStyle(.orange)
                            Text("Bonus")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack {
                            Text("\(Int(total))")
                                .font(.title2.bold())
                                .foregroundStyle(total >= 0 ? .green : .red)
                            Text("Gesamt")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !positiveRecords.isEmpty {
                    Section("Positiv") {
                        ForEach(positiveRecords, id: \.id) { record in
                            activityRow(record)
                        }
                    }
                }

                if !badRecords.isEmpty {
                    Section("Negativ") {
                        ForEach(badRecords, id: \.id) { record in
                            activityRow(record)
                        }
                    }
                }

                if !bonusRecords.isEmpty {
                    Section("Bonus") {
                        ForEach(bonusRecords, id: \.id) { record in
                            activityRow(record)
                        }
                    }
                }

                if !dayRaves.isEmpty {
                    Section("RAVEs erhalten") {
                        ForEach(dayRaves, id: \.id) { rave in
                            HStack {
                                Text(rave.emoji)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Von \(rave.fromMemberName)")
                                        .font(.subheadline.bold())
                                    Text(rave.reason)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("+\(Int(rave.points))")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }

                if dayRecords.isEmpty && dayRaves.isEmpty {
                    ContentUnavailableView(
                        "Keine Aktivitaeten",
                        systemImage: "figure.walk",
                        description: Text("Keine Daten fuer diesen Tag.")
                    )
                }
            }
            .navigationTitle(memberName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack {
                        Text(memberName)
                            .font(.headline)
                        Text(formattedDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private func activityRow(_ record: ActivityRecord) -> some View {
        HStack {
            Image(systemName: iconForActivity(record.activityType))
                .foregroundStyle(record.points >= 0 ? .green : .red)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName(for: record.activityType))
                    .font(.subheadline)
                Text(formatValue(record))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(record.points >= 0 ? "+\(Int(record.points))" : "\(Int(record.points))")
                .font(.subheadline.bold())
                .foregroundStyle(record.points >= 0 ? .green : .red)
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }

    private func displayName(for type: String) -> String {
        if type.hasPrefix("manual_") {
            return String(type.dropFirst("manual_".count))
        }
        let configs = ActivityPointConfig.defaults
        return configs.first { $0.activityType == type }?.displayName ?? type
    }

    private func formatValue(_ record: ActivityRecord) -> String {
        let value = record.rawValue
        switch record.unit {
        case "steps": return "\(Int(value)) Schritte"
        case "km": return String(format: "%.1f km", value)
        case "kcal": return "\(Int(value)) kcal"
        case "minutes": return "\(Int(value)) Min"
        case "hours": return String(format: "%.1f Std", value)
        case "count": return "\(Int(value))x"
        case "flights": return "\(Int(value)) Stockwerke"
        default: return "\(Int(value))"
        }
    }

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
}

// MARK: - Day Detail View (for weekly chart drill-down, all members)

struct DayDetailView: View {
    let date: Date

    @Query(sort: \DailyScore.finalScore, order: .reverse) private var allScores: [DailyScore]
    @Query(sort: \ActivityRecord.points, order: .reverse) private var allRecords: [ActivityRecord]
    @Query(sort: \RaveEvent.timestamp, order: .reverse) private var allRaves: [RaveEvent]
    @Query private var familyMembers: [FamilyMember]
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMember: FamilyMember?

    private var dayScores: [DailyScore] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return allScores.filter { $0.date == startOfDay }
    }

    private var familyTotal: Double {
        dayScores.reduce(0) { $0 + $1.finalScore }
    }

    private var sortedMembers: [(member: FamilyMember, score: DailyScore?)] {
        familyMembers.map { member in
            (member: member, score: dayScores.first { $0.memberID == member.id })
        }
        .sorted { ($0.score?.finalScore ?? 0) > ($1.score?.finalScore ?? 0) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Family Health")
                        Spacer()
                        Text("\(Int(familyTotal))")
                            .font(.title2.bold())
                            .foregroundStyle(familyTotal >= 0 ? .green : .red)
                    }
                }

                Section("Mitglieder") {
                    ForEach(sortedMembers, id: \.member.id) { item in
                        Button {
                            selectedMember = item.member
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.member.name)
                                        .font(.subheadline.bold())
                                    if let score = item.score {
                                        HStack(spacing: 8) {
                                            Text("+\(Int(score.positivePoints))")
                                                .foregroundStyle(.green)
                                            Text("\(Int(score.negativePoints))")
                                                .foregroundStyle(.red)
                                            Text("+\(Int(score.bonusPoints))")
                                                .foregroundStyle(.orange)
                                        }
                                        .font(.caption)
                                    }
                                }
                                Spacer()
                                Text("\(Int(item.score?.finalScore ?? 0))")
                                    .font(.headline.bold())
                                    .foregroundStyle((item.score?.finalScore ?? 0) >= 0 ? .green : .red)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }

                if dayScores.isEmpty {
                    ContentUnavailableView(
                        "Keine Daten",
                        systemImage: "calendar",
                        description: Text("Fuer diesen Tag liegen keine Daten vor.")
                    )
                }
            }
            .navigationTitle(formattedDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(item: $selectedMember) { member in
                MemberDayDetailView(
                    memberID: member.id,
                    memberName: member.name,
                    date: date
                )
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }
}

extension FamilyMember: Identifiable {}
