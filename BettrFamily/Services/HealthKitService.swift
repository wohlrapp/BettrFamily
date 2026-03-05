import Foundation
import HealthKit
import SwiftData

@MainActor
final class HealthKitService: ObservableObject {
    @Published var isAuthorized = false
    @Published var errorMessage: String?

    private let healthStore = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    init() {
        // Restore authorization state from UserDefaults (HealthKit doesn't provide a direct check for read-only auth)
        if UserDefaults.shared.bool(forKey: AppConstants.UserDefaultsKeys.healthKitAuthorized) {
            isAuthorized = true
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        guard isAvailable else {
            errorMessage = "HealthKit ist auf diesem Geraet nicht verfuegbar."
            return
        }

        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.flightsClimbed),
            HKQuantityType(.timeInDaylight),
            HKQuantityType(.numberOfAlcoholicBeverages),
            HKCategoryType(.mindfulSession),
            HKCategoryType(.sleepAnalysis),
            HKCategoryType(.appleStandHour),
            HKCategoryType(.toothbrushingEvent),
            HKObjectType.workoutType()
        ]

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            UserDefaults.shared.set(true, forKey: AppConstants.UserDefaultsKeys.healthKitAuthorized)
        } catch {
            errorMessage = "HealthKit-Berechtigung fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    // MARK: - Query Daily Activities

    func queryDailyActivities(
        for date: Date,
        memberID: String,
        config: FamilyActivityConfig,
        modelContext: ModelContext
    ) async -> [ActivityRecord] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        var records: [ActivityRecord] = []

        // Quantity types
        let quantityQueries: [(String, HKQuantityTypeIdentifier, HKUnit, String)] = [
            ("steps", .stepCount, .count(), "steps"),
            ("distanceWalking", .distanceWalkingRunning, .meterUnit(with: .kilo), "km"),
            ("distanceCycling", .distanceCycling, .meterUnit(with: .kilo), "km"),
            ("activeEnergy", .activeEnergyBurned, .kilocalorie(), "kcal"),
            ("exerciseTime", .appleExerciseTime, .minute(), "minutes"),
            ("flightsClimbed", .flightsClimbed, .count(), "flights"),
            ("timeInDaylight", .timeInDaylight, .minute(), "minutes"),
            ("alcohol", .numberOfAlcoholicBeverages, .count(), "count"),
        ]

        for (activityType, identifier, unit, unitStr) in quantityQueries {
            guard let pointConfig = config.activities.first(where: { $0.activityType == activityType && $0.isEnabled }) else { continue }
            if let value = await queryQuantity(type: HKQuantityType(identifier), unit: unit, predicate: predicate) {
                let units = value / pointConfig.unitThreshold
                let points = floor(units) * pointConfig.pointsPerUnit
                if abs(points) > 0 {
                    let category = ActivityCategory(rawValue: pointConfig.category) ?? .neutral
                    records.append(ActivityRecord(
                        memberID: memberID, date: date,
                        activityType: activityType, category: category,
                        rawValue: value, unit: unitStr,
                        points: points, source: "healthkit"
                    ))
                }
            }
        }

        // Workouts
        if let pointConfig = config.activities.first(where: { $0.activityType == "workouts" && $0.isEnabled }) {
            let workoutCount = await queryWorkoutCount(predicate: predicate)
            if workoutCount > 0 {
                let points = Double(workoutCount) * pointConfig.pointsPerUnit
                records.append(ActivityRecord(
                    memberID: memberID, date: date,
                    activityType: "workouts", category: .positive,
                    rawValue: Double(workoutCount), unit: "count",
                    points: points, source: "healthkit"
                ))
            }
        }

        // Mindful sessions
        if let pointConfig = config.activities.first(where: { $0.activityType == "mindfulSession" && $0.isEnabled }) {
            let count = await queryCategoryCount(type: HKCategoryType(.mindfulSession), predicate: predicate)
            if count > 0 {
                let points = Double(count) * pointConfig.pointsPerUnit
                records.append(ActivityRecord(
                    memberID: memberID, date: date,
                    activityType: "mindfulSession", category: .positive,
                    rawValue: Double(count), unit: "count",
                    points: points, source: "healthkit"
                ))
            }
        }

        // Stand hours
        if let pointConfig = config.activities.first(where: { $0.activityType == "standHours" && $0.isEnabled }) {
            let count = await queryCategoryCount(type: HKCategoryType(.appleStandHour), predicate: predicate)
            if count > 0 {
                let points = Double(count) * pointConfig.pointsPerUnit
                records.append(ActivityRecord(
                    memberID: memberID, date: date,
                    activityType: "standHours", category: .positive,
                    rawValue: Double(count), unit: "hours",
                    points: points, source: "healthkit"
                ))
            }
        }

        // Toothbrushing
        if let pointConfig = config.activities.first(where: { $0.activityType == "toothbrushing" && $0.isEnabled }) {
            let count = await queryCategoryCount(type: HKCategoryType(.toothbrushingEvent), predicate: predicate)
            if count > 0 {
                let points = Double(count) * pointConfig.pointsPerUnit
                records.append(ActivityRecord(
                    memberID: memberID, date: date,
                    activityType: "toothbrushing", category: .positive,
                    rawValue: Double(count), unit: "count",
                    points: points, source: "healthkit"
                ))
            }
        }

        // Sleep analysis
        await querySleep(date: date, memberID: memberID, config: config, records: &records, predicate: predicate)

        return records
    }

    // MARK: - Private Helpers

    private func queryQuantity(type: HKQuantityType, unit: HKUnit, predicate: NSPredicate) async -> Double? {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                let value = stats?.sumQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private func queryWorkoutCount(predicate: NSPredicate) async -> Int {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                continuation.resume(returning: samples?.count ?? 0)
            }
            healthStore.execute(query)
        }
    }

    private func queryCategoryCount(type: HKCategoryType, predicate: NSPredicate) async -> Int {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                continuation.resume(returning: samples?.count ?? 0)
            }
            healthStore.execute(query)
        }
    }

    private func querySleep(date: Date, memberID: String, config: FamilyActivityConfig, records: inout [ActivityRecord], predicate: NSPredicate) async {
        let sleepType = HKCategoryType(.sleepAnalysis)
        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            healthStore.execute(query)
        }

        // Calculate total sleep hours (inBed or asleep)
        let sleepSeconds = samples
            .filter { $0.value != HKCategoryValueSleepAnalysis.awake.rawValue }
            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        let sleepHours = sleepSeconds / 3600

        if sleepHours >= 7 && sleepHours <= 9,
           let cfg = config.activities.first(where: { $0.activityType == "goodSleep" && $0.isEnabled }) {
            records.append(ActivityRecord(
                memberID: memberID, date: date,
                activityType: "goodSleep", category: .positive,
                rawValue: sleepHours, unit: "hours",
                points: cfg.pointsPerUnit, source: "healthkit"
            ))
        } else if sleepHours > 0 && sleepHours < 6,
                  let cfg = config.activities.first(where: { $0.activityType == "shortSleep" && $0.isEnabled }) {
            records.append(ActivityRecord(
                memberID: memberID, date: date,
                activityType: "shortSleep", category: .bad,
                rawValue: sleepHours, unit: "hours",
                points: cfg.pointsPerUnit, source: "healthkit"
            ))
        }
    }
}
