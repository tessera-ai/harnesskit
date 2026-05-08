import XCTest

@testable import Tessera

final class HealthKitTests: XCTestCase {

    // MARK: - MockHealthDataProvider returns canonical values

    func testMockProviderReturnsHRV() async throws {
        let provider = MockHealthDataProvider()
        let result = try await provider.query([.hrv])
        XCTAssertEqual(result["hrv"] as? Int, 58)
    }

    func testMockProviderReturnsSleep() async throws {
        let provider = MockHealthDataProvider()
        let result = try await provider.query([.sleep])
        XCTAssertEqual(result["sleep"] as? Double, 7.2)
    }

    func testMockProviderReturnsRestingHeartRate() async throws {
        let provider = MockHealthDataProvider()
        let result = try await provider.query([.restingHeartRate])
        XCTAssertEqual(result["restingHeartRate"] as? Int, 54)
    }

    func testMockProviderReturnsActiveEnergy() async throws {
        let provider = MockHealthDataProvider()
        let result = try await provider.query([.activeEnergy])
        XCTAssertEqual(result["activeEnergy"] as? Int, 11200)
        XCTAssertEqual(result["window"] as? String, "7d")
        XCTAssertEqual(result["deltaVsPriorPct"] as? Int, -8)
    }

    func testMockProviderReturnsVO2Max() async throws {
        let provider = MockHealthDataProvider()
        let result = try await provider.query([.vo2Max])
        XCTAssertEqual(result["vo2Max"] as? Double, 47.2)
        XCTAssertEqual(result["zone2BpmRange"] as? [Int], [130, 145])
    }

    func testMockProviderMultipleMetrics() async throws {
        let provider = MockHealthDataProvider()
        let result = try await provider.query([.hrv, .sleep, .restingHeartRate])
        XCTAssertEqual(result["hrv"] as? Int, 58)
        XCTAssertEqual(result["sleep"] as? Double, 7.2)
        XCTAssertEqual(result["restingHeartRate"] as? Int, 54)
    }

    // MARK: - HealthKitReadTool uses provider

    func testToolWithMockProviderReturnsValidJSON() async throws {
        let tool = HealthKit.read(.hrv, .sleep, .restingHeartRate)
        let result = try await tool.invokeJSON("{}")
        XCTAssertTrue(result.contains("\"hrv\":58"))
        XCTAssertTrue(result.contains("\"sleep\":7.2"))
        XCTAssertTrue(result.contains("\"restingHeartRate\":54"))
    }

    func testToolWithExplicitMockProvider() async throws {
        let tool = HealthKit.read(.activeEnergy)
        let result = try await tool.invokeJSON("{}")
        XCTAssertTrue(result.contains("\"activeEnergy\":11200"))
        XCTAssertTrue(result.contains("\"window\":\"7d\""))
    }

    func testToolWithVO2MaxReturnsZone2Range() async throws {
        let tool = HealthKit.read(.vo2Max)
        let result = try await tool.invokeJSON("{}")
        XCTAssertTrue(result.contains("\"vo2Max\":47.2"))
        XCTAssertTrue(result.contains("\"zone2BpmRange\""))
    }

    func testToolReturnsSingleMetric() async throws {
        let tool = HealthKit.read(.hrv)
        let result = try await tool.invokeJSON("{}")
        XCTAssertTrue(result.contains("\"hrv\":58"))
        // Should NOT contain other metrics
        XCTAssertFalse(result.contains("sleep"))
        XCTAssertFalse(result.contains("restingHeartRate"))
    }

    // MARK: - Canonical fixture compatibility

    func testMockProviderMatchesCanonicalFixture() async throws {
        // Verify the mock provider output is consistent with
        // CanonicalRun.healthkitResult1JSON (the recovery snapshot).
        let provider = MockHealthDataProvider()
        let result = try await provider.query([.hrv, .sleep, .restingHeartRate])
        let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
        let _ = String(data: data, encoding: .utf8)!

        // Parse both and compare structurally
        let canonicalData = CanonicalRun.healthkitResult1JSON.data(using: .utf8)!
        let canonicalDict = try JSONSerialization.jsonObject(with: canonicalData) as! [String: Any]
        let providerDict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(providerDict["hrv"] as? NSNumber, canonicalDict["hrv"] as? NSNumber)
        XCTAssertEqual(providerDict["sleep"] as? NSNumber, canonicalDict["sleep"] as? NSNumber)
        XCTAssertEqual(providerDict["restingHeartRate"] as? NSNumber, canonicalDict["restingHeartRate"] as? NSNumber)
    }
}
