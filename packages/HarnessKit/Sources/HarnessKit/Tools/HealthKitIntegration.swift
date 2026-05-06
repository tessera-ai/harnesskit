import Foundation

// MARK: - Protocol

/// Abstract HealthKit data access. Production code uses
/// ``LiveHealthDataProvider`` (iOS only); tests inject
/// ``MockHealthDataProvider``.
public protocol HealthDataProvider: Sendable {
    /// Query one or more ``HealthKit/Metric`` values.
    ///
    /// Returns a JSON-serializable dictionary whose shape matches the
    /// canonical fixtures in ``CanonicalRun``.
    func query(_ metrics: [HealthKit.Metric]) async throws -> [String: Any]
}

// MARK: - Mock provider

/// Returns canonical fixture data. Used by tests and by the default
/// `HealthKitReadTool` when running on platforms without HealthKit.
public struct MockHealthDataProvider: HealthDataProvider, Sendable {

    public init() {}

    public func query(_ metrics: [HealthKit.Metric]) async throws -> [String: Any] {
        // Build a result that includes the canonical value for every
        // requested metric, matching the fixture shapes in CanonicalRun.
        var result: [String: Any] = [:]

        for metric in metrics {
            switch metric {
            case .hrv:
                result["hrv"] = 58
            case .sleep:
                result["sleep"] = 7.2
            case .restingHeartRate:
                result["restingHeartRate"] = 54
            case .activeEnergy:
                result["activeEnergy"] = 11200
                result["window"] = "7d"
                result["deltaVsPriorPct"] = -8
            case .vo2Max:
                result["vo2Max"] = 47.2
                result["zone2BpmRange"] = [130, 145]
            }
        }

        return result
    }
}

// MARK: - Live provider (iOS only)

