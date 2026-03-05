import Foundation
import SwiftData

enum AppConstants {
    static let appGroupID = "group.com.bettrfamily.shared"
    static let heartbeatIntervalSeconds: TimeInterval = 15 * 60 // 15 minutes
    static let heartbeatAlertThresholdSeconds: TimeInterval = 30 * 60 // 30 minutes

    enum FirestoreCollections {
        static let families = "families"
        static let members = "members"
        static let usageRecords = "usageRecords"
        static let domainRecords = "domainRecords"
        static let complianceEvents = "complianceEvents"
        static let heartbeats = "heartbeats"
        static let monitoredApps = "monitoredApps"
        static let monitoredDomains = "monitoredDomains"
        static let activityRecords = "activityRecords"
        static let dailyScores = "dailyScores"
        static let streakRecords = "streakRecords"
        static let locationSnapshots = "locationSnapshots"
        static let proximityEvents = "proximityEvents"
        static let activityConfig = "activityConfig"
        static let raveEvents = "raveEvents"
        static let badges = "badges"
    }

    enum UserDefaultsKeys {
        static let familyGroupID = "familyGroupID"
        static let memberID = "memberID"
        static let memberName = "memberName"
        static let vpnEnabled = "vpnEnabled"
        static let onboardingComplete = "onboardingComplete"
        static let healthKitAuthorized = "healthKitAuthorized"
        static let locationAuthorized = "locationAuthorized"
        static let lastScoreCalculation = "lastScoreCalculation"
    }
}

/// Shared UserDefaults for App Group
extension UserDefaults {
    static var shared: UserDefaults {
        UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
    }
}

/// Shared schema and ModelContainer factory — all targets MUST use the same schema
/// to avoid SQLite corruption when sharing the App Group database.
enum SharedModelContainer {
    static let schema = Schema([
        UsageRecord.self,
        DomainRecord.self,
        ComplianceEvent.self,
        FamilyMember.self,
        ActivityRecord.self,
        DailyScore.self,
        StreakRecord.self,
        LocationSnapshot.self,
        ProximityEvent.self,
        RaveEvent.self,
        Badge.self
    ])

    static func create() throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(AppConstants.appGroupID)
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
