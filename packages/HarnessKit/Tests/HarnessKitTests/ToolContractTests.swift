import XCTest

@testable import Tessera

final class ToolContractTests: XCTestCase {

    // MARK: - Tool name stability and uniqueness

    func testToolNamesAreUniqueAndStable() {
        let hk = HealthKit.read(.hrv)
        let wk = WorkoutKit.schedule
        XCTAssertEqual(hk.name, "healthkit_read")
        XCTAssertEqual(wk.name, "workoutkit_schedule")
        XCTAssertNotEqual(hk.name, wk.name, "Tool names must be unique")
    }

    func testToolDescriptionsAreNonEmpty() {
        let hk = HealthKit.read(.hrv)
        let wk = WorkoutKit.schedule
        XCTAssertFalse(hk.toolDescription.isEmpty, "HealthKit tool description must not be empty")
        XCTAssertFalse(wk.toolDescription.isEmpty, "WorkoutKit tool description must not be empty")
    }

    // MARK: - invokeJSON returns valid, parsable JSON

    func testHealthKitInvokeReturnsParsableJSON() async throws {
        let tool = HealthKit.read(.hrv, .sleep, .restingHeartRate)
        let result = try await tool.invokeJSON("{}")
        XCTAssertFalse(result.isEmpty, "Result must not be empty")
        let data = Data(result.utf8)
        let parsed = try JSONSerialization.jsonObject(with: data)
        XCTAssertTrue(parsed is [String: Any], "Result must be a JSON object")
    }

    func testWorkoutKitInvokeReturnsParsableJSON() async throws {
        let tool = WorkoutKit.schedule
        let result = try await tool.invokeJSON(CanonicalRun.workoutkitArgsJSON)
        XCTAssertFalse(result.isEmpty, "Result must not be empty")
        let data = Data(result.utf8)
        let parsed = try JSONSerialization.jsonObject(with: data)
        XCTAssertTrue(parsed is [String: Any], "Result must be a JSON object")
    }

    // MARK: - invokeJSON with empty args

    func testHealthKitInvokeWithEmptyArgsReturnsValidJSON() async throws {
        let tool = HealthKit.read(.hrv)
        let result = try await tool.invokeJSON("{}")
        // HealthKit ignores args — uses metrics from construction
        let parsed = try JSONSerialization.jsonObject(with: Data(result.utf8)) as! [String: Any]
        XCTAssertNotNil(parsed["hrv"], "Should return HRV even with empty args")
    }

    // MARK: - invokeJSON with malformed JSON

    func testHealthKitInvokeWithMalformedArgsDoesNotCrash() async throws {
        let tool = HealthKit.read(.hrv)
        // HealthKit ignores args entirely, so malformed JSON should still succeed
        let result = try await tool.invokeJSON("not json at all")
        XCTAssertFalse(result.isEmpty, "HealthKit should return data even with bad args since it ignores them")
    }

    func testWorkoutKitInvokeWithMalformedArgsThrows() async {
        let tool = WorkoutKit.schedule
        do {
            _ = try await tool.invokeJSON("not json")
            XCTFail("WorkoutKit should throw on malformed JSON since it parses args")
        } catch {
            // Expected — JSON decoding failure
        }
    }

    func testWorkoutKitInvokeWithEmptyObjectThrowsOnMissingFields() async {
        let tool = WorkoutKit.schedule
        do {
            _ = try await tool.invokeJSON("{}")
            XCTFail("WorkoutKit should throw when required fields are missing")
        } catch {
            // Expected — missing exercises, time, durationMin
        }
    }
}
