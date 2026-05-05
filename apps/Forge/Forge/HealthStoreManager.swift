import HealthKit

@MainActor
final class HealthStoreManager {
    static let shared = HealthStoreManager()

    private let store = HKHealthStore()

    private init() {}

    // MARK: - Authorization status

    /// Returns `true` when the user has granted at-share authorization for the
    /// workout type (a reasonable proxy that the full permission grant succeeded).
    var isAuthorized: Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let workout = HKSampleType.workoutType()
        return store.authorizationStatus(for: workout) == .sharingAuthorized
    }

    // MARK: - Types Coach reads

    /// The 5 metrics Forge's Coach agent queries from HealthKit.
    private var readTypes: Set<HKSampleType> {
        Set([
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.vo2Max),
            HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!,
        ])
    }

    /// The write types Forge needs — workouts scheduled by WorkoutKit.
    private var shareTypes: Set<HKSampleType> {
        Set([HKSampleType.workoutType()])
    }

    // MARK: - Request

    /// Requests HealthKit authorization for all metrics Coach uses.
    /// - Returns: `true` if authorization was granted, `false` if denied.
    func requestAuthorization() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            return false
        }
        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
        return isAuthorized
    }
}
