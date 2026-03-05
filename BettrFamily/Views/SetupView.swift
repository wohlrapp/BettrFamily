import SwiftUI
import FamilyControls

struct SetupView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var screenTimeService: ScreenTimeService
    @EnvironmentObject var vpnMonitor: VPNStatusMonitor
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var locationService: LocationService
    @State private var currentStep = 0

    private let totalSteps = 5

    var body: some View {
        NavigationStack {
            VStack {
                // Progress
                ProgressView(value: Double(currentStep), total: Double(totalSteps))
                    .padding()

                TabView(selection: $currentStep) {
                    screenTimeStep.tag(0)
                    appSelectionStep.tag(1)
                    vpnStep.tag(2)
                    healthKitStep.tag(3)
                    locationStep.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
            }
            .navigationTitle("Einrichtung")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Step 1: Screen Time Authorization

    private var screenTimeStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "hourglass")
                .font(.system(size: 50))
                .foregroundStyle(.blue)

            Text("Screen Time Zugriff")
                .font(.title2.bold())

            Text("BettrFamily benoetigt Zugriff auf die Screen Time API, um App-Nutzung transparent zu erfassen.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if screenTimeService.isAuthorized {
                Label("Autorisiert", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            Button(screenTimeService.isAuthorized ? "Weiter" : "Zugriff erlauben") {
                if screenTimeService.isAuthorized {
                    currentStep = 1
                } else {
                    Task {
                        await screenTimeService.requestAuthorization()
                        if screenTimeService.isAuthorized {
                            currentStep = 1
                        }
                    }
                }
            }
            .buttonStyle(.borderedProminent)

            if let error = screenTimeService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Step 2: App Selection

    private var appSelectionStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "app.badge.checkmark")
                .font(.system(size: 50))
                .foregroundStyle(.blue)

            Text("Apps auswaehlen")
                .font(.title2.bold())

            Text("Waehle die Apps aus, deren Nutzung erfasst werden soll. Alle Familienmitglieder koennen diese Auswahl aendern.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            FamilyActivityPicker(selection: $screenTimeService.selectedApps)
                .frame(maxHeight: 300)

            Button("Weiter") {
                screenTimeService.saveSelectedApps()
                screenTimeService.startMonitoring()
                currentStep = 2
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
    }

    // MARK: - Step 3: VPN Setup

    private var vpnStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "network.badge.shield.half.filled")
                .font(.system(size: 50))
                .foregroundStyle(.blue)

            Text("DNS-Monitoring")
                .font(.title2.bold())

            Text("Ein lokales VPN erfasst welche Domains aufgerufen werden. Der Traffic wird nicht umgeleitet — nur DNS-Anfragen werden protokolliert.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if vpnMonitor.isVPNActive {
                Label("VPN aktiv", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            Button(vpnMonitor.isVPNActive ? "Weiter" : "VPN aktivieren") {
                if vpnMonitor.isVPNActive {
                    currentStep = 3
                } else {
                    Task {
                        await vpnMonitor.loadAndMonitor()
                        vpnMonitor.startVPN()
                    }
                }
            }
            .buttonStyle(.borderedProminent)

            if !vpnMonitor.isVPNActive {
                Button("Ueberspringen") {
                    currentStep = 3
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Step 4: HealthKit

    private var healthKitStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "heart.fill")
                .font(.system(size: 50))
                .foregroundStyle(.red)

            Text("Gesundheitsdaten")
                .font(.title2.bold())

            Text("BettrFamily erfasst Schritte, Workouts, Schlaf und weitere Gesundheitsdaten, um Punkte fuer gesunde Aktivitaeten zu vergeben.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if healthKitService.isAuthorized {
                Label("Autorisiert", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            Button(healthKitService.isAuthorized ? "Weiter" : "Zugriff erlauben") {
                if healthKitService.isAuthorized {
                    currentStep = 4
                } else {
                    Task {
                        await healthKitService.requestAuthorization()
                        if healthKitService.isAuthorized {
                            currentStep = 4
                        }
                    }
                }
            }
            .buttonStyle(.borderedProminent)

            Button("Ueberspringen") {
                currentStep = 4
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            if let error = healthKitService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Step 5: Location

    private var locationStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "location.fill")
                .font(.system(size: 50))
                .foregroundStyle(.blue)

            Text("Standort & Naehe")
                .font(.title2.bold())

            Text("Standort-Zugriff ermoeglicht Bonus-Punkte, wenn Familienmitglieder Zeit zusammen verbringen. Es werden nur grobe Standortaenderungen erfasst.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if locationService.isLocationAuthorized {
                Label("Autorisiert", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            Button(locationService.isLocationAuthorized ? "Fertig" : "Standort erlauben") {
                if locationService.isLocationAuthorized {
                    finishSetup()
                } else {
                    locationService.requestLocationAuthorization()
                }
            }
            .buttonStyle(.borderedProminent)

            Button("Ueberspringen") {
                finishSetup()
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            if let error = locationService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .padding()
    }

    private func finishSetup() {
        UserDefaults.shared.set(true, forKey: AppConstants.UserDefaultsKeys.onboardingComplete)
        HeartbeatService.shared.startHeartbeat()
        HeartbeatService.shared.scheduleBackgroundTask()

        if locationService.isLocationAuthorized {
            locationService.startSignificantLocationMonitoring()
            locationService.startBluetoothProximity()
        }
    }
}
