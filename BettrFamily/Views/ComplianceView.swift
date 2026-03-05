import SwiftUI
import SwiftData

struct ComplianceView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var syncService: FirebaseSyncService
    @Environment(\.modelContext) private var modelContext

    @State private var events: [[String: Any]] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if events.isEmpty {
                    ContentUnavailableView(
                        "Keine Ereignisse",
                        systemImage: "shield.checkered",
                        description: Text("Keine Compliance-Verstoesse erfasst.")
                    )
                } else {
                    List(Array(events.enumerated()), id: \.offset) { _, event in
                        ComplianceEventRow(event: event)
                    }
                }
            }
            .navigationTitle("Compliance")
            .refreshable { await loadEvents() }
            .task { await loadEvents() }
        }
    }

    private func loadEvents() async {
        guard let familyGroupID = authService.familyGroupID else { return }
        isLoading = true

        // Sync local events first
        await syncService.syncComplianceEvents(from: modelContext, familyGroupID: familyGroupID)

        // Fetch all family events
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
                    Text(Date(timeIntervalSince1970: timestamp).formatted())
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
