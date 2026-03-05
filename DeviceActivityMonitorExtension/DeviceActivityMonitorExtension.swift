import DeviceActivity
import SwiftData
import Foundation

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    /// Social media bundle IDs to detect
    private let socialMediaBundleIDs: Set<String> = [
        "com.burbn.instagram",
        "com.zhiliaoapp.musically", // TikTok
        "com.toyopagroup.picaboo", // Snapchat
        "com.google.ios.youtube",
        "com.facebook.Facebook",
        "com.atebits.Tweetie2", // X/Twitter
        "com.reddit.Reddit"
    ]

    private var modelContainer: ModelContainer? {
        try? ModelContainer(
            for: UsageRecord.self, ComplianceEvent.self, ActivityRecord.self,
            configurations: ModelConfiguration(
                groupContainer: .identifier(AppConstants.appGroupID)
            )
        )
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        print("DeviceActivity interval started: \(activity.rawValue)")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        print("DeviceActivity interval ended: \(activity.rawValue)")
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        guard let container = modelContainer else { return }
        let context = ModelContext(container)

        let memberID = UserDefaults.shared.string(forKey: AppConstants.UserDefaultsKeys.memberID) ?? "unknown"
        let memberName = UserDefaults.shared.string(forKey: AppConstants.UserDefaultsKeys.memberName) ?? "Unknown"

        let eventName = event.rawValue

        // Check if this is a social media app
        let isSocialMedia = socialMediaBundleIDs.contains(eventName) ||
            eventName.localizedCaseInsensitiveContains("instagram") ||
            eventName.localizedCaseInsensitiveContains("tiktok") ||
            eventName.localizedCaseInsensitiveContains("snapchat") ||
            eventName.localizedCaseInsensitiveContains("youtube") ||
            eventName.localizedCaseInsensitiveContains("facebook") ||
            eventName.localizedCaseInsensitiveContains("twitter")

        if isSocialMedia {
            // Create social media compliance event → triggers notification to all family members
            let complianceEvent = ComplianceEvent(
                memberID: memberID,
                memberName: memberName,
                eventType: .socialMediaUsed,
                details: "Social Media genutzt: \(eventName)"
            )
            context.insert(complianceEvent)
        }

        // Always create the general monitored app compliance event
        let complianceEvent = ComplianceEvent(
            memberID: memberID,
            memberName: memberName,
            eventType: .monitoredAppUsed,
            details: "Ueberwachte App-Nutzungsschwelle erreicht: \(eventName)"
        )
        context.insert(complianceEvent)

        try? context.save()
    }

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        // Optional: warning before interval starts
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        // Optional: warning before interval ends
    }
}
