import SwiftUI
import SwiftData
import FirebaseCore

@main
struct BettrFamilyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authService = AuthService()
    @StateObject private var screenTimeService = ScreenTimeService()
    @StateObject private var vpnMonitor = VPNStatusMonitor()
    @StateObject private var syncService = FirebaseSyncService()
    @StateObject private var familyMonitor = FamilyMonitorService()
    @StateObject private var healthKitService = HealthKitService()
    @StateObject private var pointsEngine = PointsEngine()
    @StateObject private var locationService = LocationService()
    @StateObject private var activityConfigService = ActivityConfigService()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UsageRecord.self,
            DomainRecord.self,
            ComplianceEvent.self,
            FamilyMember.self,
            ActivityRecord.self,
            DailyScore.self,
            StreakRecord.self,
            LocationSnapshot.self,
            ProximityEvent.self,
            RaveEvent.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(AppConstants.appGroupID)
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .environmentObject(screenTimeService)
                .environmentObject(vpnMonitor)
                .environmentObject(syncService)
                .environmentObject(familyMonitor)
                .environmentObject(healthKitService)
                .environmentObject(pointsEngine)
                .environmentObject(locationService)
                .environmentObject(activityConfigService)
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - Root View

struct RootView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        Group {
            if authService.isAuthenticated {
                if UserDefaults.shared.bool(forKey: AppConstants.UserDefaultsKeys.onboardingComplete) {
                    MainTabView()
                } else {
                    SetupView()
                }
            } else {
                LoginView()
            }
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        // Local notifications
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }

        // Background task
        HeartbeatService.shared.registerBackgroundTask()

        // Battery monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true

        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
