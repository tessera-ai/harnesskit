import Foundation

/// Tessera-branded HealthKit namespace. Intentionally does NOT import the
/// real Apple HealthKit framework — entitlement risk on a fresh demo build.
/// Returns canonical mocked data from `CanonicalRun` matching the SPEC.
public enum HealthKit {
    /// Recovery-relevant health metrics that can be queried from HealthKit.
    public enum Metric: String, Sendable, CaseIterable, Codable {
        /// Heart rate variability (SDNN, milliseconds).
        case hrv
        /// Total sleep duration (hours).
        case sleep
        /// Resting heart rate (bpm).
        case restingHeartRate
        /// Active energy burned (kcal, 7-day window).
        case activeEnergy
        /// VO₂ Max estimate (ml/kg·min).
        case vo2Max
    }

    /// Variadic factory matching the hero-shot signature:
    /// `HealthKit.read(.hrv, .sleep, .restingHeartRate)`.
    /// Uses ``MockHealthDataProvider`` by default.
    public static func read(_ metrics: Metric...) -> any Tool {
        HealthKitReadTool(metrics: metrics, provider: MockHealthDataProvider())
    }

    /// Factory with explicit provider for dependency injection.
    public static func read(
        _ metrics: [Metric],
        provider: any HealthDataProvider
    ) -> any Tool {
        HealthKitReadTool(metrics: metrics, provider: provider)
    }
}

struct HealthKitReadTool: Tool {
    let metrics: [HealthKit.Metric]
    private let provider: any HealthDataProvider

    init(metrics: [HealthKit.Metric], provider: any HealthDataProvider) {
        self.metrics = metrics
        self.provider = provider
    }

    var name: String { "healthkit_read" }
    var toolDescription: String {
        "Read recovery-relevant HealthKit metrics (HRV, sleep, resting HR, etc.)"
    }

    func invokeJSON(_ argsJSON: String) async throws -> String {
        let result = try await provider.query(metrics)
        let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw TesseraError.toolError(
                tool: name,
                underlying: NSError(
                    domain: "HarnessKit",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to serialize HealthKit result to UTF-8"]
                )
            )
        }
        return jsonString
    }
}
