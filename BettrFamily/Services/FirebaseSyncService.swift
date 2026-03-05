import Foundation
import FirebaseFirestore
import SwiftData

@MainActor
final class FirebaseSyncService: ObservableObject {
    private let db = Firestore.firestore()

    func syncUsageRecords(from modelContext: ModelContext, familyGroupID: String) async {
        let descriptor = FetchDescriptor<UsageRecord>(
            predicate: #Predicate { !$0.syncedToFirebase }
        )

        guard let records = try? modelContext.fetch(descriptor) else { return }

        for record in records {
            do {
                try await db.collection(AppConstants.FirestoreCollections.families)
                    .document(familyGroupID)
                    .collection(AppConstants.FirestoreCollections.usageRecords)
                    .document(record.id)
                    .setData(record.firestoreData)

                record.syncedToFirebase = true
            } catch {
                print("Failed to sync usage record \(record.id): \(error)")
            }
        }

        try? modelContext.save()
    }

    func syncDomainRecords(from modelContext: ModelContext, familyGroupID: String) async {
        let descriptor = FetchDescriptor<DomainRecord>(
            predicate: #Predicate { !$0.syncedToFirebase }
        )

        guard let records = try? modelContext.fetch(descriptor) else { return }

        for record in records {
            do {
                try await db.collection(AppConstants.FirestoreCollections.families)
                    .document(familyGroupID)
                    .collection(AppConstants.FirestoreCollections.domainRecords)
                    .document(record.id)
                    .setData(record.firestoreData)

                record.syncedToFirebase = true
            } catch {
                print("Failed to sync domain record \(record.id): \(error)")
            }
        }

        try? modelContext.save()
    }

    func syncComplianceEvents(from modelContext: ModelContext, familyGroupID: String) async {
        let descriptor = FetchDescriptor<ComplianceEvent>(
            predicate: #Predicate { !$0.syncedToFirebase }
        )

        guard let records = try? modelContext.fetch(descriptor) else { return }

        for record in records {
            do {
                try await db.collection(AppConstants.FirestoreCollections.families)
                    .document(familyGroupID)
                    .collection(AppConstants.FirestoreCollections.complianceEvents)
                    .document(record.id)
                    .setData(record.firestoreData)

                record.syncedToFirebase = true
            } catch {
                print("Failed to sync compliance event \(record.id): \(error)")
            }
        }

        try? modelContext.save()
    }

    func syncActivityRecords(from modelContext: ModelContext, familyGroupID: String) async {
        let descriptor = FetchDescriptor<ActivityRecord>(
            predicate: #Predicate { !$0.syncedToFirebase }
        )

        guard let records = try? modelContext.fetch(descriptor) else { return }

        for record in records {
            do {
                try await db.collection(AppConstants.FirestoreCollections.families)
                    .document(familyGroupID)
                    .collection(AppConstants.FirestoreCollections.activityRecords)
                    .document(record.id)
                    .setData(record.firestoreData)

                record.syncedToFirebase = true
            } catch {
                print("Failed to sync activity record \(record.id): \(error)")
            }
        }

        try? modelContext.save()
    }

    func syncDailyScores(from modelContext: ModelContext, familyGroupID: String) async {
        let descriptor = FetchDescriptor<DailyScore>(
            predicate: #Predicate { !$0.syncedToFirebase }
        )

        guard let records = try? modelContext.fetch(descriptor) else { return }

        for record in records {
            do {
                try await db.collection(AppConstants.FirestoreCollections.families)
                    .document(familyGroupID)
                    .collection(AppConstants.FirestoreCollections.dailyScores)
                    .document(record.id)
                    .setData(record.firestoreData)

                record.syncedToFirebase = true
            } catch {
                print("Failed to sync daily score \(record.id): \(error)")
            }
        }

        try? modelContext.save()
    }

    func syncStreakRecords(from modelContext: ModelContext, familyGroupID: String) async {
        let descriptor = FetchDescriptor<StreakRecord>(
            predicate: #Predicate { !$0.syncedToFirebase }
        )

        guard let records = try? modelContext.fetch(descriptor) else { return }

        for record in records {
            do {
                try await db.collection(AppConstants.FirestoreCollections.families)
                    .document(familyGroupID)
                    .collection(AppConstants.FirestoreCollections.streakRecords)
                    .document(record.id)
                    .setData(record.firestoreData)

                record.syncedToFirebase = true
            } catch {
                print("Failed to sync streak record \(record.id): \(error)")
            }
        }

        try? modelContext.save()
    }

