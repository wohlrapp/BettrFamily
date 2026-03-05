import Foundation
import SwiftData

@Model
final class ProximityEvent {
    var id: String
    var memberID: String // self
    var nearbyMemberID: String
    var nearbyMemberName: String
    var detectionType: String // "bluetooth" or "gps"
    var timestamp: Date
    var durationSeconds: Int // accumulated duration if ongoing
    var syncedToFirebase: Bool

    init(
        memberID: String,
        nearbyMemberID: String,
        nearbyMemberName: String,
        detectionType: String
    ) {
        self.id = UUID().uuidString
        self.memberID = memberID
        self.nearbyMemberID = nearbyMemberID
        self.nearbyMemberName = nearbyMemberName
        self.detectionType = detectionType
        self.timestamp = Date()
        self.durationSeconds = 0
        self.syncedToFirebase = false
    }

    var firestoreData: [String: Any] {
        [
            "id": id,
            "memberID": memberID,
            "nearbyMemberID": nearbyMemberID,
            "nearbyMemberName": nearbyMemberName,
            "detectionType": detectionType,
            "timestamp": timestamp.timeIntervalSince1970,
            "durationSeconds": durationSeconds
        ]
    }
}
