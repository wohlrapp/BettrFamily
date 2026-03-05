import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
final class AuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var memberID: String?
    @Published var memberName: String?
    @Published var familyGroupID: String?
    @Published var isAuthenticated = false
    @Published var errorMessage: String?

    private var authStateListener: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()

    init() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                if let user {
                    self?.memberID = user.uid
                    UserDefaults.shared.set(user.uid, forKey: AppConstants.UserDefaultsKeys.memberID)
                    await self?.loadMemberProfile(uid: user.uid)
                }
            }
        }
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    func signUp(email: String, password: String, name: String, familyCode: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let uid = result.user.uid

        // Create or join family group
        let familyID = familyCode.isEmpty ? UUID().uuidString : familyCode
        let memberData: [String: Any] = [
            "name": name,
            "email": email,
            "familyGroupID": familyID,
            "deviceName": UIDevice.current.name,
            "createdAt": FieldValue.serverTimestamp()
        ]

        try await db.collection(AppConstants.FirestoreCollections.members)
            .document(uid)
            .setData(memberData)

        // If new family, create family document
        if familyCode.isEmpty {
            try await db.collection(AppConstants.FirestoreCollections.families)
                .document(familyID)
                .setData([
                    "createdAt": FieldValue.serverTimestamp(),
                    "createdBy": uid,
                    "familyCode": familyID
                ])
        }

        // Add member to family
        try await db.collection(AppConstants.FirestoreCollections.families)
            .document(familyID)
            .collection("members")
            .document(uid)
            .setData(["name": name, "joinedAt": FieldValue.serverTimestamp()])

        self.memberName = name
        self.familyGroupID = familyID
        UserDefaults.shared.set(name, forKey: AppConstants.UserDefaultsKeys.memberName)
        UserDefaults.shared.set(familyID, forKey: AppConstants.UserDefaultsKeys.familyGroupID)
    }

    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signOut() throws {
        try Auth.auth().signOut()
        memberID = nil
        memberName = nil
        familyGroupID = nil
        isAuthenticated = false
    }

    private func loadMemberProfile(uid: String) async {
        do {
            let doc = try await db.collection(AppConstants.FirestoreCollections.members)
                .document(uid)
                .getDocument()

            if let data = doc.data() {
                self.memberName = data["name"] as? String
                self.familyGroupID = data["familyGroupID"] as? String
                UserDefaults.shared.set(self.memberName, forKey: AppConstants.UserDefaultsKeys.memberName)
                UserDefaults.shared.set(self.familyGroupID, forKey: AppConstants.UserDefaultsKeys.familyGroupID)
            }
        } catch {
            print("Failed to load member profile: \(error)")
        }
    }
}
