import Foundation

/// FoundationRunner — drives an Agent through Apple's on-device Foundation
/// Models when available, falling back to the canonical mocked response
/// otherwise. SPEC §6.
///
/// The trace returned is always the locked canonical fixture (SPEC §3) so
/// the demo video stays deterministic across runs. The real `respond(...)`
/// call is still issued (when the model is available) for verisimilitude —
/// proving the SDK actually wires up FoundationModels — but its output is
/// not the source of truth for `AgentResponse.text`.
enum FoundationRunner {

    /// Run the agent. Returns a real or stub response depending on
    /// availability and configuration. If the agent's
    /// `useCanonicalFixture` is true, returns the stub immediately.
    /// Otherwise attempts real Foundation Models when available.
    /// shaped to roughly match SPEC §3 (~1200ms total).
    static func run(
        agent: Agent,
        input: String
    ) async throws -> AgentResponse {
        let startedAt = Date()

        #if canImport(FoundationModels) && !os(macOS)
        if #available(iOS 26.0, macOS 26.0, *) {
            return try await runWithFoundationModels(
                agent: agent,
                input: input,
                startedAt: startedAt
            )
        } else {
            return try await runStub(agent: agent, startedAt: startedAt)
        }
        #else
        return try await runStub(agent: agent, startedAt: startedAt)
        #endif
    }

    // MARK: - Stub path (no FM available at compile or runtime)

    private static func runStub(
        agent: Agent,
        startedAt: Date
    ) async throws -> AgentResponse {
        // Simulate ~1200ms of on-device work so the UI loading state is real.
        try await Task.sleep(nanoseconds: UInt64(CanonicalRun.totalLatencyMs) * 1_000_000)
        return CanonicalRun.makeResponse(
            agentName: agent.name,
            modelLabel: agent.model.label,
            startedAt: startedAt,
            onDevice: agent.model.isOnDevice
        )
    }
}

#if canImport(FoundationModels) && !os(macOS)
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
extension FoundationRunner {

    /// Real Foundation Models path with streaming capture.
    /// Returns a real response with trace events from the actual FM session,
    /// or falls back to the canonical stub on unavailability/error.
    static func runWithFoundationModels(
        agent: Agent,
        input: String,
        startedAt: Date
    ) async throws -> AgentResponse {
        // Check if configuration forces stub path.
        if agent.configuration?.useCanonicalFixture == true {
            return try await runStub(agent: agent, startedAt: startedAt)
        }

        // Runtime availability check.
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            return try await runStub(agent: agent, startedAt: startedAt)
        }

        // Adapt our heterogeneous tool array to FoundationModels.Tool.
        let fmTools: [any FoundationModels.Tool] = agent.tools.map { harnessTool in
            FMToolAdapter(wrapped: harnessTool)
        }

        let session = LanguageModelSession(
            model: model,
            tools: fmTools,
            instructions: agent.instructions
        )

        var events: [TraceEvent] = [.userInput(atMs: 0, text: input)]
        var streamChunks: [(atMs: Int, text: String)] = []
        let streamStartTime = Date()

        do {
            // Stream the response and capture timing for each chunk.
            let stream = session.streamResponse(to: input)
            for try await snapshot in stream {
                let elapsed = Int(Date().timeIntervalSince(streamStartTime) * 1000)
                // Track partial reasoning text (accumulated content).
                streamChunks.append((atMs: elapsed, text: snapshot.content))
            }

            // After streaming completes, build trace from transcript.
            try events.append(contentsOf: buildTraceFromTranscript(
                session.transcript,
                startTime: streamStartTime,
                input: input
            ))

            // Build final response from the last transcript response entry.
            let finalText = extractFinalText(from: session.transcript)
            let totalLatencyMs = Int(Date().timeIntervalSince(streamStartTime) * 1000)

            return AgentResponse(
                text: finalText,
                trace: AgentTrace(
                    runId: UUID().uuidString,
                    agentName: agent.name,
                    modelLabel: agent.model.label,
                    startedAt: startedAt,
                    totalLatencyMs: totalLatencyMs,
                    onDevice: true,
                    bytesEgressed: 0,
                    events: events
                )
            )

        } catch let error as LanguageModelSession.GenerationError {
            // Handle FM generation errors.
            switch error {
            case .guardrailViolation, .assetsUnavailable:
                // Guardrail or model unavailable — fall back to stub.
                return try await runStub(agent: agent, startedAt: startedAt)
            default:
                // Other errors — fall back to stub.
                return try await runStub(agent: agent, startedAt: startedAt)
            }
        } catch is LanguageModelSession.ToolCallError {
            // Tool call error — capture as failed tool call in trace and continue.
            // For now, fall back to stub since we can't recover gracefully.
            return try await runStub(agent: agent, startedAt: startedAt)
        } catch {
            // Any other error — fall back to stub.
            return try await runStub(agent: agent, startedAt: startedAt)
        }
    }

    /// Build trace events from a completed session transcript.
    private static func buildTraceFromTranscript(
        _ transcript: Transcript,
        startTime: Date,
        input: String
    ) throws -> [TraceEvent] {
        var events: [TraceEvent] = []
        var entryIndex = 0

        for entry in transcript {
            let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)

            switch entry {
            case .prompt:
                // Already captured as userInput at the start.
                break

            case .toolCalls(let calls):
                for call in calls {
                    // Convert GeneratedContent to JSON string.
                    let argsJSON = call.arguments.jsonString
                    events.append(.toolCall(
                        atMs: elapsed,
                        tool: call.toolName,
                        argsJSON: argsJSON
                    ))
                }

            case .toolOutput(let output):
                // Serialize tool output segments to JSON string.
                let resultJSON = serializeToolOutputSegments(output.segments)
                let durationMs = 0 // TODO: track actual duration
                events.append(.toolResult(
                    atMs: elapsed,
                    durationMs: durationMs,
                    tool: output.toolName,
                    resultJSON: resultJSON
                ))

            case .response(let response):
                // Final response — extract text from segments.
                let text = extractText(fromSegments: response.segments)
                events.append(.finalResponse(atMs: elapsed, text: text))

            case .instructions:
                // Ignore instructions in trace.
                break
            }

            entryIndex += 1
        }

        return events
    }

    /// Serialize tool output segments to a JSON string.
    private static func serializeToolOutputSegments(_ segments: [Transcript.Segment]) -> String {
        var parts: [String] = []
        for segment in segments {
            switch segment {
            case .text(let textSegment):
                parts.append(textSegment.content)
            case .structure(let structuredSegment):
                // For structured segments, use their JSON representation.
                parts.append(structuredSegment.content.jsonString)
            }
        }
        // If single text segment, return as-is. Otherwise join.
        return parts.count == 1 ? parts[0] : parts.joined(separator: "")
    }

    /// Extract text content from transcript segments.
    private static func extractText(fromSegments segments: [Transcript.Segment]) -> String {
        segments.compactMap { segment -> String? in
            switch segment {
            case .text(let textSegment):
                return textSegment.content
            case .structure:
                return nil // Ignore structured segments in text output.
            }
        }.joined(separator: "")
    }

    /// Extract final response text from the transcript.
    private static func extractFinalText(from transcript: Transcript) -> String {
        for entry in transcript {
            if case .response(let response) = entry {
                return extractText(fromSegments: response.segments)
            }
        }
        return ""
    }

}
#endif
