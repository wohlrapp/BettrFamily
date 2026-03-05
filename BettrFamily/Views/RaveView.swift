import SwiftUI
import SwiftData

struct RaveView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var syncService: FirebaseSyncService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var familyMembers: [FamilyMember]

    @State private var selectedMember: FamilyMember?
    @State private var selectedPreset: (reason: String, emoji: String)?
    @State private var customReason = ""
    @State private var customEmoji = "🌟"
    @State private var points: Double = 5
    @State private var showCustom = false
    @State private var sent = false

    private var eligibleMembers: [FamilyMember] {
        familyMembers
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if sent {
                    sentConfirmation
                } else {
                    raveForm
                }
            }
            .navigationTitle("RAVE senden")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schliessen") { dismiss() }
                }
            }
        }
    }

    // MARK: - Form

    private var raveForm: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Select recipient
                VStack(alignment: .leading, spacing: 8) {
                    Text("An wen?")
                        .font(.headline)

                    ForEach(eligibleMembers, id: \.id) { member in
                        Button {
                            selectedMember = member
                        } label: {
                            HStack {
                                Image(systemName: selectedMember?.id == member.id ? "checkmark.circle.fill" : "circle")
                                Text(member.name)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .tint(.primary)
                    }

                    if eligibleMembers.isEmpty {
                        Text("Keine anderen Familienmitglieder gefunden.")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
                .padding(.horizontal)

                // Select reason
                VStack(alignment: .leading, spacing: 8) {
                    Text("Wofuer?")
                        .font(.headline)
                        .padding(.horizontal)

                    let presets = RaveEvent.presetReasons
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 8) {
                        ForEach(presets, id: \.reason) { preset in
                            Button {
                                selectedPreset = preset
                                showCustom = false
                            } label: {
                                HStack {
                                    Text(preset.emoji)
                                    Text(preset.reason)
                                        .font(.caption)
                                    Spacer()
                                }
                                .padding(8)
                                .background(selectedPreset?.reason == preset.reason ? Color.orange.opacity(0.2) : Color(.systemGray6))
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
                                Text("Eigener Grund")
                                    .font(.caption)
                                Spacer()
                            }
                            .padding(8)
                            .background(showCustom ? Color.orange.opacity(0.2) : Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .tint(.primary)
                    }
                    .padding(.horizontal)

                    if showCustom {
                        TextField("Grund eingeben...", text: $customReason)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)
                    }
                }

                // Points
                VStack(alignment: .leading, spacing: 8) {
                    Text("Punkte: \(Int(points))")
                        .font(.headline)
                    Slider(value: $points, in: 1...10, step: 1)
                }
                .padding(.horizontal)

                // Send button
                Button {
                    sendRave()
                } label: {
                    HStack {
                        Image(systemName: "star.circle.fill")
                        Text("RAVE senden")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(selectedMember == nil || (selectedPreset == nil && customReason.isEmpty))
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    // MARK: - Confirmation

    private var sentConfirmation: some View {
        VStack(spacing: 16) {
            Spacer()
            Text(selectedPreset?.emoji ?? customEmoji)
                .font(.system(size: 64))
            Text("RAVE gesendet!")
                .font(.title2.bold())
            Text("\(selectedMember?.name ?? "") hat +\(Int(points)) Punkte erhalten")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Fertig") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            Spacer()
        }
    }

    // MARK: - Send

    private func sendRave() {
        guard let member = selectedMember,
              let fromID = authService.memberID,
              let fromName = authService.memberName else { return }

        let reason = selectedPreset?.reason ?? customReason
        let emoji = selectedPreset?.emoji ?? customEmoji

        let rave = RaveEvent(
            fromMemberID: fromID,
            fromMemberName: fromName,
            toMemberID: member.id,
            toMemberName: member.name,
            reason: reason,
            points: points,
            emoji: emoji
        )

        modelContext.insert(rave)
        try? modelContext.save()

        // Sync to Firebase
        if let familyGroupID = authService.familyGroupID {
            Task {
                await syncService.syncRaveEvents(from: modelContext, familyGroupID: familyGroupID)
            }
        }

        sent = true
    }
}
