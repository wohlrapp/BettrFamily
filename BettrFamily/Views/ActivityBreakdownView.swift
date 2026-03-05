import SwiftUI
import SwiftData

struct ActivityBreakdownView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \ActivityRecord.points, order: .reverse) private var allRecords: [ActivityRecord]
    @State private var showManualActivity = false

    private var todayRecords: [ActivityRecord] {
        guard let memberID = authService.memberID else { return [] }
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return allRecords.filter { $0.memberID == memberID && $0.date == startOfDay }
    }

    private var positiveRecords: [ActivityRecord] {
        todayRecords.filter { $0.category == "positive" }
    }

    private var badRecords: [ActivityRecord] {
        todayRecords.filter { $0.category == "bad" }
    }

    private var bonusRecords: [ActivityRecord] {
        todayRecords.filter { $0.category == "bonus" }
    }

    var body: some View {
        NavigationStack {
            List {
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

    private func activityRow(_ record: ActivityRecord) -> some View {
        HStack {
            Image(systemName: iconForActivity(record.activityType))
                .foregroundStyle(colorForCategory(record.category))
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
