import Foundation

/// Abstracts cloud-hosted model execution. Production code uses a real
/// HTTP client; tests inject a stub. Designed for dependency injection
/// so callers can swap cloud backends without touching agent logic.
public protocol CloudModelRunner: Sendable {
    /// Run the agent's input through the cloud model and return a response.
    func run(
        agent: Agent,
        input: String
    ) async throws -> AgentResponse
}

/// Default stub runner — returns the canonical ``AgentResponse`` with the
/// provider's label stamped in. Simulates a ~1200ms cloud round-trip for
/// demo cadence. Real network wiring lives behind the ``CloudModelRunner``
/// protocol seam for external implementations.
public struct StubCloudRunner: CloudModelRunner {
    public init() {}

    public func run(
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
