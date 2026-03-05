import Foundation
import CoreLocation
import CoreBluetooth
import SwiftData

@MainActor
final class LocationService: NSObject, ObservableObject {
    @Published var isLocationAuthorized = false
    @Published var isBluetoothAvailable = false
    @Published var nearbyMembers: [String] = []
    @Published var errorMessage: String?

    private(set) var locationManager: CLLocationManager?
    private var peripheralManager: CBPeripheralManager?
    private var centralManager: CBCentralManager?

    private var memberID: String?
    private var familyGroupID: String?
    private var modelContext: ModelContext?

    // Family-specific BLE service UUID derived from familyGroupID
    private var familyServiceUUID: CBUUID? {
        guard let familyGroupID else { return nil }
        // Create a deterministic UUID5-like value from familyGroupID
        // Pad or truncate to 16 bytes for uuid_t
        var bytes = Array(familyGroupID.utf8)
        while bytes.count < 16 { bytes.append(0) }
        let uuid = uuid_t(
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return CBUUID(string: UUID(uuid: uuid).uuidString)
    }

    private let memberIDCharacteristicUUID = CBUUID(string: "2A00")

    override init() {
        super.init()
        // Check current authorization status without triggering a prompt
        let manager = CLLocationManager()
        let status = manager.authorizationStatus
        isLocationAuthorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
    }

    // MARK: - Setup

    func configure(memberID: String, familyGroupID: String, modelContext: ModelContext) {
        self.memberID = memberID
        self.familyGroupID = familyGroupID
        self.modelContext = modelContext
    }

    // MARK: - Location

    func requestLocationAuthorization() {
        let manager = CLLocationManager()
        manager.delegate = self
        manager.allowsBackgroundLocationUpdates = false
        self.locationManager = manager
        manager.requestWhenInUseAuthorization()
    }

    func startSignificantLocationMonitoring() {
        guard CLLocationManager.significantLocationChangeMonitoringAvailable() else {
            errorMessage = "Standort-Monitoring nicht verfuegbar."
            return
        }
        locationManager?.startMonitoringSignificantLocationChanges()
        UserDefaults.shared.set(true, forKey: AppConstants.UserDefaultsKeys.locationAuthorized)
    }

    func stopLocationMonitoring() {
        locationManager?.stopMonitoringSignificantLocationChanges()
    }

    // MARK: - Bluetooth

    func startBluetoothProximity() {
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func stopBluetoothProximity() {
        peripheralManager?.stopAdvertising()
        centralManager?.stopScan()
        peripheralManager = nil
        centralManager = nil
        nearbyMembers = []
    }

    // MARK: - Save Location

    private func saveLocationSnapshot(latitude: Double, longitude: Double) {
        guard let memberID, let modelContext else { return }

        let snapshot = LocationSnapshot(
            memberID: memberID,
            latitude: latitude,
            longitude: longitude
        )
        modelContext.insert(snapshot)
        try? modelContext.save()
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            saveLocationSnapshot(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                isLocationAuthorized = true
            default:
                isLocationAuthorized = false
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            errorMessage = "Standort-Fehler: \(error.localizedDescription)"
        }
    }
}

// MARK: - CBPeripheralManagerDelegate

extension LocationService: CBPeripheralManagerDelegate {
    nonisolated func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        Task { @MainActor in
            guard peripheral.state == .poweredOn,
                  let familyServiceUUID,
                  let memberID else { return }

            isBluetoothAvailable = true

            // Advertise our presence
            peripheral.startAdvertising([
                CBAdvertisementDataServiceUUIDsKey: [familyServiceUUID],
                CBAdvertisementDataLocalNameKey: memberID
            ])
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension LocationService: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            guard central.state == .poweredOn, let familyServiceUUID else { return }

            // Scan for family members
            central.scanForPeripherals(withServices: [familyServiceUUID], options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: false
            ])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        Task { @MainActor in
            guard let discoveredMemberID = advertisementData[CBAdvertisementDataLocalNameKey] as? String,
                  let memberID,
                  discoveredMemberID != memberID,
                  let modelContext else { return }

            if !nearbyMembers.contains(discoveredMemberID) {
                nearbyMembers.append(discoveredMemberID)

                // Create proximity event
                let event = ProximityEvent(
                    memberID: memberID,
                    nearbyMemberID: discoveredMemberID,
                    nearbyMemberName: discoveredMemberID, // Will be resolved later
                    detectionType: "bluetooth"
                )
                modelContext.insert(event)
                try? modelContext.save()
            }
        }
    }
}
