import Foundation
import SwiftData

@Model
final class Badge {
    var id: String
    var memberID: String
    var badgeType: String // BadgeDefinition.id
    var earnedDate: Date
    var syncedToFirebase: Bool

    init(memberID: String, badgeType: String) {
        self.id = UUID().uuidString
        self.memberID = memberID
        self.badgeType = badgeType
        self.earnedDate = Date()
        self.syncedToFirebase = false
    }

    var firestoreData: [String: Any] {
        [
            "id": id,
            "memberID": memberID,
            "badgeType": badgeType,
            "earnedDate": earnedDate.timeIntervalSince1970
        ]
    }
}

// MARK: - Badge Definitions

struct BadgeDefinition: Identifiable {
    let id: String
    let name: String
    let description: String
    let emoji: String
    let category: BadgeCategory

    enum BadgeCategory: String, CaseIterable {
        case streak = "Streak"
        case activity = "Aktivitaet"
        case social = "Sozial"
        case milestone = "Meilenstein"
    }

    static let all: [BadgeDefinition] = [
        // Streak badges
        BadgeDefinition(id: "streak_3", name: "Guter Start", description: "3 Tage Streak", emoji: "🔥", category: .streak),
        BadgeDefinition(id: "streak_7", name: "Wochenkrieger", description: "7 Tage Streak", emoji: "💪", category: .streak),
        BadgeDefinition(id: "streak_14", name: "Durchhalter", description: "14 Tage Streak", emoji: "⚡", category: .streak),
        BadgeDefinition(id: "streak_30", name: "Monatsmeister", description: "30 Tage Streak", emoji: "👑", category: .streak),
        BadgeDefinition(id: "streak_100", name: "Legende", description: "100 Tage Streak", emoji: "🏆", category: .streak),

        // Activity badges
        BadgeDefinition(id: "steps_10k", name: "Laeufer", description: "10.000 Schritte an einem Tag", emoji: "🏃", category: .activity),
        BadgeDefinition(id: "steps_20k", name: "Marathoni", description: "20.000 Schritte an einem Tag", emoji: "🏅", category: .activity),
        BadgeDefinition(id: "workout_first", name: "Sportlich", description: "Erstes Workout absolviert", emoji: "🏋️", category: .activity),
        BadgeDefinition(id: "workout_10", name: "Trainingsprofi", description: "10 Workouts insgesamt", emoji: "💎", category: .activity),
        BadgeDefinition(id: "sleep_perfect", name: "Schlafmuetze", description: "7 Tage perfekter Schlaf in Folge", emoji: "😴", category: .activity),
        BadgeDefinition(id: "mindful_first", name: "Achtsam", description: "Erste Achtsamkeitsuebung", emoji: "🧘", category: .activity),
        BadgeDefinition(id: "no_screen_day", name: "Digital Detox", description: "Tag ohne negative Bildschirmzeit", emoji: "📵", category: .activity),
        BadgeDefinition(id: "early_bird", name: "Fruehaufsteher", description: "Keine Bildschirmzeit nach 22 Uhr, 7 Tage", emoji: "🌅", category: .activity),
        BadgeDefinition(id: "cyclist", name: "Radfahrer", description: "10 km Radfahren an einem Tag", emoji: "🚴", category: .activity),
        BadgeDefinition(id: "climber", name: "Bergsteiger", description: "20 Stockwerke an einem Tag", emoji: "🧗", category: .activity),

        // Social badges
        BadgeDefinition(id: "rave_first", name: "Erstlob", description: "Ersten RAVE gesendet", emoji: "⭐", category: .social),
        BadgeDefinition(id: "rave_10", name: "Motivator", description: "10 RAVEs gesendet", emoji: "🌟", category: .social),
        BadgeDefinition(id: "rave_received_10", name: "Beliebt", description: "10 RAVEs erhalten", emoji: "💝", category: .social),
        BadgeDefinition(id: "family_time", name: "Familienzeit", description: "5 Naehe-Ereignisse an einem Tag", emoji: "👨‍👩‍👧‍👦", category: .social),
        BadgeDefinition(id: "shared_workout", name: "Teamplayer", description: "Erstes gemeinsames Workout", emoji: "🤝", category: .social),

        // Milestone badges
        BadgeDefinition(id: "points_100", name: "Hundert", description: "100 Punkte insgesamt", emoji: "💯", category: .milestone),
        BadgeDefinition(id: "points_500", name: "Halbzeit", description: "500 Punkte insgesamt", emoji: "🎯", category: .milestone),
        BadgeDefinition(id: "points_1000", name: "Tausender", description: "1.000 Punkte insgesamt", emoji: "🚀", category: .milestone),
        BadgeDefinition(id: "points_5000", name: "Superstar", description: "5.000 Punkte insgesamt", emoji: "✨", category: .milestone),
        BadgeDefinition(id: "perfect_week", name: "Perfekte Woche", description: "7 positive Tage in Folge", emoji: "🌈", category: .milestone),
        BadgeDefinition(id: "first_day", name: "Willkommen", description: "Erster positiver Tag", emoji: "🎉", category: .milestone),
    ]

    static func find(_ id: String) -> BadgeDefinition? {
        all.first { $0.id == id }
    }
}
