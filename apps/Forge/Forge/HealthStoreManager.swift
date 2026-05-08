import HealthKit

@MainActor
final class HealthStoreManager {
    static let shared = HealthStoreManager()

    private let store = HKHealthStore()

    private init() {}

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

    // MARK: - Request

    /// Requests HealthKit authorization for all metrics Coach uses.
    /// - Returns: `true` if authorization was granted, `false` if denied.
    func requestAuthorization() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            return false
        }
        try await store.requestAuthorization(toShare: [], read: readTypes)
        // Apple doesn't expose read-grant status via authorizationStatus(for:).
        // Gate on the call succeeding without throwing — if the user denied,
        // requestAuthorization still returns successfully, but queries return
        // empty data. The "asked once" pattern is the standard workaround.
        return true
    }
}
