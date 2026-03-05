import SwiftUI
import FamilyControls

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var screenTimeService: ScreenTimeService
    @EnvironmentObject var vpnMonitor: VPNStatusMonitor
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var locationService: LocationService
    @State private var showFamilyCode = false
    @State private var showAppPicker = false
    @State private var showSignOutConfirm = false
    @State private var showActivityConfig = false

    var body: some View {
        NavigationStack {
            List {
                // Profile
                Section("Profil") {
                    LabeledContent("Name", value: authService.memberName ?? "—")
                    LabeledContent("E-Mail", value: authService.currentUser?.email ?? "—")
                    LabeledContent("Geraet", value: UIDevice.current.name)
                }

                // Family
                Section("Familie") {
                    if let code = authService.familyGroupID {
                        HStack {
                            LabeledContent("Family-Code", value: showFamilyCode ? code : "••••••••")
                            Button(showFamilyCode ? "Verbergen" : "Anzeigen") {
                                showFamilyCode.toggle()
                            }
                            .font(.caption)
                        }
                    }
                    Text("Teile den Family-Code mit anderen Familienmitgliedern, damit sie der Gruppe beitreten koennen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Monitoring
                Section("Monitoring") {
                    HStack {
                        Text("Screen Time")
                        Spacer()
                        Text(screenTimeService.isAuthorized ? "Aktiv" : "Inaktiv")
                            .foregroundStyle(screenTimeService.isAuthorized ? .green : .red)
                    }

                    Button("Ueberwachte Apps aendern") {
                        showAppPicker = true
                    }

                    HStack {
                        Text("VPN (DNS-Monitoring)")
                        Spacer()
                        Text(vpnMonitor.isVPNActive ? "Aktiv" : "Inaktiv")
                            .foregroundStyle(vpnMonitor.isVPNActive ? .green : .red)
                    }

                    if vpnMonitor.isVPNActive {
                        Button("VPN deaktivieren", role: .destructive) {
                            vpnMonitor.stopVPN()
                        }
                    } else {
                        Button("VPN aktivieren") {
                            vpnMonitor.startVPN()
                        }
                    }
                }

                // Punkte-System
                Section("Punkte-System") {
                    HStack {
                        Text("HealthKit")
                        Spacer()
                        Text(healthKitService.isAuthorized ? "Aktiv" : "Inaktiv")
                            .foregroundStyle(healthKitService.isAuthorized ? .green : .red)
                    }

                    if !healthKitService.isAuthorized {
                        Button("HealthKit aktivieren") {
                            Task { await healthKitService.requestAuthorization() }
                        }
                    }

                    HStack {
                        Text("Standort")
                        Spacer()
                        Text(locationService.isLocationAuthorized ? "Aktiv" : "Inaktiv")
                            .foregroundStyle(locationService.isLocationAuthorized ? .green : .red)
                    }

                    Button("Aktivitaeten konfigurieren") {
                        showActivityConfig = true
                    }
                }

                // Account
                Section {
                    Button("Abmelden", role: .destructive) {
                        showSignOutConfirm = true
                    }
                }
            }
            .navigationTitle("Einstellungen")
            .sheet(isPresented: $showAppPicker) {
                NavigationStack {
                    FamilyActivityPicker(selection: $screenTimeService.selectedApps)
                        .navigationTitle("Apps auswaehlen")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Fertig") {
                                    screenTimeService.saveSelectedApps()
                                    screenTimeService.startMonitoring()
                                    showAppPicker = false
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showActivityConfig) {
                ActivityConfigView()
            }
            .confirmationDialog("Abmelden?", isPresented: $showSignOutConfirm) {
                Button("Abmelden", role: .destructive) {
                    try? authService.signOut()
                }
                Button("Abbrechen", role: .cancel) {}
            }
        }
    }
}
