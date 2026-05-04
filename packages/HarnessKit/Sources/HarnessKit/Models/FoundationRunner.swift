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

    /// Run the agent. Returns the canonical AgentResponse with timings
    /// shaped to roughly match SPEC §3 (~1200ms total).
    static func run(
        agent: Agent,
        input: String
    ) async throws -> AgentResponse {
        let startedAt = Date()

        #if canImport(FoundationModels)
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

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
extension FoundationRunner {

    /// Real Foundation Models path. Probes runtime availability; if Apple
    /// Intelligence is not enabled / device not eligible / model not
    /// downloaded, falls back to the canonical stub. Otherwise issues a
    /// real `respond(to:)` call so we exercise the framework end-to-end,
    /// then returns the canonical trace + final text per SPEC §3.
    static func runWithFoundationModels(
        agent: Agent,
        input: String,
        startedAt: Date
    ) async throws -> AgentResponse {
        // Runtime availability check — simulator typically reports .unavailable.
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            // Apple Intelligence not enabled — use canonical fixture.
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

        // Issue the real call — best-effort. We don't read its output
        // because the canonical trace (SPEC §3) is the locked source of
        // truth for the demo. If the call throws, fall through to the stub.
        do {
            _ = try await session.respond(to: input)
        } catch {
            // Swallow — proceed with canonical fixture.
        }

        return CanonicalRun.makeResponse(
            agentName: agent.name,
            modelLabel: agent.model.label,
            startedAt: startedAt,
            onDevice: true
        )
    }
}

#endif
