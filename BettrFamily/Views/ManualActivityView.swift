import SwiftUI
import SwiftData

struct ManualActivityView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var syncService: FirebaseSyncService
    @EnvironmentObject var pointsEngine: PointsEngine
    @EnvironmentObject var activityConfigService: ActivityConfigService
    @EnvironmentObject var badgeEngine: BadgeEngine
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPreset: ManualActivityPreset?
    @State private var customName = ""
    @State private var showCustom = false
    @State private var sent = false

    static let presets: [ManualActivityPreset] = [
        .init(name: "Spuelmaschine ausraeumen", emoji: "🍽️", points: 3),
        .init(name: "Staubsaugen", emoji: "🧹", points: 4),
        .init(name: "Auto umparken", emoji: "🚗", points: 2),
        .init(name: "Kochen", emoji: "🍳", points: 5),
        .init(name: "Kueche aufraeumen", emoji: "✨", points: 4),
        .init(name: "Einkaufen", emoji: "🛒", points: 5),
        .init(name: "Wasche waschen", emoji: "👕", points: 3),
        .init(name: "Muell rausbringen", emoji: "🗑️", points: 2),
        .init(name: "Badezimmer putzen", emoji: "🚿", points: 4),
        .init(name: "Gartenarbeit", emoji: "🌱", points: 4),
        .init(name: "Hund ausfuehren", emoji: "🐕", points: 4),
        .init(name: "Betten machen", emoji: "🛏️", points: 2),
        .init(name: "Buegeln", emoji: "👔", points: 3),
        .init(name: "Aufraumen", emoji: "🧹", points: 3),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if sent {
                    sentConfirmation
                } else {
                    activityForm
                }
            }
            .navigationTitle("Aktivitaet eintragen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schliessen") { dismiss() }
                }
            }
        }
    }

    // MARK: - Form

    private var activityForm: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Was hast du gemacht?")
                        .font(.headline)
                        .padding(.horizontal)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 8) {
                        ForEach(Self.presets) { preset in
                            Button {
                                selectedPreset = preset
                                showCustom = false
                            } label: {
                                HStack {
                                    Text(preset.emoji)
                                    Text(preset.name)
                                        .font(.caption)
                                    Spacer()
                                    Text("+\(Int(preset.points))")
                                        .font(.caption.bold())
                                        .foregroundStyle(.green)
                                }
                                .padding(8)
                                .background(selectedPreset?.id == preset.id ? Color.green.opacity(0.2) : Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .tint(.primary)
                        }

                        Button {
                            showCustom = true
                            selectedPreset = nil
                        } label: {
                            HStack {
                                Text("✏️")
                                Text("Eigene Aktivitaet")
                                    .font(.caption)
                                Spacer()
                            }
                            .padding(8)
                            .background(showCustom ? Color.green.opacity(0.2) : Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .tint(.primary)
                    }
                    .padding(.horizontal)

                    if showCustom {
                        TextField("Aktivitaet eingeben...", text: $customName)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)
                    }
                }

                Button {
                    logActivity()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Eintragen")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(selectedPreset == nil && customName.isEmpty)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    // MARK: - Confirmation

    private var sentConfirmation: some View {
        VStack(spacing: 16) {
            Spacer()
            Text(selectedPreset?.emoji ?? "✅")
                .font(.system(size: 64))
            Text("Eingetragen!")
                .font(.title2.bold())
            Text("+\(Int(selectedPreset?.points ?? 3)) Punkte")
                .foregroundStyle(.green)
                .font(.headline)
            Spacer()
            Button("Fertig") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            Spacer()
        }
    }

    // MARK: - Log

    private func logActivity() {
        guard let memberID = authService.memberID,
              let memberName = authService.memberName else { return }

        let name: String
        let points: Double
        let emoji: String

        if let preset = selectedPreset {
            name = preset.name
            points = preset.points
            emoji = preset.emoji
        } else {
            name = customName
            points = 3 // default points for custom activities
            emoji = "✅"
        }

        let record = ActivityRecord(
            memberID: memberID,
            date: Date(),
            activityType: "manual_\(name)",
            category: .positive,
            rawValue: 1,
            unit: "count",
            points: points,
            source: "manual"
        )
        modelContext.insert(record)
        try? modelContext.save()

        // Recalculate score
        pointsEngine.calculateDailyScore(
            for: Date(),
            memberID: memberID,
            memberName: memberName,
            modelContext: modelContext
        )

        // Check badges
        badgeEngine.checkAndAwardBadges(memberID: memberID, modelContext: modelContext)

        // Sync
        if let familyGroupID = authService.familyGroupID {
            Task {
                await syncService.syncActivityRecords(from: modelContext, familyGroupID: familyGroupID)
                await syncService.syncDailyScores(from: modelContext, familyGroupID: familyGroupID)
            }
        }

        sent = true
    }
}

// MARK: - Preset Model

struct ManualActivityPreset: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let points: Double
}
