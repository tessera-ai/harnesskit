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
        // Canonical SPEC §3 fixture is 14 events (3 healthkit reads + workoutkit + reasoning/io).
        XCTAssertEqual(response.trace.events.count, 14)
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
        let argsJSON = CanonicalRun.workoutkitArgsJSON
        let result = try await tool.invokeJSON(argsJSON)
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

    // MARK: - Error paths

    func testRunWithEmptyInputThrowsInvalidInput() async {
        let coach = Agent(
            name: "TestCoach",
            instructions: "Test",
            tools: [HealthKit.read(.hrv)],
            model: .onDevice(.foundation)
        )
        do {
            _ = try await coach.run("")
            XCTFail("Expected TesseraError.invalidInput for empty input")
        } catch let error as TesseraError {
            if case .invalidInput(let detail) = error {
                XCTAssertTrue(
                    detail.localizedCaseInsensitiveContains("empty"),
                    "Error detail should mention empty"
                )
            } else {
                XCTFail("Expected .invalidInput, got \(error)")
            }
        } catch {
            XCTFail("Expected TesseraError, got \(error)")
        }
    }

    func testRunWithWhitespaceOnlyInputThrowsInvalidInput() async {
        let coach = Agent(
            name: "TestCoach",
            instructions: "Test",
            tools: [HealthKit.read(.hrv)],
            model: .onDevice(.foundation)
        )
        do {
            _ = try await coach.run("   \n\t  ")
            XCTFail("Expected TesseraError.invalidInput for whitespace-only input")
        } catch let error as TesseraError {
            if case .invalidInput = error {
                // Correct
            } else {
                XCTFail("Expected .invalidInput, got \(error)")
            }
        } catch {
            XCTFail("Expected TesseraError, got \(error)")
        }
    }

    // MARK: - Fallback agent

    func testFallbackAgentReturnsCanonicalResponse() async throws {
        let coach = Agent(
            name: "FallbackCoach",
            instructions: "Test fallback",
            tools: [HealthKit.read(.hrv)],
            model: .onDevice(.foundation),
            fallback: .cloud(.claude)
        )
        // On macOS, FoundationRunner stub succeeds immediately (no fallback triggered)
        let response = try await coach.run("Plan my workout")
        XCTAssertFalse(response.text.isEmpty)
        XCTAssertEqual(response.trace.events.count, 14)
    }

    // MARK: - TesseraError equality

    func testTesseraErrorEquality() {
        // Same case, same values -> equal
        XCTAssertEqual(
            TesseraError.modelUnavailable(reason: "x"),
            TesseraError.modelUnavailable(reason: "x")
        )
        XCTAssertEqual(
            TesseraError.invalidInput("a"),
            TesseraError.invalidInput("a")
        )
        XCTAssertEqual(
            TesseraError.noToolsRegistered,
            TesseraError.noToolsRegistered
        )

        // Same case, different values -> not equal
        XCTAssertNotEqual(
            TesseraError.modelUnavailable(reason: "x"),
            TesseraError.modelUnavailable(reason: "y")
        )
        XCTAssertNotEqual(
            TesseraError.invalidInput("a"),
            TesseraError.invalidInput("b")
        )

        // Different cases -> not equal
        XCTAssertNotEqual(
            TesseraError.modelUnavailable(reason: "x"),
            TesseraError.invalidInput("x")
        )
    }

    // MARK: - TesseraError localized descriptions

    func testTesseraErrorLocalizedDescriptions() {
        let modelErr = TesseraError.modelUnavailable(reason: "not enabled")
        XCTAssertTrue(modelErr.localizedDescription.contains("not enabled"))

        let inputErr = TesseraError.invalidInput("empty")
        XCTAssertTrue(inputErr.localizedDescription.contains("empty"))

        let noToolsErr = TesseraError.noToolsRegistered
        XCTAssertTrue(noToolsErr.localizedDescription.contains("no tools"))

        let toolErr = TesseraError.toolError(
            tool: "healthkit_read",
            underlying: NSError(domain: "Test", code: 1)
        )
        XCTAssertTrue(toolErr.localizedDescription.contains("healthkit_read"))
    }

    func testTesseraErrorFallbackFailedDescription() {
        let primary = TesseraError.modelUnavailable(reason: "primary down")
        let fallback = TesseraError.modelUnavailable(reason: "fallback down")
        let error = TesseraError.fallbackFailed(primary: primary, fallback: fallback)
        XCTAssertTrue(error.localizedDescription.contains("Both providers failed"))
        XCTAssertTrue(error.localizedDescription.contains("primary down"))
        XCTAssertTrue(error.localizedDescription.contains("fallback down"))
    }

    // MARK: - AgentConfiguration defaults

    func testAgentConfigurationDefaultsToFalse() {
        let config = AgentConfiguration()
        XCTAssertFalse(config.useCanonicalFixture)

        let explicitConfig = AgentConfiguration(useCanonicalFixture: true)
        XCTAssertTrue(explicitConfig.useCanonicalFixture)
    }
}
