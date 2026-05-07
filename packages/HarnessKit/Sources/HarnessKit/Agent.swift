import Foundation

/// Tessera's hero type — declarative description of an AI agent that
/// runs on-device by default, with optional cloud fallback. SPEC §1, §2.
public struct Agent: Sendable {

    /// Human-readable name (e.g. "ForgeCoach"). Propagated into trace metadata.
    public let name: String

    /// System instructions / persona prompt for the model.
    public let instructions: String

    /// Registered tools the model may call during execution.
    public let tools: [any Tool]

    /// Primary model provider (on-device or cloud).
    public let model: ModelProvider

    /// Optional fallback provider, used when the primary fails.
    public let fallback: ModelProvider?

    /// Configuration flags that control agent behavior.
    public let configuration: AgentConfiguration?

    public init(
        name: String,
        instructions: String,
        tools: [any Tool],
        model: ModelProvider,
        fallback: ModelProvider? = nil,
        configuration: AgentConfiguration? = nil
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
    /// to the configured `fallback` provider when present. If both fail,
    /// throws ``TesseraError/fallbackFailed(primary:fallback:)`` wrapping
    /// both errors.
    public func run(_ input: String) async throws -> AgentResponse {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TesseraError.invalidInput("Input must not be empty or whitespace")
        }
        guard !tools.isEmpty else {
            throw TesseraError.noToolsRegistered
        }

        do {
            return try await runOn(provider: model, input: input)
        } catch let primaryError {
            guard let fallback else { throw primaryError }
            do {
                return try await runOn(provider: fallback, input: input)
            } catch let fallbackError {
                throw TesseraError.fallbackFailed(primary: primaryError, fallback: fallbackError)
            }
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
            return try await StubCloudRunner().run(agent: self, input: input)
        }
    }
}

/// The result of running an ``Agent``. Contains the model's text output and
/// a full ``AgentTrace`` for debugging, replay, and analytics.
public struct AgentResponse: Sendable {
    /// The model's final text response.
    public let text: String
    /// Structured trace of the entire agent run (tool calls, timing, etc.).
    public let trace: AgentTrace
}
