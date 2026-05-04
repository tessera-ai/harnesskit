import XCTest
@testable import Tessera

final class AgentTests: XCTestCase {

    // MARK: - Hero-shot construction (SPEC §1, must compile verbatim)

    /// Compile-checks the exact hero-shot snippet from SPEC §1. If this
    /// breaks, the README/marketing material breaks too.
    func testHeroShotConstructs() throws {
        let coach = Agent(
            name: "ForgeCoach",
            instructions: "Plan today's lift based on recovery.",
            tools: [
                HealthKit.read(.hrv, .sleep, .restingHeartRate),
                WorkoutKit.schedule
            ],
            model: .onDevice(.foundation),
            fallback: .cloud(.claude)
        )

        XCTAssertEqual(coach.name, "ForgeCoach")
        XCTAssertEqual(coach.instructions, "Plan today's lift based on recovery.")
        XCTAssertEqual(coach.tools.count, 2)
        XCTAssertEqual(coach.tools[0].name, "healthkit_read")
        XCTAssertEqual(coach.tools[1].name, "workoutkit_schedule")
        XCTAssertNotNil(coach.fallback)
    }

    // MARK: - run() returns canonical response with non-empty trace

    func testRunReturnsNonEmptyTrace() async throws {
        let coach = Agent(
            name: "ForgeCoach",
            instructions: "Plan today's lift based on recovery.",
            tools: [
                HealthKit.read(.hrv, .sleep, .restingHeartRate),
                WorkoutKit.schedule
            ],
            model: .onDevice(.foundation),
            fallback: .cloud(.claude)
        )

        let response = try await coach.run("Plan my workout for today")

        XCTAssertFalse(response.text.isEmpty, "final text should be non-empty")
        XCTAssertEqual(response.trace.agentName, "ForgeCoach")
        XCTAssertGreaterThan(response.trace.events.count, 0, "trace events must be non-empty")
        // Canonical SPEC §3 fixture is 8 events.
        XCTAssertEqual(response.trace.events.count, 8)
        XCTAssertEqual(response.trace.totalLatencyMs, 1200)
        XCTAssertEqual(response.trace.bytesEgressed, 0)
    }

    // MARK: - Tool JSON contract

    func testHealthKitToolReturnsCanonicalSnapshot() async throws {
        let tool = HealthKit.read(.hrv, .sleep, .restingHeartRate)
        let result = try await tool.invokeJSON("{}")
        XCTAssertTrue(result.contains("\"hrv\":58"))
        XCTAssertTrue(result.contains("\"sleep\":7.2"))
        XCTAssertTrue(result.contains("\"restingHeartRate\":54"))
    }

    func testWorkoutKitToolReturnsScheduledTrue() async throws {
        let tool = WorkoutKit.schedule
        let result = try await tool.invokeJSON("{}")
        XCTAssertTrue(result.contains("\"scheduled\":true"))
        XCTAssertTrue(result.contains("\"workoutId\":\"wk_a1b2c3\""))
    }

    // MARK: - Trace Codable round-trip

    func testTraceCodableRoundTrip() throws {
        let original = CanonicalRun.makeTrace()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AgentTrace.self, from: data)
        XCTAssertEqual(decoded.runId, original.runId)
        XCTAssertEqual(decoded.events.count, original.events.count)
        // Spot-check one event of each kind.
        if case .userInput(_, let text) = decoded.events[0] {
            XCTAssertEqual(text, "Plan my workout for today")
        } else {
            XCTFail("expected userInput at events[0]")
        }
        if case .toolCall(_, let tool, _) = decoded.events[2] {
            XCTAssertEqual(tool, "healthkit_read")
        } else {
            XCTFail("expected toolCall at events[2]")
        }
        if case .finalResponse(_, let text) = decoded.events.last! {
            XCTAssertTrue(text.contains("Recovery is solid"))
        } else {
            XCTFail("expected finalResponse at events.last")
        }
    }

    // MARK: - ModelProvider labels

    func testModelProviderLabels() {
        XCTAssertEqual(ModelProvider.onDevice(.foundation).label, "Apple Foundation Models (on-device)")
        XCTAssertTrue(ModelProvider.onDevice(.foundation).isOnDevice)
        XCTAssertFalse(ModelProvider.cloud(.claude).isOnDevice)
    }
}
