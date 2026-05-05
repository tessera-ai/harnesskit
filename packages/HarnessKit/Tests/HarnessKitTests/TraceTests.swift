import XCTest
@testable import Tessera

final class TraceTests: XCTestCase {

    // MARK: - TraceEvent Codable round-trip (all 5 cases)

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    private let decoder = JSONDecoder()

    func testUserInputCodableRoundTrip() throws {
        let original = TraceEvent.userInput(atMs: 42, text: "hello")
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(TraceEvent.self, from: data)
        if case .userInput(let atMs, let text) = decoded {
            XCTAssertEqual(atMs, 42)
            XCTAssertEqual(text, "hello")
        } else {
            XCTFail("Expected .userInput, got \(decoded)")
        }
    }

    func testReasoningCodableRoundTrip() throws {
        let original = TraceEvent.reasoning(atMs: 100, text: "thinking hard")
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(TraceEvent.self, from: data)
        if case .reasoning(let atMs, let text) = decoded {
            XCTAssertEqual(atMs, 100)
            XCTAssertEqual(text, "thinking hard")
        } else {
            XCTFail("Expected .reasoning, got \(decoded)")
        }
    }

    func testToolCallCodableRoundTrip() throws {
        let original = TraceEvent.toolCall(atMs: 200, tool: "healthkit_read", argsJSON: #"{"metrics":["hrv"]}"#)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(TraceEvent.self, from: data)
        if case .toolCall(let atMs, let tool, let argsJSON) = decoded {
            XCTAssertEqual(atMs, 200)
            XCTAssertEqual(tool, "healthkit_read")
            XCTAssertEqual(argsJSON, #"{"metrics":["hrv"]}"#)
        } else {
            XCTFail("Expected .toolCall, got \(decoded)")
        }
    }

    func testToolResultCodableRoundTrip() throws {
        let original = TraceEvent.toolResult(atMs: 300, durationMs: 100, tool: "healthkit_read", resultJSON: #"{"hrv":58}"#)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(TraceEvent.self, from: data)
        if case .toolResult(let atMs, let durationMs, let tool, let resultJSON) = decoded {
            XCTAssertEqual(atMs, 300)
            XCTAssertEqual(durationMs, 100)
            XCTAssertEqual(tool, "healthkit_read")
            XCTAssertEqual(resultJSON, #"{"hrv":58}"#)
        } else {
            XCTFail("Expected .toolResult, got \(decoded)")
        }
    }

    func testFinalResponseCodableRoundTrip() throws {
        let original = TraceEvent.finalResponse(atMs: 1200, text: "Done!")
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(TraceEvent.self, from: data)
        if case .finalResponse(let atMs, let text) = decoded {
            XCTAssertEqual(atMs, 1200)
            XCTAssertEqual(text, "Done!")
        } else {
            XCTFail("Expected .finalResponse, got \(decoded)")
        }
    }

    // MARK: - TraceEvent equality after encode/decode (spot-check canonical fixture)

    func testCanonicalEventsMatchAfterRoundTrip() throws {
        let originals = CanonicalRun.makeEvents()
        for (i, original) in originals.enumerated() {
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(TraceEvent.self, from: data)
            switch (original, decoded) {
            case (.userInput(let a1, let b1), .userInput(let a2, let b2)):
                XCTAssertEqual(a1, a2, "atMs mismatch at event[\(i)]")
                XCTAssertEqual(b1, b2, "text mismatch at event[\(i)]")
            case (.reasoning(let a1, let b1), .reasoning(let a2, let b2)):
                XCTAssertEqual(a1, a2, "atMs mismatch at event[\(i)]")
                XCTAssertEqual(b1, b2, "text mismatch at event[\(i)]")
            case (.toolCall(let a1, let b1, let c1), .toolCall(let a2, let b2, let c2)):
                XCTAssertEqual(a1, a2, "atMs mismatch at event[\(i)]")
                XCTAssertEqual(b1, b2, "tool mismatch at event[\(i)]")
                XCTAssertEqual(c1, c2, "argsJSON mismatch at event[\(i)]")
            case (.toolResult(let a1, let b1, let c1, let d1), .toolResult(let a2, let b2, let c2, let d2)):
                XCTAssertEqual(a1, a2, "atMs mismatch at event[\(i)]")
                XCTAssertEqual(b1, b2, "durationMs mismatch at event[\(i)]")
                XCTAssertEqual(c1, c2, "tool mismatch at event[\(i)]")
                XCTAssertEqual(d1, d2, "resultJSON mismatch at event[\(i)]")
            case (.finalResponse(let a1, let b1), .finalResponse(let a2, let b2)):
                XCTAssertEqual(a1, a2, "atMs mismatch at event[\(i)]")
                XCTAssertEqual(b1, b2, "text mismatch at event[\(i)]")
            default:
                XCTFail("Kind mismatch at event[\(i)]: \(original) vs \(decoded)")
            }
        }
    }

    // MARK: - Empty and single-event traces

    func testEmptyEventsTrace() throws {
        let trace = AgentTrace(
            runId: "empty",
            agentName: "Test",
            modelLabel: "Test",
            startedAt: Date(),
            totalLatencyMs: 0,
            onDevice: true,
            bytesEgressed: 0,
            events: []
        )
        XCTAssertTrue(trace.events.isEmpty)
        let data = try encoder.encode(trace)
        let decoded = try decoder.decode(AgentTrace.self, from: data)
        XCTAssertTrue(decoded.events.isEmpty)
        XCTAssertEqual(decoded.runId, "empty")
    }

    func testSingleEventTrace() throws {
        let event = TraceEvent.finalResponse(atMs: 50, text: "Quick")
        let trace = AgentTrace(
            runId: "single",
            agentName: "Test",
            modelLabel: "Test",
            startedAt: Date(),
            totalLatencyMs: 50,
            onDevice: true,
            bytesEgressed: 0,
            events: [event]
        )
        XCTAssertEqual(trace.events.count, 1)
        let data = try encoder.encode(trace)
        let decoded = try decoder.decode(AgentTrace.self, from: data)
        XCTAssertEqual(decoded.events.count, 1)
        if case .finalResponse(let atMs, let text) = decoded.events[0] {
            XCTAssertEqual(atMs, 50)
            XCTAssertEqual(text, "Quick")
        } else {
            XCTFail("Expected .finalResponse")
        }
    }

    // MARK: - Large trace (1000 events)

    func testLargeTraceHandles1000Events() throws {
        let events = (0..<1000).map { i -> TraceEvent in
            .reasoning(atMs: i, text: "Step \(i)")
        }
        let trace = AgentTrace(
            runId: "large",
            agentName: "StressTest",
            modelLabel: "Test",
            startedAt: Date(),
            totalLatencyMs: 999,
            onDevice: false,
            bytesEgressed: 0,
            events: events
        )
        XCTAssertEqual(trace.events.count, 1000)

        measure {
            _ = try? encoder.encode(trace)
        }

        let data = try encoder.encode(trace)
        let decoded = try decoder.decode(AgentTrace.self, from: data)
        XCTAssertEqual(decoded.events.count, 1000)
        if case .reasoning(let atMs, _) = decoded.events[999] {
            XCTAssertEqual(atMs, 999)
        } else {
            XCTFail("Last event should be reasoning at ms=999")
        }
    }

    // MARK: - AgentTrace Codable round-trip

    func testAgentTraceCodableRoundTrip() throws {
        let original = CanonicalRun.makeTrace()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AgentTrace.self, from: data)

        XCTAssertEqual(decoded.runId, original.runId)
        XCTAssertEqual(decoded.agentName, original.agentName)
        XCTAssertEqual(decoded.modelLabel, original.modelLabel)
        XCTAssertEqual(decoded.totalLatencyMs, original.totalLatencyMs)
        XCTAssertEqual(decoded.onDevice, original.onDevice)
        XCTAssertEqual(decoded.bytesEgressed, original.bytesEgressed)
        XCTAssertEqual(decoded.events.count, original.events.count)
    }

    // MARK: - atMs monotonicity in canonical fixture

    func testCanonicalFixtureAtMsIsNonDecrecreasing() {
        let events = CanonicalRun.makeEvents()
        var previous = -1
        for (i, event) in events.enumerated() {
            let atMs: Int
            switch event {
            case .userInput(let ms, _): atMs = ms
            case .reasoning(let ms, _): atMs = ms
            case .toolCall(let ms, _, _): atMs = ms
            case .toolResult(let ms, _, _, _): atMs = ms
            case .finalResponse(let ms, _): atMs = ms
            }
            XCTAssertGreaterThanOrEqual(atMs, previous, "atMs must be non-decreasing; violation at event[\(i)]")
            previous = atMs
        }
    }
}
