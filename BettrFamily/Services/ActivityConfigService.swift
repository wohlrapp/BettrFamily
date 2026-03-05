import Foundation
import FirebaseFirestore

@MainActor
final class ActivityConfigService: ObservableObject {
    @Published var config: FamilyActivityConfig = .default
    @Published var isLoaded = false

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func loadConfig(familyGroupID: String) {
        listener?.remove()
        listener = db.collection(AppConstants.FirestoreCollections.families)
            .document(familyGroupID)
            .collection(AppConstants.FirestoreCollections.activityConfig)
            .document("current")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let data = snapshot?.data(),
                   let jsonData = try? JSONSerialization.data(withJSONObject: data),
                   let decoded = try? JSONDecoder().decode(FamilyActivityConfig.self, from: jsonData) {
                    self.config = decoded
                } else {
                    self.config = .default
                }
                self.isLoaded = true
            }
    }

    func saveConfig(familyGroupID: String) async {
        guard let jsonData = try? JSONEncoder().encode(config),
              let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return
        }

        do {
            try await db.collection(AppConstants.FirestoreCollections.families)
                .document(familyGroupID)
                .collection(AppConstants.FirestoreCollections.activityConfig)
                .document("current")
                .setData(dict)
        } catch {
            print("Failed to save activity config: \(error)")
        }
    }

    func pointConfig(for activityType: String) -> ActivityPointConfig? {
        config.activities.first { $0.activityType == activityType }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
