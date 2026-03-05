import Foundation
import SwiftData

@Model
final class StreakRecord {
    var id: String
    var memberID: String
    var currentStreak: Int // consecutive positive days
    var longestStreak: Int
    var totalAccumulatedPoints: Double // lifetime points (never reset)
    var lastPositiveDate: Date? // last date with positive score
    var syncedToFirebase: Bool

    init(memberID: String) {
        self.id = memberID // one per member
        self.memberID = memberID
        self.currentStreak = 0
        self.longestStreak = 0
        self.totalAccumulatedPoints = 0
        self.lastPositiveDate = nil
        self.syncedToFirebase = false
    }

    var streakMultiplier: Double {
        switch currentStreak {
        case 0...1: return 1.0
        case 2...6: return 1.5
        case 7...29: return 2.0
        default: return 3.0
        }
    }

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "memberID": memberID,
            "currentStreak": currentStreak,
            "longestStreak": longestStreak,
            "totalAccumulatedPoints": totalAccumulatedPoints
        ]
        if let lastPositiveDate {
            data["lastPositiveDate"] = lastPositiveDate.timeIntervalSince1970
        }
        return data
    }
}
