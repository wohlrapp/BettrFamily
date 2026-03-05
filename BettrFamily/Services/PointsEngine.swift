import Foundation
import SwiftData

@MainActor
final class PointsEngine: ObservableObject {
    @Published var todayScore: DailyScore?
    @Published var currentStreak: StreakRecord?

    // MARK: - Calculate Daily Score

    func calculateDailyScore(
        for date: Date,
        memberID: String,
        memberName: String,
        modelContext: ModelContext
    ) {
        let startOfDay = Calendar.current.startOfDay(for: date)

        // Fetch all ActivityRecords for the day
        let descriptor = FetchDescriptor<ActivityRecord>(
            predicate: #Predicate { $0.memberID == memberID && $0.date == startOfDay }
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []

        // Fetch RAVE events received today
        let raveDescriptor = FetchDescriptor<RaveEvent>(
            predicate: #Predicate { $0.toMemberID == memberID && $0.date == startOfDay }
        )
        let raveEvents = (try? modelContext.fetch(raveDescriptor)) ?? []
        let ravePoints = raveEvents.reduce(0.0) { $0 + $1.points }

        // Sum by category
        let positivePoints = records.filter { $0.category == "positive" }.reduce(0.0) { $0 + $1.points }
        let negativePoints = records.filter { $0.category == "bad" }.reduce(0.0) { $0 + $1.points }
        let bonusPoints = records.filter { $0.category == "bonus" }.reduce(0.0) { $0 + $1.points } + ravePoints

        // Get or create streak
        let streak = getOrCreateStreak(memberID: memberID, modelContext: modelContext)
        let multiplier = streak.streakMultiplier

        // Get or create daily score
        let scoreDescriptor = FetchDescriptor<DailyScore>(
            predicate: #Predicate { $0.memberID == memberID && $0.date == startOfDay }
        )
        let existingScore = try? modelContext.fetch(scoreDescriptor).first

        if let score = existingScore {
            score.positivePoints = positivePoints
            score.negativePoints = negativePoints
            score.bonusPoints = bonusPoints
            score.rawTotal = positivePoints + negativePoints + bonusPoints
            score.streakMultiplier = multiplier
            score.finalScore = score.rawTotal * multiplier
            score.streakDay = streak.currentStreak
            score.syncedToFirebase = false
            todayScore = score
        } else {
            let score = DailyScore(
                memberID: memberID,
                memberName: memberName,
                date: date,
                positivePoints: positivePoints,
                negativePoints: negativePoints,
                bonusPoints: bonusPoints,
                streakMultiplier: multiplier,
                streakDay: streak.currentStreak
            )
            modelContext.insert(score)
            todayScore = score
        }

        try? modelContext.save()

        UserDefaults.shared.set(Date().timeIntervalSince1970, forKey: AppConstants.UserDefaultsKeys.lastScoreCalculation)
    }

    // MARK: - Update Streak

    func updateStreak(for date: Date, memberID: String, modelContext: ModelContext) {
        let streak = getOrCreateStreak(memberID: memberID, modelContext: modelContext)
        let startOfDay = Calendar.current.startOfDay(for: date)

        // Check yesterday's score
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: startOfDay)!
        let yesterdayDescriptor = FetchDescriptor<DailyScore>(
            predicate: #Predicate { $0.memberID == memberID && $0.date == yesterday }
        )
        let yesterdayScore = try? modelContext.fetch(yesterdayDescriptor).first

        // Check today's score
        let todayDescriptor = FetchDescriptor<DailyScore>(
            predicate: #Predicate { $0.memberID == memberID && $0.date == startOfDay }
        )
        let todayScoreRecord = try? modelContext.fetch(todayDescriptor).first

        if let todayScoreRecord, todayScoreRecord.isPositiveDay {
            // Today is positive
            if let lastPositive = streak.lastPositiveDate {
                let daysSinceLast = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: lastPositive), to: startOfDay).day ?? 0
                if daysSinceLast == 1 {
                    // Consecutive day — extend streak
                    streak.currentStreak += 1
                } else if daysSinceLast == 0 {
                    // Same day — no change
                } else {
                    // Gap — reset streak
                    streak.currentStreak = 1
                }
            } else {
                streak.currentStreak = 1
            }
            streak.lastPositiveDate = startOfDay
            streak.longestStreak = max(streak.longestStreak, streak.currentStreak)
            streak.totalAccumulatedPoints += (todayScoreRecord.finalScore)
        } else if yesterdayScore == nil || !(yesterdayScore?.isPositiveDay ?? false) {
            // Yesterday wasn't positive and today isn't yet — check if streak should reset
            if let lastPositive = streak.lastPositiveDate {
                let daysSinceLast = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: lastPositive), to: startOfDay).day ?? 0
                if daysSinceLast > 1 {
                    streak.currentStreak = 0
                }
            }
        }

        streak.syncedToFirebase = false
        currentStreak = streak

        try? modelContext.save()
    }

    // MARK: - Save Screen Time Activities

    func processScreenTimeRecords(
        usageRecords: [UsageRecord],
        memberID: String,
        date: Date,
        config: FamilyActivityConfig,
        modelContext: ModelContext
    ) {
        let startOfDay = Calendar.current.startOfDay(for: date)

        // Total screen time in minutes
        let totalScreenMinutes = Double(usageRecords.reduce(0) { $0 + $1.durationSeconds }) / 60.0

        // Excessive screen time (>2h)
        if totalScreenMinutes > 120,
           let cfg = config.activities.first(where: { $0.activityType == "excessiveScreenTime" && $0.isEnabled }) {
            let excessMinutes = totalScreenMinutes - 120
            let units = floor(excessMinutes / cfg.unitThreshold)
            let points = units * cfg.pointsPerUnit
            if abs(points) > 0 {
                insertOrUpdateRecord(
                    memberID: memberID, date: startOfDay,
                    activityType: "excessiveScreenTime", category: .bad,
                    rawValue: excessMinutes, unit: "minutes",
                    points: points, source: "screentime",
                    modelContext: modelContext
                )
            }
        }

        // Social media time
        let socialMediaMinutes = Double(usageRecords
            .filter { config.socialMediaBundleIDs.contains($0.appBundleID) }
            .reduce(0) { $0 + $1.durationSeconds }) / 60.0

        if socialMediaMinutes > 0,
           let cfg = config.activities.first(where: { $0.activityType == "socialMedia" && $0.isEnabled }) {
            let units = floor(socialMediaMinutes / cfg.unitThreshold)
            let points = units * cfg.pointsPerUnit
            if abs(points) > 0 {
                insertOrUpdateRecord(
                    memberID: memberID, date: startOfDay,
                    activityType: "socialMedia", category: .bad,
                    rawValue: socialMediaMinutes, unit: "minutes",
                    points: points, source: "screentime",
                    modelContext: modelContext
                )
            }
        }

        // Late night screen (after 22:00)
        let calendar = Calendar.current
        let lateNightCount = usageRecords.filter { record in
            let hour = calendar.component(.hour, from: record.startTime)
            return hour >= 22
        }.count

        if lateNightCount > 0,
           let cfg = config.activities.first(where: { $0.activityType == "lateNightScreen" && $0.isEnabled }) {
            let points = Double(lateNightCount) * cfg.pointsPerUnit
            insertOrUpdateRecord(
                memberID: memberID, date: startOfDay,
                activityType: "lateNightScreen", category: .bad,
                rawValue: Double(lateNightCount), unit: "count",
                points: points, source: "screentime",
                modelContext: modelContext
            )
        }

        // Streaming apps
        let streamingBundleIDs = [
            "com.netflix.Netflix",
            "com.amazon.aiv.AIVApp", // Prime Video
            "com.disney.disneyplus",
            "com.hbo.hbonow" // Max/HBO
        ]
        let streamingMinutes = Double(usageRecords
            .filter { streamingBundleIDs.contains($0.appBundleID) }
            .reduce(0) { $0 + $1.durationSeconds }) / 60.0

        if streamingMinutes > 0,
           let cfg = config.activities.first(where: { $0.activityType == "streaming" && $0.isEnabled }) {
            let units = floor(streamingMinutes / cfg.unitThreshold)
            let points = units * cfg.pointsPerUnit
            if abs(points) > 0 {
                insertOrUpdateRecord(
                    memberID: memberID, date: startOfDay,
                    activityType: "streaming", category: .bad,
                    rawValue: streamingMinutes, unit: "minutes",
                    points: points, source: "screentime",
                    modelContext: modelContext
                )
            }
        }

        // Gaming apps
        let gamingBundleIDs = [
            "com.supercell.laser", "com.king.candycrush", "com.mojang.minecraftpe",
            "com.innersloth.amongus", "com.epicgames.fortnite"
        ]
        let gamingMinutes = Double(usageRecords
            .filter { gamingBundleIDs.contains($0.appBundleID) }
            .reduce(0) { $0 + $1.durationSeconds }) / 60.0

        if gamingMinutes > 0,
           let cfg = config.activities.first(where: { $0.activityType == "gaming" && $0.isEnabled }) {
            let units = floor(gamingMinutes / cfg.unitThreshold)
            let points = units * cfg.pointsPerUnit
            if abs(points) > 0 {
                insertOrUpdateRecord(
                    memberID: memberID, date: startOfDay,
                    activityType: "gaming", category: .bad,
                    rawValue: gamingMinutes, unit: "minutes",
                    points: points, source: "screentime",
                    modelContext: modelContext
                )
            }
        }

        try? modelContext.save()
    }

    // MARK: - Process Domain Records (VPN/DNS)

    func processDomainRecords(
        memberID: String,
        memberName: String,
        date: Date,
        config: FamilyActivityConfig,
        modelContext: ModelContext
    ) {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<DomainRecord>(
            predicate: #Predicate {
                $0.memberID == memberID && $0.timestamp >= startOfDay && $0.timestamp < endOfDay
            }
        )
        guard let records = try? modelContext.fetch(descriptor), !records.isEmpty else { return }

        // Count unique domain hits per category
        let socialMediaHits = countDomainHits(records: records, domains: config.socialMediaDomains)
        let streamingHits = countDomainHits(records: records, domains: config.streamingDomains)
        let gamingHits = countDomainHits(records: records, domains: config.gamingDomains)

        // Social media domains → negative points + compliance event
        if socialMediaHits > 0,
           let cfg = config.activities.first(where: { $0.activityType == "socialMediaDomain" && $0.isEnabled })
            ?? config.activities.first(where: { $0.activityType == "socialMedia" && $0.isEnabled }) {
            let points = Double(socialMediaHits) * cfg.pointsPerUnit
            insertOrUpdateRecord(
                memberID: memberID, date: startOfDay,
                activityType: "socialMediaDomain", category: .bad,
                rawValue: Double(socialMediaHits), unit: "count",
                points: points, source: "dns",
                modelContext: modelContext
            )

            // Create compliance event for social media domain access
            createDomainComplianceEvent(
                memberID: memberID,
                memberName: memberName,
                date: startOfDay,
                records: records,
                domains: config.socialMediaDomains,
                modelContext: modelContext
            )
        }

        // Streaming domains
        if streamingHits > 0,
           let cfg = config.activities.first(where: { $0.activityType == "streamingDomain" && $0.isEnabled })
            ?? config.activities.first(where: { $0.activityType == "streaming" && $0.isEnabled }) {
            let points = Double(streamingHits) * cfg.pointsPerUnit
            insertOrUpdateRecord(
                memberID: memberID, date: startOfDay,
                activityType: "streamingDomain", category: .bad,
                rawValue: Double(streamingHits), unit: "count",
                points: points, source: "dns",
                modelContext: modelContext
            )
        }

        // Gaming domains
        if gamingHits > 0,
           let cfg = config.activities.first(where: { $0.activityType == "gamingDomain" && $0.isEnabled })
            ?? config.activities.first(where: { $0.activityType == "gaming" && $0.isEnabled }) {
            let points = Double(gamingHits) * cfg.pointsPerUnit
            insertOrUpdateRecord(
                memberID: memberID, date: startOfDay,
                activityType: "gamingDomain", category: .bad,
                rawValue: Double(gamingHits), unit: "count",
                points: points, source: "dns",
                modelContext: modelContext
            )
        }

        try? modelContext.save()
    }

    private func countDomainHits(records: [DomainRecord], domains: [String]) -> Int {
        let matchingDomains = Set(records.compactMap { record -> String? in
            let domain = record.domain.lowercased()
            return domains.first(where: { domain.hasSuffix($0) })
        })
        return records.filter { record in
            let domain = record.domain.lowercased()
            return domains.contains(where: { domain.hasSuffix($0) })
        }.count
    }

    private func createDomainComplianceEvent(
        memberID: String,
        memberName: String,
        date: Date,
        records: [DomainRecord],
        domains: [String],
        modelContext: ModelContext
    ) {
        // Find which social media domains were accessed
        let accessedDomains = Set(records.compactMap { record -> String? in
            let domain = record.domain.lowercased()
            return domains.first(where: { domain.hasSuffix($0) })
        })

        guard !accessedDomains.isEmpty else { return }

        // Check if we already created a compliance event today for this
        let eventType = ComplianceEventType.socialMediaUsed.rawValue
        let descriptor = FetchDescriptor<ComplianceEvent>(
            predicate: #Predicate {
                $0.memberID == memberID && $0.eventType == eventType && $0.timestamp >= date
            }
        )
        if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty { return }

        let event = ComplianceEvent(
            memberID: memberID,
            memberName: memberName,
            eventType: .socialMediaUsed,
            details: "Social Media im Browser: \(accessedDomains.sorted().joined(separator: ", "))"
        )
        modelContext.insert(event)
    }

    // MARK: - Helpers

    private func getOrCreateStreak(memberID: String, modelContext: ModelContext) -> StreakRecord {
        let descriptor = FetchDescriptor<StreakRecord>(
            predicate: #Predicate { $0.memberID == memberID }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let streak = StreakRecord(memberID: memberID)
        modelContext.insert(streak)
        return streak
    }

    private func insertOrUpdateRecord(
        memberID: String, date: Date,
        activityType: String, category: ActivityCategory,
        rawValue: Double, unit: String,
        points: Double, source: String,
        modelContext: ModelContext
    ) {
        let descriptor = FetchDescriptor<ActivityRecord>(
            predicate: #Predicate {
                $0.memberID == memberID && $0.date == date && $0.activityType == activityType
            }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.rawValue = rawValue
            existing.points = points
            existing.syncedToFirebase = false
        } else {
            let record = ActivityRecord(
                memberID: memberID, date: date,
                activityType: activityType, category: category,
                rawValue: rawValue, unit: unit,
                points: points, source: source
            )
            modelContext.insert(record)
        }
    }
}
