import SwiftUI
import SwiftData

struct DashboardView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var vpnMonitor: VPNStatusMonitor
    @EnvironmentObject var syncService: FirebaseSyncService
    @Environment(\.modelContext) private var modelContext

    @State private var selectedDate = Date()
    @State private var familyUsage: [[String: Any]] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusCards
                    datePicker
                    usageSection
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .refreshable { await loadData() }
            .task { await loadData() }
        }
    }

    // MARK: - Status Cards

    private var statusCards: some View {
        HStack(spacing: 12) {
            StatusCard(
                title: "VPN",
                value: vpnMonitor.isVPNActive ? "Aktiv" : "Inaktiv",
                icon: "network.badge.shield.half.filled",
                color: vpnMonitor.isVPNActive ? .green : .red
            )

            StatusCard(
                title: "Mitglied",
                value: authService.memberName ?? "—",
                icon: "person.fill",
                color: .blue
            )

            StatusCard(
                title: "Heartbeat",
                value: "OK",
                icon: "heart.fill",
                color: .green
            )
        }
    }

    // MARK: - Date Picker

    private var datePicker: some View {
        DatePicker(
            "Datum",
            selection: $selectedDate,
            displayedComponents: .date
        )
        .datePickerStyle(.compact)
        .onChange(of: selectedDate) {
            Task { await loadData() }
        }
    }

    // MARK: - Usage Section

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("App-Nutzung")
                .font(.headline)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if familyUsage.isEmpty {
                ContentUnavailableView(
                    "Keine Daten",
                    systemImage: "chart.bar",
                    description: Text("Fuer diesen Tag liegen keine Nutzungsdaten vor.")
                )
            } else {
                ForEach(groupedByMember, id: \.memberID) { group in
                    MemberUsageCard(
                        memberName: group.memberName,
                        records: group.records
                    )
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        guard let familyGroupID = authService.familyGroupID else { return }
        isLoading = true

        // Sync local data first
        await syncService.syncUsageRecords(from: modelContext, familyGroupID: familyGroupID)

        // Fetch all family data
        familyUsage = await syncService.fetchFamilyUsageRecords(
            familyGroupID: familyGroupID,
            date: selectedDate
        )

        isLoading = false
    }

    // MARK: - Grouping

    private var groupedByMember: [MemberUsageGroup] {
        let grouped = Dictionary(grouping: familyUsage) { $0["memberID"] as? String ?? "" }
        return grouped.map { memberID, records in
            let memberName = records.first?["appName"] as? String ?? memberID
            return MemberUsageGroup(memberID: memberID, memberName: memberName, records: records)
        }.sorted { $0.memberName < $1.memberName }
    }
}

struct MemberUsageGroup: Identifiable {
    let memberID: String
    let memberName: String
    let records: [[String: Any]]
    var id: String { memberID }
}

// MARK: - Sub-views

struct StatusCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.caption.bold())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct MemberUsageCard: View {
    let memberName: String
    let records: [[String: Any]]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(memberName)
                .font(.subheadline.bold())

            ForEach(Array(records.enumerated()), id: \.offset) { _, record in
                HStack {
                    Text(record["appName"] as? String ?? "Unbekannt")
                        .font(.subheadline)
                    Spacer()
                    let seconds = record["durationSeconds"] as? Int ?? 0
                    Text(formatDuration(seconds))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
