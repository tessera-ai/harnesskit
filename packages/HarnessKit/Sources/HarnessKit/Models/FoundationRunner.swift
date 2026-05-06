import Foundation

/// FoundationRunner — drives an Agent through Apple's on-device Foundation
/// Models when available, falling back to the canonical mocked response
/// otherwise. SPEC §6.
///
/// When `AgentConfiguration.useCanonicalFixture` is true, always returns
/// the canonical stub. Otherwise, when FM is available at runtime, streams
/// a real response with trace events. On error, throws ``TesseraError``
/// rather than silently falling back to the stub — callers with a
/// `fallback` provider will have `Agent.run()` route accordingly.
enum FoundationRunner {

    /// Run the agent. Returns a real or stub response depending on
    /// availability and configuration.
    static func run(
        agent: Agent,
        input: String
    ) async throws -> AgentResponse {
        let startedAt = Date()

        // If configuration forces canonical fixture, skip FM entirely.
        if agent.configuration?.useCanonicalFixture == true {
            return try await runStub(agent: agent, startedAt: startedAt)
        }

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

    static func runStub(
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
        /// Returns a real response with trace events from the actual FM session.
        /// Throws ``TesseraError`` on failure so callers can route to fallback.
        static func runWithFoundationModels(
            agent: Agent,
            input: String,
            startedAt: Date
        ) async throws -> AgentResponse {
            // Runtime availability check.
            let model = SystemLanguageModel.default
            guard case .available = model.availability else {
                throw TesseraError.modelUnavailable(reason: "Apple Foundation Models are not available on this device")
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
            // Track per-event timing from the stream.
            var eventTimings: [(event: TraceEvent, atMs: Int)] = []
            let streamStartTime = Date()

            do {
                // Stream the response and build trace events incrementally.
                let stream = session.streamResponse(to: input)
                for try await snapshot in stream {
                    let elapsed = Int(Date().timeIntervalSince(streamStartTime) * 1000)
                    // Capture partial text chunks for timing reference.
                    _ = snapshot.content
                    // We'll build the trace from the transcript after streaming,
                    // but record timing checkpoints from the stream itself.
                    eventTimings = buildEventsFromSnapshot(
                        session.transcript,
                        elapsed: elapsed,
                        existingEvents: &events
                    )
                }

                // Build final trace from completed transcript with proper timing.
                let transcriptEvents = buildTraceFromTranscript(
                    session.transcript,
                    startTime: streamStartTime,
                    input: input
                )
                events.append(contentsOf: transcriptEvents)

                // Extract text from the LAST response entry (not the first).
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
                switch error {
                case .guardrailViolation:
                    throw TesseraError.modelUnavailable(
                        reason: "Safety filter triggered — the model refused to respond")
                case .assetsUnavailable:
                    throw TesseraError.modelUnavailable(
                        reason: "Foundation Models assets are not downloaded on this device")
                default:
                    throw TesseraError.modelUnavailable(reason: error.localizedDescription)
                }
            } catch is LanguageModelSession.ToolCallError {
                throw TesseraError.toolError(
                    tool: "unknown",
                    underlying: NSError(
                        domain: "HarnessKit",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Foundation Models tool call failed"]
                    )
                )
            } catch {
                throw TesseraError.modelUnavailable(reason: error.localizedDescription)
            }
        }

        /// Build trace events from a completed session transcript.
        /// Uses stream-relative timing: each entry's atMs is computed from
        /// the stream start time, recorded as entries are iterated.
        private static func buildTraceFromTranscript(
            _ transcript: Transcript,
            startTime: Date,
            input: String
        ) -> [TraceEvent] {
            var events: [TraceEvent] = []

            for entry in transcript {
                let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)

                switch entry {
                case .prompt:
                    // Already captured as userInput at the start.
                    break

                case .toolCalls(let calls):
                    for call in calls {
                        let argsJSON = call.arguments.jsonString
                        events.append(
                            .toolCall(
                                atMs: elapsed,
                                tool: call.toolName,
                                argsJSON: argsJSON
                            ))
                    }

                case .toolOutput(let output):
                    let resultJSON = serializeToolOutputSegments(output.segments)
                    events.append(
                        .toolResult(
                            atMs: elapsed,
                            durationMs: 0,
                            tool: output.toolName,
                            resultJSON: resultJSON
                        ))

                case .response(let response):
                    let text = extractText(fromSegments: response.segments)
                    // Only the LAST response is a finalResponse.
                    // Earlier responses are treated as reasoning.
                    // We'll fix this below after the loop.
                    events.append(.finalResponse(atMs: elapsed, text: text))

                case .instructions:
                    break
                @unknown default:
                    break
                }
            }

            // If there are multiple .response entries, convert all but the
            // last to .reasoning so only the true final response is .finalResponse.
            let finalResponseIndices = events.indices.filter {
                if case .finalResponse = events[$0] { return true }
                return false
            }
            if finalResponseIndices.count > 1 {
                for index in finalResponseIndices.dropLast() {
                    if case .finalResponse(atMs: let ms, text: let txt) = events[index] {
                        events[index] = .reasoning(atMs: ms, text: txt)
                    }
                }
            }

            return events
        }

        /// Placeholder — snapshot-driven timing capture during streaming.
        /// Returns empty array; real timing is handled by buildTraceFromTranscript.
        private static func buildEventsFromSnapshot(
            _ transcript: Transcript,
            elapsed: Int,
            existingEvents: inout [TraceEvent]
        ) -> [(event: TraceEvent, atMs: Int)] {
            // Timing is driven by buildTraceFromTranscript after the stream completes.
            // This hook exists for future incremental event capture.
            return []
        }

        /// Serialize tool output segments to a JSON string.
        private static func serializeToolOutputSegments(_ segments: [Transcript.Segment]) -> String {
            var parts: [String] = []
            for segment in segments {
                switch segment {
                case .text(let textSegment):
                    parts.append(textSegment.content)
                case .structure(let structuredSegment):
                    parts.append(structuredSegment.content.jsonString)
                @unknown default:
                    break
                }
            }
            return parts.count == 1 ? parts[0] : parts.joined(separator: "")
        }

        /// Extract text content from transcript segments.
        private static func extractText(fromSegments segments: [Transcript.Segment]) -> String {
            segments.compactMap { segment -> String? in
                switch segment {
                case .text(let textSegment):
                    return textSegment.content
                case .structure:
                    return nil
                @unknown default:
                    return nil
                }
            }.joined(separator: "")
        }

        /// Extract final response text from the transcript.
        /// Walks in reverse to find the LAST .response entry.
        private static func extractFinalText(from transcript: Transcript) -> String {
            for entry in transcript.reversed() {
                if case .response(let response) = entry {
                    return extractText(fromSegments: response.segments)
                }
            }
            return ""
        }

    }
#endif
