import SwiftUI
import SwiftData

struct RaveView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var syncService: FirebaseSyncService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var familyMembers: [FamilyMember]

    @State private var isRant = false
    @State private var selectedMember: FamilyMember?
    @State private var selectedPreset: (reason: String, emoji: String)?
    @State private var customReason = ""
    @State private var customEmoji = "🌟"
    @State private var points: Double = 5
    @State private var showCustom = false
    @State private var sent = false

    private var accentColor: Color { isRant ? .red : .orange }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if sent {
                    sentConfirmation
                } else {
                    raveForm
                }
            }
            .navigationTitle(isRant ? "RANT senden" : "RAVE senden")
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
                // RAVE / RANT toggle
                Picker("Typ", selection: $isRant) {
                    Text("RAVE").tag(false)
                    Text("RANT").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: isRant) { _, _ in
                    selectedPreset = nil
                    showCustom = false
                    customReason = ""
                    points = 5
                }

                // Select recipient
                VStack(alignment: .leading, spacing: 8) {
                    Text("An wen?")
                        .font(.headline)

                    ForEach(familyMembers, id: \.id) { member in
                        Button {
                            selectedMember = member
                        } label: {
                            HStack {
                                Image(systemName: selectedMember?.id == member.id ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedMember?.id == member.id ? accentColor : .secondary)
                                Text(member.name)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .tint(.primary)
                    }

                    if familyMembers.isEmpty {
                        Text("Keine Familienmitglieder gefunden.")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
                .padding(.horizontal)

                // Select reason
                VStack(alignment: .leading, spacing: 8) {
                    Text(isRant ? "Was war los?" : "Wofuer?")
                        .font(.headline)
                        .padding(.horizontal)

                    let presets = isRant ? RaveEvent.presetRantReasons : RaveEvent.presetReasons
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
                                .background(selectedPreset?.reason == preset.reason ? accentColor.opacity(0.2) : Color(.systemGray6))
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
                            .background(showCustom ? accentColor.opacity(0.2) : Color(.systemGray6))
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
                    Text(isRant ? "Abzug: -\(Int(points))" : "Punkte: +\(Int(points))")
                        .font(.headline)
                    Slider(value: $points, in: 1...10, step: 1)
                        .tint(accentColor)
                }
                .padding(.horizontal)

                // Send button
                Button {
                    sendRaveOrRant()
                } label: {
                    HStack {
                        Image(systemName: isRant ? "exclamationmark.triangle.fill" : "star.circle.fill")
                        Text(isRant ? "RANT senden" : "RAVE senden")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
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
            Text(selectedPreset?.emoji ?? (isRant ? "😤" : customEmoji))
                .font(.system(size: 64))
            Text(isRant ? "RANT gesendet!" : "RAVE gesendet!")
                .font(.title2.bold())
            if isRant {
                Text("\(selectedMember?.name ?? "") hat -\(Int(points)) Punkte erhalten")
                    .foregroundStyle(.red)
            } else {
                Text("\(selectedMember?.name ?? "") hat +\(Int(points)) Punkte erhalten")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Fertig") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
            Spacer()
        }
    }

    // MARK: - Send

    private func sendRaveOrRant() {
        guard let member = selectedMember,
              let fromID = authService.memberID,
              let fromName = authService.memberName else { return }

        let reason = selectedPreset?.reason ?? customReason
        let emoji = selectedPreset?.emoji ?? (isRant ? "😤" : customEmoji)
        let actualPoints = isRant ? -points : points

        let rave = RaveEvent(
            fromMemberID: fromID,
            fromMemberName: fromName,
            toMemberID: member.id,
            toMemberName: member.name,
            reason: reason,
            points: actualPoints,
            emoji: emoji
        )

        modelContext.insert(rave)
        try? modelContext.save()

        if let familyGroupID = authService.familyGroupID {
            Task {
                await syncService.syncRaveEvents(from: modelContext, familyGroupID: familyGroupID)
            }
        }

        sent = true
    }
}