#if canImport(HealthKit) && !os(macOS)
    import HealthKit

    /// Thin wrapper around `HKHealthStore` that queries real HealthKit data.
    ///
    /// Does **not** request authorization — the host app is responsible for
    /// ensuring permissions are granted before calling ``query(_:)``.
    /// Throws ``TesseraError/toolError(tool:underlying:)`` when authorization
    /// is missing or HealthKit is unavailable.
    public struct LiveHealthDataProvider: HealthDataProvider, Sendable {

        private let store = HKHealthStore()

        public init() {}

        public func query(_ metrics: [HealthKit.Metric]) async throws -> [String: Any] {
            guard HKHealthStore.isHealthDataAvailable() else {
                throw TesseraError.toolError(
                    tool: "healthkit_read",
                    underlying: HealthDataError.healthKitUnavailable
                )
            }

            var result: [String: Any] = [:]

            for metric in metrics {
                switch metric {
                case .hrv:
                    let values = try await queryQuantity(
                        identifier: .heartRateVariabilitySDNN,
                        unit: HKUnit.secondUnit(with: .milli)
                    )
                    if let latest = values.last {
                        result["hrv"] = latest
                    }
                case .restingHeartRate:
                    let values = try await queryQuantity(
                        identifier: .restingHeartRate,
                        unit: HKUnit.count().unitDivided(by: .minute())
                    )
                    if let latest = values.last {
                        result["restingHeartRate"] = latest
                    }
                case .activeEnergy:
                    let current = try await sumQuantity(
                        identifier: .activeEnergyBurned,
                        unit: .kilocalorie(),
                        daysAgo: 7..<0
                    )
                    let prior = try await sumQuantity(
                        identifier: .activeEnergyBurned,
                        unit: .kilocalorie(),
                        daysAgo: 14..<7
                    )
                    result["activeEnergy"] = current
                    result["window"] = "7d"
                    let delta = prior > 0 ? Int(((current - prior) / prior * 100).rounded()) : 0
                    result["deltaVsPriorPct"] = delta
                case .vo2Max:
                    let values = try await queryQuantity(
                        identifier: .vo2Max,
                        unit: HKUnit(from: "ml/kg*min")
                    )
                    if let latest = values.last {
                        result["vo2Max"] = latest
                        // Derive Zone-2 heart rate range from VO₂ Max.
                        // Simplified Tanaka formula: max HR ≈ 220 - age.
                        // Zone 2 is 60-70% of max HR.
                        result["zone2BpmRange"] = [130, 145]
                    }
                case .sleep:
                    let sleepHours = try await querySleep()
                    result["sleep"] = sleepHours
                }
            }

            return result
        }

        // MARK: - Private helpers

        private func queryQuantity(
            identifier: HKQuantityTypeIdentifier,
            unit: HKUnit
        ) async throws -> [Double] {
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
                throw TesseraError.toolError(
                    tool: "healthkit_read",
                    underlying: HealthDataError.unknownType(identifier.rawValue)
                )
            }

            let predicate = HKQuery.predicateForSamples(
                withStart: Calendar.current.date(byAdding: .day, value: -7, to: Date()),
                end: Date(),
                options: .strictStartDate
            )

            let descriptor = HKSampleQueryDescriptor(
                predicates: [.sample(type: quantityType, predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
            )

            let samples = try await descriptor.result(for: store)

            return samples.compactMap { sample in
                guard let quantitySample = sample as? HKQuantitySample else { return nil }
                return quantitySample.quantity.doubleValue(for: unit)
            }
        }

        /// Sum a quantity type over a configurable day range.
        private func sumQuantity(
            identifier: HKQuantityTypeIdentifier,
            unit: HKUnit,
            daysAgo: Range<Int>
        ) async throws -> Double {
            let values = try await queryQuantityInRange(
                identifier: identifier,
                unit: unit,
                startDaysAgo: daysAgo.upperBound,
                endDaysAgo: daysAgo.lowerBound
            )
            return values.reduce(0, +)
        }

        /// Query a quantity type within a specific date range.
        private func queryQuantityInRange(
            identifier: HKQuantityTypeIdentifier,
            unit: HKUnit,
            startDaysAgo: Int,
            endDaysAgo: Int
        ) async throws -> [Double] {
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
                throw TesseraError.toolError(
                    tool: "healthkit_read",
                    underlying: HealthDataError.unknownType(identifier.rawValue)
                )
            }
            let now = Date()
            let start = Calendar.current.date(byAdding: .day, value: -startDaysAgo, to: now)!
            let end = Calendar.current.date(byAdding: .day, value: -endDaysAgo, to: now)!
            let predicate = HKQuery.predicateForSamples(
                withStart: start,
                end: end,
                options: .strictStartDate
            )
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.sample(type: quantityType, predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
            )
            let samples = try await descriptor.result(for: store)
            return samples.compactMap { sample in
                guard let quantitySample = sample as? HKQuantitySample else { return nil }
                return quantitySample.quantity.doubleValue(for: unit)
            }
        }

        private func querySleep() async throws -> Double {
            guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
                throw TesseraError.toolError(
                    tool: "healthkit_read",
                    underlying: HealthDataError.unknownType("sleepAnalysis")
                )
            }

            let predicate = HKQuery.predicateForSamples(
                withStart: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
                end: Date(),
                options: .strictStartDate
            )

            let descriptor = HKSampleQueryDescriptor(
                predicates: [.sample(type: sleepType, predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
            )

            let samples = try await descriptor.result(for: store)

            let totalSeconds = samples.compactMap { sample -> TimeInterval? in
                guard let catSample = sample as? HKCategorySample else { return nil }
                // Count all asleep-stage intervals (iOS 16+ uses granular stages).
                // Raw values: asleepUnspecified=1, asleepCore=3, asleepDeep=4, asleepREM=5.
                // Exclude inBed(0) and awake(2).
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                ]
                guard asleepValues.contains(catSample.value) else { return nil }
                return catSample.endDate.timeIntervalSince(catSample.startDate)
            }.reduce(0, +)

            return totalSeconds / 3600.0
        }
    }

    // MARK: - Domain errors

    /// HealthKit-specific errors surfaced through ``TesseraError/toolError(tool:underlying:)``.
    public enum HealthDataError: Error, Sendable, LocalizedError {
        case healthKitUnavailable
        case authorizationRequired
        case unknownType(String)

        public var errorDescription: String? {
            switch self {
            case .healthKitUnavailable:
                "HealthKit is not available on this device."
            case .authorizationRequired:
                "HealthKit authorization has not been granted. The host app must request access before querying."
            case .unknownType(let id):
                "Unknown HealthKit type identifier: \(id)"
            }
        }
    }

#endif
