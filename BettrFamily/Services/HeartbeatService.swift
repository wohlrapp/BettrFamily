import Foundation
import FirebaseFirestore
import BackgroundTasks
import UIKit

final class HeartbeatService {
    static let shared = HeartbeatService()
    static let bgTaskIdentifier = "com.bettrfamily.heartbeat"

    private let db = Firestore.firestore()
    private var timer: Timer?

    private init() {}

    func startHeartbeat() {
        // Send immediately
        Task { await sendHeartbeat() }

        // Schedule periodic heartbeats
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            withTimeInterval: AppConstants.heartbeatIntervalSeconds,
            repeats: true
        ) { [weak self] _ in
            Task { await self?.sendHeartbeat() }
        }
    }

    func stopHeartbeat() {
        timer?.invalidate()
        timer = nil
    }

    func sendHeartbeat() async {
        guard let memberID = UserDefaults.shared.string(forKey: AppConstants.UserDefaultsKeys.memberID),
              let familyGroupID = UserDefaults.shared.string(forKey: AppConstants.UserDefaultsKeys.familyGroupID)
        else { return }

        let heartbeatData: [String: Any] = [
            "memberID": memberID,
            "memberName": UserDefaults.shared.string(forKey: AppConstants.UserDefaultsKeys.memberName) ?? "Unknown",
            "timestamp": FieldValue.serverTimestamp(),
            "deviceName": UIDevice.current.name,
            "vpnActive": UserDefaults.shared.bool(forKey: AppConstants.UserDefaultsKeys.vpnEnabled),
            "batteryLevel": UIDevice.current.batteryLevel
        ]

        do {
            try await db.collection(AppConstants.FirestoreCollections.families)
                .document(familyGroupID)
                .collection(AppConstants.FirestoreCollections.heartbeats)
                .document(memberID)
                .setData(heartbeatData)
        } catch {
            print("Failed to send heartbeat: \(error)")
        }
    }

    // MARK: - Background Task

    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.bgTaskIdentifier,
            using: nil
        ) { task in
            self.handleBackgroundTask(task as! BGAppRefreshTask)
        }
    }

    func scheduleBackgroundTask() {
        let request = BGAppRefreshTaskRequest(identifier: Self.bgTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: AppConstants.heartbeatIntervalSeconds)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule background heartbeat: \(error)")
        }
    }

    private func handleBackgroundTask(_ task: BGAppRefreshTask) {
        scheduleBackgroundTask() // re-schedule

        let sendTask = Task {
            await sendHeartbeat()
        }

        task.expirationHandler = {
            sendTask.cancel()
        }

        Task {
            await sendTask.value
            task.setTaskCompleted(success: true)
        }
    }
}
