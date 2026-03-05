import SwiftUI
import SwiftData

struct DomainsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var syncService: FirebaseSyncService
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \DomainRecord.timestamp, order: .reverse)
    private var localRecords: [DomainRecord]
    @Query private var familyMembers: [FamilyMember]

    @State private var searchText = ""
    @State private var selectedMemberID: String? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                memberFilter

                List {
                    if filteredRecords.isEmpty {
                        ContentUnavailableView(
                            "Keine Domains",
                            systemImage: "globe",
                            description: Text("Aktiviere das VPN, um Domain-Zugriffe zu erfassen.")
                        )
                    } else {
                        ForEach(groupedByDate, id: \.date) { group in
                            Section(group.dateString) {
                                ForEach(group.records, id: \.id) { record in
                                    DomainRow(record: record, memberName: memberName(for: record.memberID))
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Domain suchen...")
            .navigationTitle("Domains")
            .refreshable {
                if let familyGroupID = authService.familyGroupID {
                    await syncService.syncDomainRecords(
                        from: modelContext,
                        familyGroupID: familyGroupID
                    )
                }
            }
        }
    }

    private var memberFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "Alle", isSelected: selectedMemberID == nil) {
                    selectedMemberID = nil
                }
                ForEach(familyMembers, id: \.id) { member in
                    FilterChip(title: member.name, isSelected: selectedMemberID == member.id) {
                        selectedMemberID = member.id
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
    }

    private var filteredRecords: [DomainRecord] {
        var records = localRecords
        if let memberID = selectedMemberID {
            records = records.filter { $0.memberID == memberID }
        }
        if !searchText.isEmpty {
            records = records.filter { $0.domain.localizedCaseInsensitiveContains(searchText) }
        }
        return records
    }

    private var groupedByDate: [DomainGroup] {
        let grouped = Dictionary(grouping: filteredRecords) {
            Calendar.current.startOfDay(for: $0.timestamp)
        }
        return grouped.map { date, records in
            DomainGroup(date: date, records: records)
        }.sorted { $0.date > $1.date }
    }

    private func memberName(for memberID: String) -> String {
        familyMembers.first(where: { $0.id == memberID })?.name ?? memberID
    }
}

struct DomainGroup {
    let date: Date
    let records: [DomainRecord]

    var dateString: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}

struct DomainRow: View {
    let record: DomainRecord
    let memberName: String

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(record.domain)
                    .font(.subheadline)
                HStack(spacing: 6) {
                    Text(memberName)
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text(record.queryType)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(record.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}
