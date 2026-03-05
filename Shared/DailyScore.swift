import Foundation
import SwiftData

@Model
final class DailyScore {
    var id: String
    var memberID: String
    var memberName: String
    var date: Date // normalized to start of day
    var positivePoints: Double
    var negativePoints: Double
    var bonusPoints: Double
    var rawTotal: Double // before multiplier
    var streakMultiplier: Double
    var finalScore: Double // rawTotal * streakMultiplier
    var streakDay: Int // current streak day count
    var syncedToFirebase: Bool

    init(
        memberID: String,
        memberName: String,
        date: Date,
        positivePoints: Double = 0,
        negativePoints: Double = 0,
        bonusPoints: Double = 0,
        streakMultiplier: Double = 1.0,
        streakDay: Int = 0
    ) {
        self.id = UUID().uuidString
        self.memberID = memberID
        self.memberName = memberName
        self.date = Calendar.current.startOfDay(for: date)
        self.positivePoints = positivePoints
        self.negativePoints = negativePoints
        self.bonusPoints = bonusPoints
        let total = positivePoints + negativePoints + bonusPoints
        self.rawTotal = total
        self.streakMultiplier = streakMultiplier
        self.finalScore = total * streakMultiplier
        self.streakDay = streakDay
        self.syncedToFirebase = false
    }

    var isPositiveDay: Bool {
        rawTotal > 0
    }

    var firestoreData: [String: Any] {
        [
            "id": id,
            "memberID": memberID,
            "memberName": memberName,
            "date": date.timeIntervalSince1970,
            "positivePoints": positivePoints,
            "negativePoints": negativePoints,
            "bonusPoints": bonusPoints,
            "rawTotal": rawTotal,
            "streakMultiplier": streakMultiplier,
            "finalScore": finalScore,
            "streakDay": streakDay
        ]
    }
}
