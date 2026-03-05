import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings

@MainActor
final class ScreenTimeService: ObservableObject {
    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var selectedApps = FamilyActivitySelection()
    @Published var isAuthorized = false
    @Published var errorMessage: String?

    private let center = AuthorizationCenter.shared
    private let deviceActivityCenter = DeviceActivityCenter()

    init() {
        authorizationStatus = center.authorizationStatus
        isAuthorized = authorizationStatus == .approved
    }

    func requestAuthorization() async {
        do {
            try await center.requestAuthorization(for: .individual)
            authorizationStatus = center.authorizationStatus
            isAuthorized = authorizationStatus == .approved
        } catch {
            errorMessage = "Screen Time Autorisierung fehlgeschlagen: \(error.localizedDescription)"
            print("FamilyControls auth error: \(error)")
        }
    }

    func checkAuthorizationStatus() {
        authorizationStatus = center.authorizationStatus
        isAuthorized = authorizationStatus == .approved
    }

    func startMonitoring() {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        do {
            try deviceActivityCenter.startMonitoring(
                .daily,
                during: schedule
            )
        } catch {
            print("Failed to start device activity monitoring: \(error)")
        }
    }

    func stopMonitoring() {
        deviceActivityCenter.stopMonitoring([.daily])
    }

    func saveSelectedApps() {
        // Persist selection to shared UserDefaults
        if let encoded = try? JSONEncoder().encode(selectedApps) {
            UserDefaults.shared.set(encoded, forKey: "selectedFamilyActivities")
        }
    }

    func loadSelectedApps() {
        if let data = UserDefaults.shared.data(forKey: "selectedFamilyActivities"),
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selectedApps = selection
        }
    }
}

extension DeviceActivityName {
    static let daily = DeviceActivityName("daily")
}
