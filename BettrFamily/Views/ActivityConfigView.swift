import SwiftUI

struct ActivityConfigView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var activityConfigService: ActivityConfigService
    @Environment(\.dismiss) private var dismiss

    @State private var editableConfig: FamilyActivityConfig = .default

    var body: some View {
        NavigationStack {
            List {
                Section("Positive Aktivitaeten") {
                    ForEach(editableConfig.activities.indices.filter { editableConfig.activities[$0].category == "positive" }, id: \.self) { index in
                        activityConfigRow(index: index)
                    }
                }

                Section("Negative Aktivitaeten") {
                    ForEach(editableConfig.activities.indices.filter { editableConfig.activities[$0].category == "bad" }, id: \.self) { index in
                        activityConfigRow(index: index)
                    }
                }

                Section("Bonus Aktivitaeten") {
                    ForEach(editableConfig.activities.indices.filter { editableConfig.activities[$0].category == "bonus" }, id: \.self) { index in
                        activityConfigRow(index: index)
                    }
                }
            }
            .navigationTitle("Aktivitaeten konfigurieren")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        activityConfigService.config = editableConfig
                        if let familyGroupID = authService.familyGroupID {
                            Task {
                                await activityConfigService.saveConfig(familyGroupID: familyGroupID)
                            }
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                editableConfig = activityConfigService.config
            }
        }
    }

    private func activityConfigRow(index: Int) -> some View {
        HStack {
            Toggle(isOn: $editableConfig.activities[index].isEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(editableConfig.activities[index].displayName)
                        .font(.subheadline)
                    let cfg = editableConfig.activities[index]
                    Text("\(Int(cfg.pointsPerUnit)) Pkt / \(Int(cfg.unitThreshold)) \(cfg.unit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
