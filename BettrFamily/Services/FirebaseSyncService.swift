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

    func syncBadges(from modelContext: ModelContext, familyGroupID: String) async {
        let descriptor = FetchDescriptor<Badge>(
            predicate: #Predicate { !$0.syncedToFirebase }
        )

        guard let records = try? modelContext.fetch(descriptor) else { return }

        for record in records {
            do {
                try await db.collection(AppConstants.FirestoreCollections.families)
                    .document(familyGroupID)
                    .collection(AppConstants.FirestoreCollections.badges)
                    .document(record.id)
                    .setData(record.firestoreData)

                record.syncedToFirebase = true
            } catch {
                print("Failed to sync badge \(record.id): \(error)")
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

    // MARK: - Fetch Remote Data (from other family members)

    func fetchAndStoreRemoteRaves(familyGroupID: String, modelContext: ModelContext) async {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let startTimestamp = Calendar.current.startOfDay(for: sevenDaysAgo).timeIntervalSince1970

        do {
            let snapshot = try await db.collection(AppConstants.FirestoreCollections.families)
                .document(familyGroupID)
                .collection(AppConstants.FirestoreCollections.raveEvents)
                .whereField("timestamp", isGreaterThan: startTimestamp)
                .getDocuments()

            for doc in snapshot.documents {
                let data = doc.data()
                let raveID = data["id"] as? String ?? doc.documentID

                // Check if already exists locally
                let descriptor = FetchDescriptor<RaveEvent>(
                    predicate: #Predicate { $0.id == raveID }
                )
                if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty { continue }

                let rave = RaveEvent(
                    fromMemberID: data["fromMemberID"] as? String ?? "",
                    fromMemberName: data["fromMemberName"] as? String ?? "",
                    toMemberID: data["toMemberID"] as? String ?? "",
                    toMemberName: data["toMemberName"] as? String ?? "",
                    reason: data["reason"] as? String ?? "",
                    points: data["points"] as? Double ?? 5,
                    emoji: data["emoji"] as? String ?? "🌟"
                )
                rave.id = raveID
                if let ts = data["timestamp"] as? Double {
                    rave.timestamp = Date(timeIntervalSince1970: ts)
                }
                if let d = data["date"] as? Double {
                    rave.date = Date(timeIntervalSince1970: d)
                }
                rave.syncedToFirebase = true
                modelContext.insert(rave)
            }
            try? modelContext.save()
        } catch {
            print("Failed to fetch remote RAVEs: \(error)")
        }
    }

    func fetchAndStoreRemoteBadges(familyGroupID: String, memberID: String, modelContext: ModelContext) async {
        do {
            let snapshot = try await db.collection(AppConstants.FirestoreCollections.families)
                .document(familyGroupID)
                .collection(AppConstants.FirestoreCollections.badges)
                .whereField("memberID", isEqualTo: memberID)
                .getDocuments()

            for doc in snapshot.documents {
                let data = doc.data()
                let badgeID = data["id"] as? String ?? doc.documentID
                let badgeType = data["badgeType"] as? String ?? ""

                let descriptor = FetchDescriptor<Badge>(
                    predicate: #Predicate { $0.id == badgeID }
                )
                if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty { continue }

                let badge = Badge(memberID: memberID, badgeType: badgeType)
                badge.id = badgeID
                if let d = data["earnedDate"] as? Double {
                    badge.earnedDate = Date(timeIntervalSince1970: d)
                }
                badge.syncedToFirebase = true
                modelContext.insert(badge)
            }
            try? modelContext.save()
        } catch {
            print("Failed to fetch remote badges: \(error)")
        }
    }

    func fetchAndStoreRemoteDailyScores(familyGroupID: String, modelContext: ModelContext) async {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let startTimestamp = Calendar.current.startOfDay(for: sevenDaysAgo).timeIntervalSince1970

        do {
            let snapshot = try await db.collection(AppConstants.FirestoreCollections.families)
                .document(familyGroupID)
                .collection(AppConstants.FirestoreCollections.dailyScores)
                .whereField("date", isGreaterThanOrEqualTo: startTimestamp)
                .getDocuments()

            for doc in snapshot.documents {
                let data = doc.data()
                let scoreID = data["id"] as? String ?? doc.documentID
                let scoreMemberID = data["memberID"] as? String ?? ""

                let descriptor = FetchDescriptor<DailyScore>(
                    predicate: #Predicate { $0.id == scoreID }
                )
                if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty { continue }

                let score = DailyScore(
                    memberID: scoreMemberID,
                    memberName: data["memberName"] as? String ?? "",
                    date: Date(timeIntervalSince1970: data["date"] as? Double ?? 0),
                    positivePoints: data["positivePoints"] as? Double ?? 0,
                    negativePoints: data["negativePoints"] as? Double ?? 0,
                    bonusPoints: data["bonusPoints"] as? Double ?? 0,
                    streakMultiplier: data["streakMultiplier"] as? Double ?? 1.0,
                    streakDay: data["streakDay"] as? Int ?? 0
                )
                score.id = scoreID
                score.syncedToFirebase = true
                modelContext.insert(score)
            }
            try? modelContext.save()
        } catch {
            print("Failed to fetch remote daily scores: \(error)")
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
