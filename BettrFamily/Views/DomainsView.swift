import SwiftUI
import SwiftData

struct DomainsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var syncService: FirebaseSyncService
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \DomainRecord.timestamp, order: .reverse)
    private var localRecords: [DomainRecord]

    @State private var searchText = ""

    var body: some View {
        NavigationStack {
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
                                DomainRow(record: record)
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

    private var filteredRecords: [DomainRecord] {
        if searchText.isEmpty { return localRecords }
        return localRecords.filter { $0.domain.localizedCaseInsensitiveContains(searchText) }
    }

    private var groupedByDate: [DomainGroup] {
        let grouped = Dictionary(grouping: filteredRecords) {
            Calendar.current.startOfDay(for: $0.timestamp)
        }
        return grouped.map { date, records in
            DomainGroup(date: date, records: records)
        }.sorted { $0.date > $1.date }
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

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(record.domain)
                    .font(.subheadline)
                Text(record.queryType)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(record.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
