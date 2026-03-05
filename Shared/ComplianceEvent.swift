import Foundation
import SwiftData

enum ComplianceEventType: String, Codable {
    case vpnDisabled = "vpn_disabled"
    case vpnEnabled = "vpn_enabled"
    case heartbeatMissing = "heartbeat_missing"
    case monitoredAppUsed = "monitored_app_used"
    case monitoredDomainAccessed = "monitored_domain_accessed"
    case screenTimeAuthRevoked = "screentime_auth_revoked"
    case socialMediaUsed = "social_media_used"
    case tiktokUsed = "tiktok_used"
    case instagramUsed = "instagram_used"
    case youtubeUsed = "youtube_used"
    case snapchatExcessive = "snapchat_excessive"
}

@Model
final class ComplianceEvent {
    var id: String
    var memberID: String
    var memberName: String
    var eventType: String // ComplianceEventType.rawValue
    var timestamp: Date
    var details: String
    var acknowledged: Bool
    var syncedToFirebase: Bool

    init(
        memberID: String,
        memberName: String,
        eventType: ComplianceEventType,
        details: String
    ) {
        self.id = UUID().uuidString
        self.memberID = memberID
        self.memberName = memberName
        self.eventType = eventType.rawValue
        self.timestamp = Date()
        self.details = details
        self.acknowledged = false
        self.syncedToFirebase = false
    }

    var type: ComplianceEventType? {
        ComplianceEventType(rawValue: eventType)
    }

    var firestoreData: [String: Any] {
        [
            "id": id,
            "memberID": memberID,
            "memberName": memberName,
            "eventType": eventType,
            "timestamp": timestamp.timeIntervalSince1970,
            "details": details,
            "acknowledged": acknowledged
        ]
    }
}
