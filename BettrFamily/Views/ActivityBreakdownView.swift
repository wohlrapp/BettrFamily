import SwiftUI
import SwiftData

struct ActivityBreakdownView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \ActivityRecord.points, order: .reverse) private var allRecords: [ActivityRecord]
    @Query private var familyMembers: [FamilyMember]
    @State private var showManualActivity = false

    private var todayRecords: [ActivityRecord] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return allRecords.filter { $0.date == startOfDay }
    }

    /// Group today's records by activityType, sorted by total absolute points
    private var groupedActivities: [(type: String, records: [ActivityRecord])] {
        let grouped = Dictionary(grouping: todayRecords) { $0.activityType }
        return grouped.map { (type: $0.key, records: $0.value) }
            .sorted { abs($0.records.reduce(0) { $0 + $1.points }) > abs($1.records.reduce(0) { $0 + $1.points }) }
    }

    private var positiveGroups: [(type: String, records: [ActivityRecord])] {
        groupedActivities.filter { $0.records.first?.category == "positive" }
    }

    private var badGroups: [(type: String, records: [ActivityRecord])] {
        groupedActivities.filter { $0.records.first?.category == "bad" }
    }

    private var bonusGroups: [(type: String, records: [ActivityRecord])] {
        groupedActivities.filter { $0.records.first?.category == "bonus" }
    }

    var body: some View {
        NavigationStack {
            List {
                if !positiveGroups.isEmpty {
                    Section("Positiv") {
                        ForEach(positiveGroups, id: \.type) { group in
                            activityGroupRow(group.type, records: group.records)
                        }
                    }
                }

                if !badGroups.isEmpty {
                    Section("Negativ") {
                        ForEach(badGroups, id: \.type) { group in
                            activityGroupRow(group.type, records: group.records)
                        }
                    }
                }

                if !bonusGroups.isEmpty {
                    Section("Bonus") {
                        ForEach(bonusGroups, id: \.type) { group in
                            activityGroupRow(group.type, records: group.records)
                        }
                    }
                }

                if todayRecords.isEmpty {
                    ContentUnavailableView(
                        "Keine Aktivitaeten",
                        systemImage: "figure.walk",
                        description: Text("Heute wurden noch keine Aktivitaeten erfasst.")
                    )
                }
            }
            .navigationTitle("Aktivitaeten")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showManualActivity = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(isPresented: $showManualActivity) {
                ManualActivityView()
            }
        }
    }

    // MARK: - Activity Group Row (with NavigationLink drill-down)

    private func activityGroupRow(_ type: String, records: [ActivityRecord]) -> some View {
        let totalPoints = records.reduce(0) { $0 + $1.points }
        let memberCount = Set(records.map(\.memberID)).count

        return NavigationLink {
            ActivityDetailView(
                activityType: type,
                records: records,
                familyMembers: familyMembers
            )
        } label: {
            HStack {
                Image(systemName: iconForActivity(type))
                    .foregroundStyle(colorForCategory(records.first?.category ?? ""))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName(for: type))
                        .font(.subheadline)
                    Text("\(memberCount) Mitglied\(memberCount == 1 ? "" : "er")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(totalPoints >= 0 ? "+\(Int(totalPoints))" : "\(Int(totalPoints))")
                    .font(.subheadline.bold())
                    .foregroundStyle(totalPoints >= 0 ? .green : .red)
            }
        }
    }

    // MARK: - Helpers

    private func colorForCategory(_ category: String) -> Color {
        switch category {
        case "positive": return .green
        case "bad": return .red
        case "bonus": return .orange
        default: return .gray
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

    private func displayName(for type: String) -> String {
        if type.hasPrefix("manual_") {
            return String(type.dropFirst("manual_".count))
        }
        let configs = ActivityPointConfig.defaults
        return configs.first { $0.activityType == type }?.displayName ?? type
    }
}

// MARK: - Activity Detail View (Drill-Down)

struct ActivityDetailView: View {
    let activityType: String
    let records: [ActivityRecord]
    let familyMembers: [FamilyMember]

    private var sortedRecords: [ActivityRecord] {
        records.sorted { abs($0.points) > abs($1.points) }
    }

    private var totalPoints: Double {
        records.reduce(0) { $0 + $1.points }
    }

    var body: some View {
        List {
            // Summary
            Section {
                HStack {
                    Text("Gesamt-Punkte")
                    Spacer()
                    Text(totalPoints >= 0 ? "+\(Int(totalPoints))" : "\(Int(totalPoints))")
                        .font(.headline.bold())
                        .foregroundStyle(totalPoints >= 0 ? .green : .red)
                }
                HStack {
                    Text("Beitragende")
                    Spacer()
                    Text("\(Set(records.map(\.memberID)).count)")
                        .foregroundStyle(.secondary)
                }
            }

            // Per-member breakdown
            Section("Wer hat beigetragen") {
                ForEach(sortedRecords, id: \.id) { record in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(memberName(for: record.memberID))
                                .font(.subheadline.bold())
                            HStack(spacing: 8) {
                                Label(formatValue(record), systemImage: "chart.bar")
                                Label(record.source, systemImage: "arrow.down.circle")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(record.points >= 0 ? "+\(Int(record.points))" : "\(Int(record.points))")
                            .font(.subheadline.bold())
                            .foregroundStyle(record.points >= 0 ? .green : .red)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle(displayName(for: activityType))
    }

    private func memberName(for memberID: String) -> String {
        familyMembers.first(where: { $0.id == memberID })?.name ?? memberID
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
        case "count": return "\(Int(value))×"
        case "flights": return "\(Int(value)) Stockwerke"
        default: return "\(Int(value))"
        }
    }
}
