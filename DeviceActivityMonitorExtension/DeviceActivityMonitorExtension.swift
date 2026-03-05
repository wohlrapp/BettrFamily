import DeviceActivity
import SwiftData
import Foundation

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private var modelContainer: ModelContainer? {
        try? ModelContainer(
            for: UsageRecord.self, ComplianceEvent.self,
            configurations: ModelConfiguration(
                groupContainer: .identifier(AppConstants.appGroupID)
            )
        )
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        // Called when a new monitoring interval begins (daily reset)
        print("DeviceActivity interval started: \(activity.rawValue)")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        // Called when a monitoring interval ends
        print("DeviceActivity interval ended: \(activity.rawValue)")
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        // Called when a monitored app reaches usage threshold
        guard let container = modelContainer else { return }
        let context = ModelContext(container)

        let memberID = UserDefaults.shared.string(forKey: AppConstants.UserDefaultsKeys.memberID) ?? "unknown"
        let memberName = UserDefaults.shared.string(forKey: AppConstants.UserDefaultsKeys.memberName) ?? "Unknown"

        let complianceEvent = ComplianceEvent(
            memberID: memberID,
            memberName: memberName,
            eventType: .monitoredAppUsed,
            details: "Ueberwachte App-Nutzungsschwelle erreicht: \(event.rawValue)"
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
