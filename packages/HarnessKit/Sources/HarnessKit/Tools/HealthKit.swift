import Foundation

/// Tessera-branded HealthKit namespace. Intentionally does NOT import the
/// real Apple HealthKit framework — entitlement risk on a fresh demo build.
/// Returns canonical mocked data from `CanonicalRun` matching the SPEC.
public enum HealthKit {
    public enum Metric: String, Sendable, CaseIterable, Codable {
        case hrv
        case sleep
        case restingHeartRate
        case activeEnergy
        case vo2Max
    }

    /// Variadic factory matching the hero-shot signature:
    /// `HealthKit.read(.hrv, .sleep, .restingHeartRate)`.
    public static func read(_ metrics: Metric...) -> any Tool {
        HealthKitReadTool(metrics: metrics)
    }
}

struct HealthKitReadTool: Tool {
    let metrics: [HealthKit.Metric]

    var name: String { "healthkit_read" }
    var toolDescription: String {
        "Read recovery-relevant HealthKit metrics (HRV, sleep, resting HR, etc.)"
    }

    func invokeJSON(_ argsJSON: String) async throws -> String {
        // Mocked — returns the canonical HealthKit snapshot regardless of args.
        // The real iOS app would gate on HKHealthStore authorization.
        return CanonicalRun.healthkitResultJSON
    }
}
