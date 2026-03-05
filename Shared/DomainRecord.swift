import Foundation
import SwiftData

@Model
final class DomainRecord {
    var id: String
    var memberID: String
    var domain: String
    var timestamp: Date
    var queryType: String // "DNS" or "SNI"
    var sourceApp: String? // bundle ID if determinable
    var syncedToFirebase: Bool

    init(
        memberID: String,
        domain: String,
        queryType: String,
        sourceApp: String? = nil
    ) {
        self.id = UUID().uuidString
        self.memberID = memberID
        self.domain = domain
        self.timestamp = Date()
        self.queryType = queryType
        self.sourceApp = sourceApp
        self.syncedToFirebase = false
    }

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "memberID": memberID,
            "domain": domain,
            "timestamp": timestamp.timeIntervalSince1970,
            "queryType": queryType
        ]
        if let sourceApp { data["sourceApp"] = sourceApp }
        return data
    }
}
