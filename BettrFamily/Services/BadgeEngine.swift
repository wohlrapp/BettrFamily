import Foundation
import SwiftData

@MainActor
final class BadgeEngine: ObservableObject {
    @Published var newBadge: BadgeDefinition?

    /// Check all badge conditions and award any newly earned badges.
    /// Call after daily score calculation.
    func checkAndAwardBadges(
        memberID: String,
        modelContext: ModelContext
    ) {
        let earnedIDs = fetchEarnedBadgeIDs(memberID: memberID, modelContext: modelContext)

        for definition in BadgeDefinition.all {
            guard !earnedIDs.contains(definition.id) else { continue }

            if shouldAward(definition, memberID: memberID, modelContext: modelContext) {
                let badge = Badge(memberID: memberID, badgeType: definition.id)
                modelContext.insert(badge)
                newBadge = definition
            }
        }

        try? modelContext.save()
    }

    private func fetchEarnedBadgeIDs(memberID: String, modelContext: ModelContext) -> Set<String> {
        let descriptor = FetchDescriptor<Badge>(
            predicate: #Predicate { $0.memberID == memberID }
        )
        let badges = (try? modelContext.fetch(descriptor)) ?? []
        return Set(badges.map { $0.badgeType })
    }

    // MARK: - Badge Checks

    private func shouldAward(_ badge: BadgeDefinition, memberID: String, modelContext: ModelContext) -> Bool {
        switch badge.id {

        // Streak badges
        case "streak_3": return currentStreak(memberID: memberID, modelContext: modelContext) >= 3
        case "streak_7": return currentStreak(memberID: memberID, modelContext: modelContext) >= 7
        case "streak_14": return currentStreak(memberID: memberID, modelContext: modelContext) >= 14
        case "streak_30": return currentStreak(memberID: memberID, modelContext: modelContext) >= 30
        case "streak_100": return currentStreak(memberID: memberID, modelContext: modelContext) >= 100

        // Activity badges
        case "steps_10k": return todayActivityValue("steps", memberID: memberID, modelContext: modelContext) >= 10_000
        case "steps_20k": return todayActivityValue("steps", memberID: memberID, modelContext: modelContext) >= 20_000
        case "workout_first": return totalActivityCount("workouts", memberID: memberID, modelContext: modelContext) >= 1
        case "workout_10": return totalActivityCount("workouts", memberID: memberID, modelContext: modelContext) >= 10
        case "mindful_first": return totalActivityCount("mindfulSession", memberID: memberID, modelContext: modelContext) >= 1
        case "cyclist": return todayActivityValue("distanceCycling", memberID: memberID, modelContext: modelContext) >= 10
        case "climber": return todayActivityValue("flightsClimbed", memberID: memberID, modelContext: modelContext) >= 20

        case "sleep_perfect": return consecutiveDaysWithActivity("goodSleep", days: 7, memberID: memberID, modelContext: modelContext)
        case "no_screen_day": return noNegativeScreenToday(memberID: memberID, modelContext: modelContext)
        case "early_bird": return consecutiveDaysWithoutActivity("lateNightScreen", days: 7, memberID: memberID, modelContext: modelContext)

        // Social badges
        case "rave_first": return totalRavesSent(memberID: memberID, modelContext: modelContext) >= 1
        case "rave_10": return totalRavesSent(memberID: memberID, modelContext: modelContext) >= 10
        case "rave_received_10": return totalRavesReceived(memberID: memberID, modelContext: modelContext) >= 10
        case "family_time": return todayProximityCount(memberID: memberID, modelContext: modelContext) >= 5
        case "shared_workout": return totalActivityCount("sharedWorkout", memberID: memberID, modelContext: modelContext) >= 1

        // Milestone badges
        case "points_100": return totalPoints(memberID: memberID, modelContext: modelContext) >= 100
        case "points_500": return totalPoints(memberID: memberID, modelContext: modelContext) >= 500
        case "points_1000": return totalPoints(memberID: memberID, modelContext: modelContext) >= 1_000
        case "points_5000": return totalPoints(memberID: memberID, modelContext: modelContext) >= 5_000
        case "perfect_week": return currentStreak(memberID: memberID, modelContext: modelContext) >= 7
        case "first_day": return hasAnyPositiveDay(memberID: memberID, modelContext: modelContext)

        default: return false
        }
    }

