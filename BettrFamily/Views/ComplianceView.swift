import SwiftUI
import SwiftData

struct ComplianceView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var syncService: FirebaseSyncService
    @Environment(\.modelContext) private var modelContext

    @Query private var familyMembers: [FamilyMember]

    @State private var events: [[String: Any]] = []
    @State private var isLoading = false
    @State private var selectedMemberID: String? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                memberFilter

                Group {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filteredEvents.isEmpty {
                        ContentUnavailableView(
                            "Keine Ereignisse",
                            systemImage: "shield.checkered",
                            description: Text("Keine Compliance-Verstoesse erfasst.")
                        )
                    } else {
                        List {
                            ForEach(groupedByDate, id: \.date) { group in
                                Section(group.dateString) {
                                    ForEach(Array(group.events.enumerated()), id: \.offset) { _, event in
                                        ComplianceEventRow(event: event)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Compliance")
            .refreshable { await loadEvents() }
            .task { await loadEvents() }
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

    private var filteredEvents: [[String: Any]] {
        guard let memberID = selectedMemberID else { return events }
        return events.filter { ($0["memberID"] as? String) == memberID }
    }

    private var groupedByDate: [(date: Date, dateString: String, events: [[String: Any]])] {
        let grouped = Dictionary(grouping: filteredEvents) { event -> Date in
            if let ts = event["timestamp"] as? Double {
                return Calendar.current.startOfDay(for: Date(timeIntervalSince1970: ts))
            }
            return Calendar.current.startOfDay(for: Date())
        }
        return grouped.map { date, events in
            (date: date, dateString: date.formatted(date: .abbreviated, time: .omitted), events: events)
        }
        .sorted { $0.date > $1.date }
    }

    private func loadEvents() async {
        guard let familyGroupID = authService.familyGroupID else { return }
        isLoading = true

        await syncService.syncComplianceEvents(from: modelContext, familyGroupID: familyGroupID)
        events = await syncService.fetchFamilyComplianceEvents(familyGroupID: familyGroupID)
        isLoading = false
    }
}

struct ComplianceEventRow: View {
    let event: [String: Any]

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(event["memberName"] as? String ?? "Unbekannt")
                    .font(.subheadline.bold())

                Text(event["details"] as? String ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let timestamp = event["timestamp"] as? Double {
                    Text(Date(timeIntervalSince1970: timestamp).formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var eventType: String {
        event["eventType"] as? String ?? ""
    }

    private var iconName: String {
        switch ComplianceEventType(rawValue: eventType) {
        case .vpnDisabled: return "shield.slash.fill"
        case .vpnEnabled: return "shield.fill"
        case .heartbeatMissing: return "heart.slash.fill"
        case .monitoredAppUsed: return "app.fill"
        case .monitoredDomainAccessed: return "globe"
        case .screenTimeAuthRevoked: return "exclamationmark.triangle.fill"
        case .socialMediaUsed: return "app.badge"
        case .tiktokUsed: return "play.rectangle.fill"
        case .instagramUsed: return "camera.fill"
        case .youtubeUsed: return "play.tv.fill"
        case .snapchatExcessive: return "message.fill"
        case nil: return "questionmark.circle"
        }
    }

    private var iconColor: Color {
        switch ComplianceEventType(rawValue: eventType) {
        case .vpnDisabled, .heartbeatMissing, .screenTimeAuthRevoked: return .red
        case .vpnEnabled: return .green
        case .monitoredAppUsed, .monitoredDomainAccessed: return .orange
        case .socialMediaUsed: return .purple
        case .tiktokUsed, .instagramUsed, .youtubeUsed, .snapchatExcessive: return .red
        case nil: return .gray
        }
    }
}