    func syncLocationSnapshots(from modelContext: ModelContext, familyGroupID: String) async {
        let descriptor = FetchDescriptor<LocationSnapshot>(
            predicate: #Predicate { !$0.syncedToFirebase }
        )

        guard let records = try? modelContext.fetch(descriptor) else { return }

        for record in records {
            do {
                try await db.collection(AppConstants.FirestoreCollections.families)
                    .document(familyGroupID)
                    .collection(AppConstants.FirestoreCollections.locationSnapshots)
                    .document(record.id)
                    .setData(record.firestoreData)

                record.syncedToFirebase = true
            } catch {
                print("Failed to sync location snapshot \(record.id): \(error)")
            }
        }

        try? modelContext.save()
    }

    func syncRaveEvents(from modelContext: ModelContext, familyGroupID: String) async {
        let descriptor = FetchDescriptor<RaveEvent>(
            predicate: #Predicate { !$0.syncedToFirebase }
        )

        guard let records = try? modelContext.fetch(descriptor) else { return }

        for record in records {
            do {
                try await db.collection(AppConstants.FirestoreCollections.families)
                    .document(familyGroupID)
                    .collection(AppConstants.FirestoreCollections.raveEvents)
                    .document(record.id)
                    .setData(record.firestoreData)

                record.syncedToFirebase = true
            } catch {
                print("Failed to sync rave event \(record.id): \(error)")
            }
        }

        try? modelContext.save()
    }

    func fetchFamilyDailyScores(familyGroupID: String, date: Date) async -> [[String: Any]] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        do {
            let snapshot = try await db.collection(AppConstants.FirestoreCollections.families)
                .document(familyGroupID)
                .collection(AppConstants.FirestoreCollections.dailyScores)
                .whereField("date", isGreaterThanOrEqualTo: startOfDay.timeIntervalSince1970)
                .whereField("date", isLessThan: endOfDay.timeIntervalSince1970)
                .getDocuments()

            return snapshot.documents.map { $0.data() }
        } catch {
            print("Failed to fetch family daily scores: \(error)")
            return []
        }
    }

    func fetchFamilyRaveEvents(familyGroupID: String, limit: Int = 50) async -> [[String: Any]] {
        do {
            let snapshot = try await db.collection(AppConstants.FirestoreCollections.families)
                .document(familyGroupID)
                .collection(AppConstants.FirestoreCollections.raveEvents)
                .order(by: "timestamp", descending: true)
                .limit(to: limit)
                .getDocuments()

            return snapshot.documents.map { $0.data() }
        } catch {
            print("Failed to fetch rave events: \(error)")
            return []
        }
    }

    func fetchFamilyUsageRecords(familyGroupID: String, date: Date) async -> [[String: Any]] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        do {
            let snapshot = try await db.collection(AppConstants.FirestoreCollections.families)
                .document(familyGroupID)
                .collection(AppConstants.FirestoreCollections.usageRecords)
                .whereField("date", isGreaterThanOrEqualTo: startOfDay.timeIntervalSince1970)
                .whereField("date", isLessThan: endOfDay.timeIntervalSince1970)
                .getDocuments()

            return snapshot.documents.map { $0.data() }
        } catch {
            print("Failed to fetch family usage records: \(error)")
            return []
        }
    }

    func fetchFamilyComplianceEvents(familyGroupID: String, limit: Int = 50) async -> [[String: Any]] {
        do {
            let snapshot = try await db.collection(AppConstants.FirestoreCollections.families)
                .document(familyGroupID)
                .collection(AppConstants.FirestoreCollections.complianceEvents)
                .order(by: "timestamp", descending: true)
                .limit(to: limit)
                .getDocuments()

            return snapshot.documents.map { $0.data() }
        } catch {
            print("Failed to fetch compliance events: \(error)")
            return []
        }
    }

    func fetchFamilyMembers(familyGroupID: String) async -> [[String: Any]] {
        do {
            let snapshot = try await db.collection(AppConstants.FirestoreCollections.members)
                .whereField("familyGroupID", isEqualTo: familyGroupID)
                .getDocuments()

            return snapshot.documents.map {
                var data = $0.data()
                data["uid"] = $0.documentID
                return data
            }
        } catch {
            print("Failed to fetch family members: \(error)")
            return []
        }
    }
}
