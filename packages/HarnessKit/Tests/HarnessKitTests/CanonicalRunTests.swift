import XCTest
@testable import Tessera

final class CanonicalRunTests: XCTestCase {

    // MARK: - Event count

    func testEventCountIs14() {
        let events = CanonicalRun.makeEvents()
        XCTAssertEqual(events.count, 14, "SPEC §3 defines exactly 14 trace events")
    }

    // MARK: - Event ordering (atMs non-decreasing)

    func testEventOrderingIsNonDecreasing() {
        let events = CanonicalRun.makeEvents()
        var previous = -1
        for (i, event) in events.enumerated() {
            let atMs = extractAtMs(from: event)
            XCTAssertGreaterThanOrEqual(atMs, previous, "atMs must be non-decreasing at event[\(i)]")
            previous = atMs
        }
    }

    // MARK: - Tool call/result pairing

    func testToolCallsHaveMatchingResults() {
        let events = CanonicalRun.makeEvents()
        var toolCallNames: [String] = []
        var toolResultNames: [String] = []

        for event in events {
            switch event {
            case .toolCall(_, let tool, _):
                toolCallNames.append(tool)
            case .toolResult(_, _, let tool, _):
                toolResultNames.append(tool)
            default:
                break
            }
        }

        XCTAssertEqual(toolCallNames.count, toolResultNames.count,
            "Every tool call must have a matching tool result")
        for (i, callName) in toolCallNames.enumerated() {
            XCTAssertEqual(callName, toolResultNames[i],
                "Tool call[\(i)] (\(callName)) must match result[\(i)] (\(toolResultNames[i]))")
        }
    }

    // MARK: - Final event is .finalResponse

    func testFinalEventIsFinalResponse() {
        let events = CanonicalRun.makeEvents()
        guard let last = events.last else {
            XCTFail("Events should not be empty")
            return
        }
        if case .finalResponse = last {
            // Correct
        } else {
            XCTFail("Last event must be .finalResponse, got \(last)")
        }
    }

    // MARK: - makeResponse() trace matches makeTrace() structure

    func testMakeResponseMatchesMakeTraceStructure() {
        let startedAt = Date(timeIntervalSince1970: 1700000000)
        let response = CanonicalRun.makeResponse(
            agentName: "TestAgent",
            modelLabel: "TestModel",
            startedAt: startedAt,
            onDevice: false
        )
        let trace = CanonicalRun.makeTrace(
            agentName: "TestAgent",
            modelLabel: "TestModel",
            startedAt: startedAt,
            onDevice: false
        )

        XCTAssertEqual(response.trace.runId, trace.runId)
        XCTAssertEqual(response.trace.agentName, trace.agentName)
        XCTAssertEqual(response.trace.modelLabel, trace.modelLabel)
        XCTAssertEqual(response.trace.totalLatencyMs, trace.totalLatencyMs)
        XCTAssertEqual(response.trace.onDevice, trace.onDevice)
        XCTAssertEqual(response.trace.bytesEgressed, trace.bytesEgressed)
        XCTAssertEqual(response.trace.events.count, trace.events.count)
        XCTAssertEqual(response.text, CanonicalRun.finalText)
    }

    // MARK: - HealthKit fixture values match SPEC §3

    func testHealthKitFixtureValuesMatchSpec() throws {
        // Read 1 — recovery snapshot
        let result1 = try JSONSerialization.jsonObject(
            with: Data(CanonicalRun.healthkitResult1JSON.utf8)
        ) as! [String: Any]
        XCTAssertEqual(result1["hrv"] as? Int, 58)
        XCTAssertEqual(result1["sleep"] as? Double, 7.2)
        XCTAssertEqual(result1["restingHeartRate"] as? Int, 54)

        // Read 2 — training load
        let result2 = try JSONSerialization.jsonObject(
            with: Data(CanonicalRun.healthkitResult2JSON.utf8)
        ) as! [String: Any]
        XCTAssertEqual(result2["activeEnergy"] as? Int, 11200)
        XCTAssertEqual(result2["window"] as? String, "7d")
        XCTAssertEqual(result2["deltaVsPriorPct"] as? Int, -8)

        // Read 3 — VO₂ Max
        let result3 = try JSONSerialization.jsonObject(
            with: Data(CanonicalRun.healthkitResult3JSON.utf8)
        ) as! [String: Any]
        XCTAssertEqual(result3["vo2Max"] as? Double, 47.2)
        XCTAssertEqual(result3["zone2BpmRange"] as? [Int], [130, 145])
    }

    // MARK: - WorkoutKit fixture values match SPEC §3

    func testWorkoutKitFixtureValuesMatchSpec() throws {
        let args = try JSONSerialization.jsonObject(
            with: Data(CanonicalRun.workoutkitArgsJSON.utf8)
        ) as! [String: Any]

        let exercises = args["exercises"] as! [[String: String]]
        XCTAssertEqual(exercises.count, 4)
        XCTAssertEqual(exercises[0]["name"], "Back Squat")
        XCTAssertEqual(exercises[0]["detail"], "4 × 5 @ 85%")
        XCTAssertEqual(exercises[1]["name"], "Romanian Deadlift")
        XCTAssertEqual(exercises[2]["name"], "Bulgarian Split Squat")
        XCTAssertEqual(exercises[3]["name"], "Cooldown")
        XCTAssertEqual(args["time"] as? String, "18:00")
        XCTAssertEqual(args["durationMin"] as? Int, 45)

        let result = try JSONSerialization.jsonObject(
            with: Data(CanonicalRun.workoutkitResultJSON.utf8)
        ) as! [String: Any]
        XCTAssertEqual(result["scheduled"] as? Bool, true)
        XCTAssertEqual(result["workoutId"] as? String, "wk_a1b2c3")
    }

    // MARK: - finalText is non-empty

    func testFinalTextIsNonEmpty() {
        XCTAssertFalse(CanonicalRun.finalText.isEmpty, "finalText must be non-empty")
        XCTAssertTrue(CanonicalRun.finalText.contains("Recovery"), "finalText should mention recovery")
    }

    // MARK: - Static identity fields

    func testStaticIdentityFields() {
        XCTAssertEqual(CanonicalRun.runId, "run_a1b2c3d4")
        XCTAssertEqual(CanonicalRun.agentName, "ForgeCoach")
        XCTAssertEqual(CanonicalRun.modelLabel, "Apple Foundation Models (on-device)")
        XCTAssertEqual(CanonicalRun.totalLatencyMs, 1200)
        XCTAssertEqual(CanonicalRun.bytesEgressed, 0)
    }

    // MARK: - Exercise fixtures

    func testExerciseFixtureCount() {
        XCTAssertEqual(CanonicalRun.exercises.count, 4)
        XCTAssertEqual(CanonicalRun.scheduleTime, "18:00")
        XCTAssertEqual(CanonicalRun.scheduleDurationMin, 45)
    }

    // MARK: - Helper

    private func extractAtMs(from event: TraceEvent) -> Int {
        switch event {
        case .userInput(let ms, _): return ms
        case .reasoning(let ms, _): return ms
        case .toolCall(let ms, _, _): return ms
        case .toolResult(let ms, _, _, _): return ms
        case .finalResponse(let ms, _): return ms
        }
    }
}
