import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging

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
    @StateObject private var badgeEngine = BadgeEngine()
    @StateObject private var calendarService = CalendarService()

    var sharedModelContainer: ModelContainer = {
        do {
            return try SharedModelContainer.create()
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
                .environmentObject(badgeEngine)
                .environmentObject(calendarService)
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - Root View

struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showSplash = true

    var body: some View {
        ZStack {
            Group {
                if authService.isAuthenticated {
                    if authService.onboardingComplete {
                        MainTabView()
                    } else {
                        SetupView()
                    }
                } else {
                    LoginView()
                }
            }
            .opacity(showSplash ? 0 : 1)

            if showSplash {
                LaunchScreenView()
                    .transition(.opacity)
                    .ignoresSafeArea()
            }
        }
        .animation(.easeOut(duration: 0.5), value: showSplash)
        .task {
            try? await Task.sleep(for: .seconds(1.5))
            showSplash = false
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        // Push notifications
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }

        // FCM
        Messaging.messaging().delegate = self

        // Background task
        HeartbeatService.shared.registerBackgroundTask()

        // Battery monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true

        return true
    }

    // MARK: - Remote Notifications

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // MARK: - FCM Delegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        // Store FCM token in Firestore for this member
        guard let memberID = UserDefaults.shared.string(forKey: AppConstants.UserDefaultsKeys.memberID) else { return }

        Task {
            do {
                try await Firestore.firestore()
                    .collection(AppConstants.FirestoreCollections.members)
                    .document(memberID)
                    .updateData(["fcmToken": fcmToken])
            } catch {
                print("Failed to update FCM token: \(error)")
            }
        }
    }

    // MARK: - Notification Presentation

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
