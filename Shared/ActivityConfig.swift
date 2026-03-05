import Foundation

/// Codable config for activity point values — shared across family via Firestore (not SwiftData)
struct ActivityPointConfig: Codable, Identifiable {
    var id: String { activityType }
    let activityType: String
    let displayName: String
    var category: String // ActivityCategory.rawValue
    var pointsPerUnit: Double
    var unitThreshold: Double // e.g. 1000 for steps, 30 for minutes
    var unit: String
    var isEnabled: Bool

    static let defaults: [ActivityPointConfig] = [
        // Positive
        ActivityPointConfig(activityType: "steps", displayName: "Schritte", category: "positive", pointsPerUnit: 1, unitThreshold: 1000, unit: "steps", isEnabled: true),
        ActivityPointConfig(activityType: "distanceWalking", displayName: "Gehen/Laufen", category: "positive", pointsPerUnit: 2, unitThreshold: 1, unit: "km", isEnabled: true),
        ActivityPointConfig(activityType: "distanceCycling", displayName: "Radfahren", category: "positive", pointsPerUnit: 1.5, unitThreshold: 1, unit: "km", isEnabled: true),
        ActivityPointConfig(activityType: "activeEnergy", displayName: "Aktive Energie", category: "positive", pointsPerUnit: 1, unitThreshold: 100, unit: "kcal", isEnabled: true),
        ActivityPointConfig(activityType: "exerciseTime", displayName: "Trainingszeit", category: "positive", pointsPerUnit: 2, unitThreshold: 30, unit: "minutes", isEnabled: true),
        ActivityPointConfig(activityType: "workouts", displayName: "Workouts", category: "positive", pointsPerUnit: 3, unitThreshold: 1, unit: "count", isEnabled: true),
        ActivityPointConfig(activityType: "flightsClimbed", displayName: "Stockwerke", category: "positive", pointsPerUnit: 1, unitThreshold: 3, unit: "flights", isEnabled: true),
        ActivityPointConfig(activityType: "mindfulSession", displayName: "Achtsamkeit", category: "positive", pointsPerUnit: 3, unitThreshold: 1, unit: "count", isEnabled: true),
        ActivityPointConfig(activityType: "goodSleep", displayName: "Guter Schlaf (7-9h)", category: "positive", pointsPerUnit: 5, unitThreshold: 1, unit: "flat", isEnabled: true),
        ActivityPointConfig(activityType: "timeInDaylight", displayName: "Zeit im Tageslicht", category: "positive", pointsPerUnit: 1, unitThreshold: 30, unit: "minutes", isEnabled: true),
        ActivityPointConfig(activityType: "standHours", displayName: "Steh-Stunden", category: "positive", pointsPerUnit: 0.5, unitThreshold: 1, unit: "hours", isEnabled: true),
        ActivityPointConfig(activityType: "toothbrushing", displayName: "Zaehneputzen", category: "positive", pointsPerUnit: 2, unitThreshold: 1, unit: "count", isEnabled: true),

        // Bad
        ActivityPointConfig(activityType: "excessiveScreenTime", displayName: "Ueberm. Bildschirmzeit (>2h)", category: "bad", pointsPerUnit: -1, unitThreshold: 30, unit: "minutes", isEnabled: true),
        ActivityPointConfig(activityType: "socialMedia", displayName: "Social Media", category: "bad", pointsPerUnit: -2, unitThreshold: 30, unit: "minutes", isEnabled: true),
        ActivityPointConfig(activityType: "streaming", displayName: "Streaming (Netflix etc.)", category: "bad", pointsPerUnit: -1, unitThreshold: 30, unit: "minutes", isEnabled: true),
        ActivityPointConfig(activityType: "gaming", displayName: "Gaming Apps", category: "bad", pointsPerUnit: -1, unitThreshold: 30, unit: "minutes", isEnabled: true),
        ActivityPointConfig(activityType: "lateNightScreen", displayName: "Spaete Bildschirmzeit (>22h)", category: "bad", pointsPerUnit: -3, unitThreshold: 1, unit: "count", isEnabled: true),
        ActivityPointConfig(activityType: "shortSleep", displayName: "Wenig Schlaf (<6h)", category: "bad", pointsPerUnit: -5, unitThreshold: 1, unit: "flat", isEnabled: true),
        ActivityPointConfig(activityType: "alcohol", displayName: "Alkohol", category: "bad", pointsPerUnit: -2, unitThreshold: 1, unit: "count", isEnabled: true),
        ActivityPointConfig(activityType: "socialMediaDomain", displayName: "Social Media (Browser)", category: "bad", pointsPerUnit: -2, unitThreshold: 1, unit: "count", isEnabled: true),
        ActivityPointConfig(activityType: "streamingDomain", displayName: "Streaming (Browser)", category: "bad", pointsPerUnit: -1, unitThreshold: 1, unit: "count", isEnabled: true),
        ActivityPointConfig(activityType: "gamingDomain", displayName: "Gaming (Browser)", category: "bad", pointsPerUnit: -1, unitThreshold: 1, unit: "count", isEnabled: true),

        // Bonus
        ActivityPointConfig(activityType: "proximity", displayName: "Zusammen (BLE)", category: "bonus", pointsPerUnit: 3, unitThreshold: 30, unit: "minutes", isEnabled: true),
        ActivityPointConfig(activityType: "coLocation", displayName: "Gleicher Ort (GPS)", category: "bonus", pointsPerUnit: 2, unitThreshold: 1, unit: "count", isEnabled: true),
        ActivityPointConfig(activityType: "sharedWorkout", displayName: "Gemeinsames Training", category: "bonus", pointsPerUnit: 5, unitThreshold: 1, unit: "count", isEnabled: true),
    ]
}

/// Wrapper for the full family config
struct FamilyActivityConfig: Codable {
    var activities: [ActivityPointConfig]
    var socialMediaBundleIDs: [String]

    static let defaultSocialMediaBundleIDs = [
        "com.burbn.instagram",
        "com.zhiliaoapp.musically", // TikTok
        "com.toyopagroup.picaboo", // Snapchat
        "com.google.ios.youtube",
        "com.facebook.Facebook",
        "com.atebits.Tweetie2", // X/Twitter
        "com.reddit.Reddit"
    ]

    var socialMediaDomains: [String]
    var streamingDomains: [String]
    var gamingDomains: [String]

    static let defaultSocialMediaDomains = [
        "instagram.com",
        "tiktok.com",
        "snapchat.com",
        "youtube.com",
        "facebook.com",
        "twitter.com",
        "x.com",
        "reddit.com",
        "threads.net"
    ]

    static let defaultStreamingDomains = [
        "netflix.com",
        "disneyplus.com",
        "primevideo.com",
        "hbomax.com",
        "max.com",
        "twitch.tv"
    ]

    static let defaultGamingDomains = [
        "roblox.com",
        "fortnite.com",
        "epicgames.com",
        "supercell.com"
    ]

    static let `default` = FamilyActivityConfig(
        activities: ActivityPointConfig.defaults,
        socialMediaBundleIDs: defaultSocialMediaBundleIDs,
        socialMediaDomains: defaultSocialMediaDomains,
        streamingDomains: defaultStreamingDomains,
        gamingDomains: defaultGamingDomains
    )
}
