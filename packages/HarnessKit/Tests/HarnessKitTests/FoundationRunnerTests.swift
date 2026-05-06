import XCTest

@testable import Tessera

final class FoundationRunnerTests: XCTestCase {

    // MARK: - Stub path tests

    /// Test that `runStub()` returns canonical fixture with correct timings.
    /// Test that stub path (triggered on macOS) returns canonical fixture.
    func testStubPathOnMacOSReturnsCanonicalFixture() async throws {
        let agent = Agent(
            name: "TestAgent",
            instructions: "Test instructions",
            tools: [HealthKit.read(.hrv), WorkoutKit.schedule],
            model: .onDevice(.foundation)
        )

        // On macOS, FM is unavailable so this takes the stub path.
        let response = try await agent.run("Test input")

        // Verify canonical fixture data.
        XCTAssertEqual(response.trace.agentName, "TestAgent")
        XCTAssertEqual(response.trace.modelLabel, "Apple Foundation Models (on-device)")
        XCTAssertEqual(response.trace.totalLatencyMs, 1200)
        XCTAssertEqual(response.trace.bytesEgressed, 0)
        XCTAssertTrue(response.trace.onDevice)

        // Verify 14 canonical trace events per SPEC §3.
        XCTAssertEqual(response.trace.events.count, 14)

        // Verify event sequence.
        if case .userInput(let atMs, _) = response.trace.events[0] {
            XCTAssertEqual(atMs, 0)
        } else {
            XCTFail("First event should be userInput")
        }

        if case .finalResponse(let atMs, let text) = response.trace.events.last! {
            XCTAssertEqual(atMs, 1200)
            XCTAssertTrue(text.contains("Recovery is solid"))
        } else {
            XCTFail("Last event should be finalResponse")
        }

        // Verify HealthKit tool calls are present.
        let toolCallEvents = response.trace.events.compactMap { event -> String? in
            if case .toolCall(_, let tool, _) = event {
                return tool
            }
            return nil
        }
        XCTAssertTrue(toolCallEvents.contains("healthkit_read"))
        XCTAssertTrue(toolCallEvents.contains("workoutkit_schedule"))
    }

    /// Test that `AgentConfiguration.useCanonicalFixture` forces stub path.
    func testAgentConfigurationForcesStubPath() async throws {
        let agentWithConfig = Agent(
            name: "TestAgent",
            instructions: "Test instructions",
            tools: [HealthKit.read(.hrv)],
            model: .onDevice(.foundation),
            configuration: AgentConfiguration(useCanonicalFixture: true)
        )

        let agentWithoutConfig = Agent(
            name: "TestAgent",
            instructions: "Test instructions",
            tools: [HealthKit.read(.hrv)],
            model: .onDevice(.foundation)
        )

        // Both should return canonical fixture on macOS (FM unavailable).
        let response1 = try await agentWithConfig.run("Test")
        let response2 = try await agentWithoutConfig.run("Test")

        XCTAssertEqual(response1.trace.events.count, 14)
        XCTAssertEqual(response2.trace.events.count, 14)
    }

    /// Test trace event count matches SPEC §3 when using stub.
    func testStubPathReturns14Events() async throws {
        let agent = Agent(
            name: "ForgeCoach",
            instructions: "Plan today's lift",
            tools: [
                HealthKit.read(.hrv, .sleep, .restingHeartRate),
                WorkoutKit.schedule,
            ],
            model: .onDevice(.foundation)
        )

        let response = try await agent.run("Plan my workout for today")

        XCTAssertEqual(response.trace.events.count, 14, "Stub should return exactly 14 canonical events")

        // Verify all expected event types are present.
        let eventTypes = response.trace.events.map { event -> String in
            switch event {
            case .userInput: return "userInput"
            case .reasoning: return "reasoning"
            case .toolCall: return "toolCall"
            case .toolResult: return "toolResult"
            case .finalResponse: return "finalResponse"
            }
        }

        XCTAssertEqual(eventTypes.filter { $0 == "userInput" }.count, 1)
        XCTAssertEqual(eventTypes.filter { $0 == "toolCall" }.count, 4)
        XCTAssertEqual(eventTypes.filter { $0 == "toolResult" }.count, 4)
        XCTAssertEqual(eventTypes.filter { $0 == "reasoning" }.count, 4)
        XCTAssertEqual(eventTypes.filter { $0 == "finalResponse" }.count, 1)

        // 1 + 4 + 4 + 4 + 1 = 14 ✓
    }
}
