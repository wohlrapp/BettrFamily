import Foundation
import FirebaseFirestore
import UserNotifications

/// Monitors other family members' heartbeats and compliance events via Firestore listeners.
/// Replaces Cloud Functions — runs entirely on-device, works on free Spark plan.
@MainActor
final class FamilyMonitorService: ObservableObject {
    @Published var familyHeartbeats: [String: HeartbeatInfo] = [:]

    private let db = Firestore.firestore()
    private var complianceListener: ListenerRegistration?
    private var heartbeatListener: ListenerRegistration?
    private var raveListener: ListenerRegistration?
    private var heartbeatCheckTimer: Timer?

    struct HeartbeatInfo: Identifiable {
        let id: String // memberID
        let memberName: String
        let timestamp: Date
        let deviceName: String
        let vpnActive: Bool

        var isStale: Bool {
            Date().timeIntervalSince(timestamp) > AppConstants.heartbeatAlertThresholdSeconds
        }

        var lastSeenText: String {
            let minutes = Int(Date().timeIntervalSince(timestamp) / 60)
            if minutes < 1 { return "gerade eben" }
            if minutes < 60 { return "vor \(minutes) Min" }
            let hours = minutes / 60
            return "vor \(hours)h \(minutes % 60)m"
        }
    }

    // MARK: - Start/Stop

    func startListening(familyGroupID: String) {
        listenForComplianceEvents(familyGroupID: familyGroupID)
        listenForHeartbeats(familyGroupID: familyGroupID)
        listenForRaveEvents(familyGroupID: familyGroupID)
        startHeartbeatCheckTimer(familyGroupID: familyGroupID)
    }

    func stopListening() {
        complianceListener?.remove()
        heartbeatListener?.remove()
        raveListener?.remove()
        heartbeatCheckTimer?.invalidate()
        complianceListener = nil
        heartbeatListener = nil
        raveListener = nil
        heartbeatCheckTimer = nil
    }

    // MARK: - Compliance Event Listener

    private func listenForComplianceEvents(familyGroupID: String) {
        let myMemberID = UserDefaults.shared.string(forKey: AppConstants.UserDefaultsKeys.memberID) ?? ""

        // Listen for new compliance events from OTHER family members
        complianceListener = db.collection(AppConstants.FirestoreCollections.families)
            .document(familyGroupID)
            .collection(AppConstants.FirestoreCollections.complianceEvents)
            .whereField("timestamp", isGreaterThan: Date().timeIntervalSince1970)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let changes = snapshot?.documentChanges else { return }

                for change in changes where change.type == .added {
                    let data = change.document.data()
                    let memberID = data["memberID"] as? String ?? ""

                    // Don't notify about our own events
                    guard memberID != myMemberID else { continue }

                    let memberName = data["memberName"] as? String ?? "Familienmitglied"
                    let eventType = data["eventType"] as? String ?? ""
                    let details = data["details"] as? String ?? ""

                    self?.sendLocalNotification(
                        title: Self.notificationTitle(for: eventType),
                        body: "\(memberName): \(details)"
                    )
                }
            }
    }

    // MARK: - RAVE Event Listener

    private func listenForRaveEvents(familyGroupID: String) {
        let myMemberID = UserDefaults.shared.string(forKey: AppConstants.UserDefaultsKeys.memberID) ?? ""

        raveListener = db.collection(AppConstants.FirestoreCollections.families)
            .document(familyGroupID)
            .collection(AppConstants.FirestoreCollections.raveEvents)
            .whereField("timestamp", isGreaterThan: Date().timeIntervalSince1970)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let changes = snapshot?.documentChanges else { return }

                for change in changes where change.type == .added {
                    let data = change.document.data()
                    let toMemberID = data["toMemberID"] as? String ?? ""

                    // Notify the recipient
                    guard toMemberID == myMemberID else { continue }

                    let fromName = data["fromMemberName"] as? String ?? "Jemand"
                    let reason = data["reason"] as? String ?? ""
                    let emoji = data["emoji"] as? String ?? "🌟"
                    let points = data["points"] as? Double ?? 5

                    self?.sendLocalNotification(
                        title: "\(emoji) RAVE von \(fromName)!",
                        body: "\(reason) (+\(Int(points)) Punkte)"
                    )
                }
            }
    }

    // MARK: - Heartbeat Listener

    private func listenForHeartbeats(familyGroupID: String) {
        heartbeatListener = db.collection(AppConstants.FirestoreCollections.families)
            .document(familyGroupID)
            .collection(AppConstants.FirestoreCollections.heartbeats)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }

                var heartbeats: [String: HeartbeatInfo] = [:]
                for doc in documents {
                    let data = doc.data()
                    let timestamp: Date
                    if let ts = data["timestamp"] as? Timestamp {
                        timestamp = ts.dateValue()
                    } else if let ts = data["timestamp"] as? Double {
                        timestamp = Date(timeIntervalSince1970: ts)
                    } else {
                        timestamp = .distantPast
                    }

                    heartbeats[doc.documentID] = HeartbeatInfo(
                        id: doc.documentID,
                        memberName: data["memberName"] as? String ?? "Unbekannt",
                        timestamp: timestamp,
                        deviceName: data["deviceName"] as? String ?? "",
                        vpnActive: data["vpnActive"] as? Bool ?? false
                    )
                }
                self?.familyHeartbeats = heartbeats
            }
    }

    // MARK: - Periodic Heartbeat Staleness Check

    private func startHeartbeatCheckTimer(familyGroupID: String) {
        heartbeatCheckTimer?.invalidate()
        heartbeatCheckTimer = Timer.scheduledTimer(
            withTimeInterval: 5 * 60, // check every 5 minutes
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkForStaleHeartbeats()
            }
        }
    }

    private func checkForStaleHeartbeats() {
        let myMemberID = UserDefaults.shared.string(forKey: AppConstants.UserDefaultsKeys.memberID) ?? ""

        for (memberID, info) in familyHeartbeats {
            guard memberID != myMemberID else { continue }

            if info.isStale {
                let minutes = Int(Date().timeIntervalSince(info.timestamp) / 60)
                sendLocalNotification(
                    title: "Heartbeat fehlt",
                    body: "\(info.memberName) hat seit \(minutes) Minuten keinen Heartbeat gesendet."
                )
            }
        }
    }

    // MARK: - Local Notifications

    private func sendLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // immediate
        )

        UNUserNotificationCenter.current().add(request)
    }

    private static func notificationTitle(for eventType: String) -> String {
        switch ComplianceEventType(rawValue: eventType) {
        case .vpnDisabled: return "VPN deaktiviert"
        case .vpnEnabled: return "VPN aktiviert"
        case .heartbeatMissing: return "Heartbeat fehlt"
        case .monitoredAppUsed: return "Ueberwachte App genutzt"
        case .monitoredDomainAccessed: return "Ueberwachte Domain aufgerufen"
        case .screenTimeAuthRevoked: return "Screen Time entzogen"
        case .socialMediaUsed: return "Social Media genutzt"
        case nil: return "Compliance-Ereignis"
        }
    }
}
