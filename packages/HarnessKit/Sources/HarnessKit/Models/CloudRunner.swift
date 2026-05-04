import Foundation

/// CloudRunner — placeholder for hosted-model fallback (Claude / GPT).
/// v0 stub returns the canonical AgentResponse with the provider's label
/// stamped in. Real network wiring lives behind this seam.
enum CloudRunner {
    static func run(
        agent: Agent,
        input: String
    ) async throws -> AgentResponse {
        let startedAt = Date()
        // Simulate cloud round-trip ~1200ms (matching demo cadence).
        try await Task.sleep(nanoseconds: UInt64(CanonicalRun.totalLatencyMs) * 1_000_000)
        return CanonicalRun.makeResponse(
            agentName: agent.name,
            modelLabel: agent.model.label,
            startedAt: startedAt,
            onDevice: false
        )
    }
}
