import Foundation
import SwiftData

enum ActivityCategory: String, Codable, CaseIterable {
    case positive
    case neutral
    case bad
    case bonus
}

@Model
final class ActivityRecord {
    var id: String
    var memberID: String
    var date: Date // normalized to start of day
    var activityType: String // e.g. "steps", "socialMedia", "proximity"
    var category: String // ActivityCategory.rawValue
    var rawValue: Double // e.g. 5000 steps, 120 minutes
    var unit: String // "steps", "km", "minutes", "count", "kcal"
    var points: Double // calculated points (before multiplier)
    var source: String // "healthkit", "screentime", "location", "manual"
    var syncedToFirebase: Bool

    init(
        memberID: String,
        date: Date,
        activityType: String,
        category: ActivityCategory,
        rawValue: Double,
        unit: String,
        points: Double,
        source: String
    ) {
        self.id = UUID().uuidString
        self.memberID = memberID
        self.date = Calendar.current.startOfDay(for: date)
        self.activityType = activityType
        self.category = category.rawValue
        self.rawValue = rawValue
        self.unit = unit
        self.points = points
        self.source = source
        self.syncedToFirebase = false
    }

    var activityCategory: ActivityCategory? {
        ActivityCategory(rawValue: category)
    }

    var firestoreData: [String: Any] {
        [
            "id": id,
            "memberID": memberID,
            "date": date.timeIntervalSince1970,
            "activityType": activityType,
            "category": category,
            "rawValue": rawValue,
            "unit": unit,
            "points": points,
            "source": source
        ]
    }
}
