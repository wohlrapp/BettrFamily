import DeviceActivity
import SwiftUI
import SwiftData

struct DeviceActivityReportExtension: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity

    let content: ([AppUsageInfo]) -> TotalActivityView

    /// Social media bundle IDs — matches ActivityConfig defaults
    private static let socialMediaBundleIDs: Set<String> = [
        "com.burbn.instagram",
        "com.zhiliaoapp.musically",
        "com.toyopagroup.picaboo",
        "com.google.ios.youtube",
        "com.facebook.Facebook",
        "com.atebits.Tweetie2",
        "com.reddit.Reddit"
    ]

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> [AppUsageInfo] {
        var usages: [AppUsageInfo] = []

        for await activityData in data {
            for await categoryActivity in activityData.activitySegments {
                for await appActivity in categoryActivity.categories {
                    let totalDuration = appActivity.totalActivityDuration
                    guard totalDuration > 0 else { continue }

                    let name = appActivity.category.localizedDisplayName ?? "Unknown"
                    usages.append(AppUsageInfo(
                        bundleID: name,
                        displayName: name,
                        durationSeconds: Int(totalDuration)
                    ))
                }
            }
        }

        // Save to shared container
        await saveToSharedContainer(usages: usages)

        return usages.sorted { $0.durationSeconds > $1.durationSeconds }
    }

    private func saveToSharedContainer(usages: [AppUsageInfo]) async {
        guard let container = try? ModelContainer(
            for: UsageRecord.self, ComplianceEvent.self,
            configurations: ModelConfiguration(
                groupContainer: .identifier(AppConstants.appGroupID)
            )
        ) else { return }

        let context = ModelContext(container)
        let memberID = UserDefaults.shared.string(forKey: AppConstants.UserDefaultsKeys.memberID) ?? "unknown"
        let memberName = UserDefaults.shared.string(forKey: AppConstants.UserDefaultsKeys.memberName) ?? "Unknown"

        for usage in usages {
            let record = UsageRecord(
                memberID: memberID,
                appBundleID: usage.bundleID,
                appName: usage.displayName,
                startTime: Calendar.current.startOfDay(for: Date()),
                endTime: Date(),
                durationSeconds: usage.durationSeconds
            )
            context.insert(record)

            // Flag social media usage as compliance event
            if Self.socialMediaBundleIDs.contains(usage.bundleID) {
                let event = ComplianceEvent(
                    memberID: memberID,
                    memberName: memberName,
                    eventType: .socialMediaUsed,
                    details: "Social Media genutzt: \(usage.displayName) (\(usage.formattedDuration))"
                )
                context.insert(event)
            }
        }

        try? context.save()
    }
}

struct TotalActivityView: View {
    let appUsages: [AppUsageInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if appUsages.isEmpty {
                Text("Keine Nutzungsdaten")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appUsages, id: \.bundleID) { usage in
                    HStack {
                        Text(usage.displayName)
                            .font(.subheadline)
                        Spacer()
                        Text(usage.formattedDuration)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

struct AppUsageInfo {
    let bundleID: String
    let displayName: String
    let durationSeconds: Int

    var formattedDuration: String {
        let hours = durationSeconds / 3600
        let minutes = (durationSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

extension DeviceActivityReport.Context {
    static let totalActivity = DeviceActivityReport.Context("Total Activity")
}
