import Foundation
import SwiftData

/// RAVE = Recognize And Value Everyone
/// Family members can grant bonus points to each other for positive actions
@Model
final class RaveEvent {
    var id: String
    var fromMemberID: String
    var fromMemberName: String
    var toMemberID: String
    var toMemberName: String
    var reason: String // "Abendessen gekocht", "Hund ausgefuehrt", etc.
    var points: Double // bonus points awarded
    var emoji: String // visual indicator
    var timestamp: Date
    var date: Date // normalized to start of day
    var syncedToFirebase: Bool

    init(
        fromMemberID: String,
        fromMemberName: String,
        toMemberID: String,
        toMemberName: String,
        reason: String,
        points: Double = 5,
        emoji: String = "🌟"
    ) {
        self.id = UUID().uuidString
        self.fromMemberID = fromMemberID
        self.fromMemberName = fromMemberName
        self.toMemberID = toMemberID
        self.toMemberName = toMemberName
        self.reason = reason
        self.points = points
        self.emoji = emoji
        self.timestamp = Date()
        self.date = Calendar.current.startOfDay(for: Date())
        self.syncedToFirebase = false
    }

    var firestoreData: [String: Any] {
        [
            "id": id,
            "fromMemberID": fromMemberID,
            "fromMemberName": fromMemberName,
            "toMemberID": toMemberID,
            "toMemberName": toMemberName,
            "reason": reason,
            "points": points,
            "emoji": emoji,
            "timestamp": timestamp.timeIntervalSince1970,
            "date": date.timeIntervalSince1970
        ]
    }

    var isRant: Bool {
        points < 0
    }

    /// Predefined RAVE reasons with suggested emoji
    static let presetReasons: [(reason: String, emoji: String)] = [
        ("Abendessen gekocht", "🍳"),
        ("Hund ausgefuehrt", "🐕"),
        ("Besonders nett gewesen", "💛"),
        ("Einkaufen gegangen", "🛒"),
        ("Aufraeumen geholfen", "🧹"),
        ("Bei Hausaufgaben geholfen", "📚"),
        ("Gartenarbeit", "🌱"),
        ("Wasche gewaschen", "👕"),
        ("Jemanden gefahren", "🚗"),
        ("Gute Laune verbreitet", "😊"),
        ("Gute Schulnote", "🎓"),
        ("Test gut bestanden", "📝"),
        ("Zeugnis-Verbesserung", "🏅"),
        ("Besorgungen erledigt", "✅"),
    ]

    /// Predefined RANT reasons (negative points)
    static let presetRantReasons: [(reason: String, emoji: String)] = [
        ("Zimmer nicht aufgeraeumt", "🗑️"),
        ("Unhoeflich gewesen", "😤"),
        ("Aufgaben nicht erledigt", "❌"),
        ("Zu viel gemeckert", "😡"),
        ("Geschwister geaergert", "👊"),
        ("Nicht mitgeholfen", "🚫"),
        ("Versprechen nicht gehalten", "💔"),
        ("Zu spaet nach Hause", "🕐"),
        ("Schlechte Laune verbreitet", "😒"),
        ("Regeln nicht eingehalten", "⚠️"),
    ]
}