    // MARK: - Query Helpers

    private func currentStreak(memberID: String, modelContext: ModelContext) -> Int {
        let descriptor = FetchDescriptor<StreakRecord>(
            predicate: #Predicate { $0.memberID == memberID }
        )
        return (try? modelContext.fetch(descriptor).first)?.currentStreak ?? 0
    }

    private func totalPoints(memberID: String, modelContext: ModelContext) -> Double {
        let descriptor = FetchDescriptor<StreakRecord>(
            predicate: #Predicate { $0.memberID == memberID }
        )
        return (try? modelContext.fetch(descriptor).first)?.totalAccumulatedPoints ?? 0
    }

    private func todayActivityValue(_ activityType: String, memberID: String, modelContext: ModelContext) -> Double {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<ActivityRecord>(
            predicate: #Predicate {
                $0.memberID == memberID && $0.date == startOfDay && $0.activityType == activityType
            }
        )
        return (try? modelContext.fetch(descriptor).first)?.rawValue ?? 0
    }

    private func totalActivityCount(_ activityType: String, memberID: String, modelContext: ModelContext) -> Int {
        let descriptor = FetchDescriptor<ActivityRecord>(
            predicate: #Predicate {
                $0.memberID == memberID && $0.activityType == activityType
            }
        )
        return (try? modelContext.fetch(descriptor))?.count ?? 0
    }

    private func consecutiveDaysWithActivity(_ activityType: String, days: Int, memberID: String, modelContext: ModelContext) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for i in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: -i, to: today) else { return false }
            let descriptor = FetchDescriptor<ActivityRecord>(
                predicate: #Predicate {
                    $0.memberID == memberID && $0.date == day && $0.activityType == activityType
                }
            )
            if (try? modelContext.fetch(descriptor))?.isEmpty ?? true {
                return false
            }
        }
        return true
    }

    private func consecutiveDaysWithoutActivity(_ activityType: String, days: Int, memberID: String, modelContext: ModelContext) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for i in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: -i, to: today) else { return false }
            let descriptor = FetchDescriptor<ActivityRecord>(
                predicate: #Predicate {
                    $0.memberID == memberID && $0.date == day && $0.activityType == activityType
                }
            )
            if let records = try? modelContext.fetch(descriptor), !records.isEmpty {
                return false
            }
        }
        return true
    }

    private func noNegativeScreenToday(memberID: String, modelContext: ModelContext) -> Bool {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<ActivityRecord>(
            predicate: #Predicate {
                $0.memberID == memberID && $0.date == startOfDay && $0.category == "bad"
            }
        )
        return (try? modelContext.fetch(descriptor))?.isEmpty ?? true
    }

    private func totalRavesSent(memberID: String, modelContext: ModelContext) -> Int {
        let descriptor = FetchDescriptor<RaveEvent>(
            predicate: #Predicate { $0.fromMemberID == memberID }
        )
        return (try? modelContext.fetch(descriptor))?.count ?? 0
    }

    private func totalRavesReceived(memberID: String, modelContext: ModelContext) -> Int {
        let descriptor = FetchDescriptor<RaveEvent>(
            predicate: #Predicate { $0.toMemberID == memberID }
        )
        return (try? modelContext.fetch(descriptor))?.count ?? 0
    }

    private func todayProximityCount(memberID: String, modelContext: ModelContext) -> Int {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<ProximityEvent>(
            predicate: #Predicate {
                $0.memberID == memberID && $0.timestamp >= startOfDay
            }
        )
        return (try? modelContext.fetch(descriptor))?.count ?? 0
    }

    private func hasAnyPositiveDay(memberID: String, modelContext: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<DailyScore>(
            predicate: #Predicate { $0.memberID == memberID && $0.rawTotal > 0 }
        )
        return !((try? modelContext.fetch(descriptor))?.isEmpty ?? true)
    }
}
