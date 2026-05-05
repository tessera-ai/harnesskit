import Foundation

/// Tessera's hero type — declarative description of an AI agent that
/// runs on-device by default, with optional cloud fallback. SPEC §1, §2.
public struct Agent: Sendable {
    public let name: String
    public let instructions: String
    public let tools: [any Tool]
    public let model: ModelProvider
    public let fallback: ModelProvider?
    public let configuration: AgentConfiguration?

    public init(
        name: String,
        instructions: String,
        tools: [any Tool],
        model: ModelProvider,
        configuration: AgentConfiguration? = nil,
        fallback: ModelProvider? = nil
    ) {
        self.name = name
        self.instructions = instructions
        self.tools = tools
        self.model = model
        self.fallback = fallback
        self.configuration = configuration
    }

    /// Run the agent. Dispatches to `FoundationRunner` for on-device models
    /// and `CloudRunner` for hosted ones. If the primary throws, falls back
    /// to the configured `fallback` provider when present; otherwise the
    /// error is propagated.
    public func run(_ input: String) async throws -> AgentResponse {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TesseraError.invalidInput("Input must not be empty or whitespace")
        }
        do {
            return try await runOn(provider: model, input: input)
        } catch {
            if let fallback {
                return try await runOn(provider: fallback, input: input)
            }
            throw error
        }
    }

    private func runOn(
        provider: ModelProvider,
        input: String
    ) async throws -> AgentResponse {
        switch provider {
        case .onDevice:
            return try await FoundationRunner.run(agent: self, input: input)
        case .cloud:
            return try await CloudRunner.run(agent: self, input: input)
        }
    }
}

/// The result of running an ``Agent``. Contains the model's text output and
/// a full ``AgentTrace`` for debugging, replay, and analytics.
public struct AgentResponse: Sendable {
    /// The model's final text response.
    public let text: String
    /// Structured trace of every event during the run (tool calls, reasoning, etc.).
    public let trace: AgentTrace

    public init(text: String, trace: AgentTrace) {
        self.text = text
        self.trace = trace
    }
}
