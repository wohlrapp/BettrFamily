import Foundation
import SwiftData

@Model
final class UsageRecord {
    var id: String
    var memberID: String
    var appBundleID: String
    var appName: String
    var startTime: Date
    var endTime: Date
    var durationSeconds: Int
    var date: Date // normalized to start of day
    var syncedToFirebase: Bool

    init(
        memberID: String,
        appBundleID: String,
        appName: String,
        startTime: Date,
        endTime: Date,
        durationSeconds: Int
    ) {
        self.id = UUID().uuidString
        self.memberID = memberID
        self.appBundleID = appBundleID
        self.appName = appName
        self.startTime = startTime
        self.endTime = endTime
        self.durationSeconds = durationSeconds
        self.date = Calendar.current.startOfDay(for: startTime)
        self.syncedToFirebase = false
    }

    var firestoreData: [String: Any] {
        [
            "id": id,
            "memberID": memberID,
            "appBundleID": appBundleID,
            "appName": appName,
            "startTime": startTime.timeIntervalSince1970,
            "endTime": endTime.timeIntervalSince1970,
            "durationSeconds": durationSeconds,
            "date": date.timeIntervalSince1970
        ]
    }
}
