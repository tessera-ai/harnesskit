import Foundation

/// A structured, replayable record of every event that occurred during a
/// single ``Agent`` run. Codable for persistence and cross-platform transport.
public struct AgentTrace: Codable, Sendable {
    /// Unique identifier for this run.
    public let runId: String
    /// The ``Agent`` name that produced this trace.
    public let agentName: String
    /// Human-readable model label (e.g. "Apple Foundation Models (on-device)").
    public let modelLabel: String
    /// Timestamp when the run started.
    public let startedAt: Date
    /// Total wall-clock latency in milliseconds.
    public let totalLatencyMs: Int
    /// Whether the run executed on-device (no cloud round-trip).
    public let onDevice: Bool
    /// Network bytes sent during the run (0 for on-device).
    public let bytesEgressed: Int
    /// Ordered sequence of events during the run.
    public let events: [TraceEvent]

    public init(
        runId: String,
        agentName: String,
        modelLabel: String,
        startedAt: Date,
        totalLatencyMs: Int,
        onDevice: Bool,
        bytesEgressed: Int,
        events: [TraceEvent]
    ) {
        self.runId = runId
        self.agentName = agentName
        self.modelLabel = modelLabel
        self.startedAt = startedAt
        self.totalLatencyMs = totalLatencyMs
        self.onDevice = onDevice
        self.bytesEgressed = bytesEgressed
        self.events = events
    }
}

/// A single event in an ``AgentTrace``. Discriminated union with explicit
/// `kind` coding key for stable JSON serialization across platforms.
public enum TraceEvent: Codable, Sendable {
    /// The user's initial prompt text.
    case userInput(atMs: Int, text: String)
    /// Intermediate model reasoning / chain-of-thought.
    case reasoning(atMs: Int, text: String)
    /// A tool invocation request from the model.
    case toolCall(atMs: Int, tool: String, argsJSON: String)
    /// The result returned by a tool invocation.
    case toolResult(atMs: Int, durationMs: Int, tool: String, resultJSON: String)
    /// The model's final text response.
    case finalResponse(atMs: Int, text: String)

    // MARK: - Codable (discriminated by `kind`)

    private enum CodingKeys: String, CodingKey {
        case kind, atMs, text, tool, argsJSON, resultJSON, durationMs
    }

    private enum Kind: String, Codable {
        case userInput, reasoning, toolCall, toolResult, finalResponse
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .userInput(let atMs, let text):
            try c.encode(Kind.userInput, forKey: .kind)
            try c.encode(atMs, forKey: .atMs)
            try c.encode(text, forKey: .text)
        case .reasoning(let atMs, let text):
            try c.encode(Kind.reasoning, forKey: .kind)
            try c.encode(atMs, forKey: .atMs)
            try c.encode(text, forKey: .text)
        case .toolCall(let atMs, let tool, let argsJSON):
            try c.encode(Kind.toolCall, forKey: .kind)
            try c.encode(atMs, forKey: .atMs)
            try c.encode(tool, forKey: .tool)
            try c.encode(argsJSON, forKey: .argsJSON)
        case .toolResult(let atMs, let durationMs, let tool, let resultJSON):
            try c.encode(Kind.toolResult, forKey: .kind)
            try c.encode(atMs, forKey: .atMs)
            try c.encode(durationMs, forKey: .durationMs)
            try c.encode(tool, forKey: .tool)
            try c.encode(resultJSON, forKey: .resultJSON)
        case .finalResponse(let atMs, let text):
            try c.encode(Kind.finalResponse, forKey: .kind)
            try c.encode(atMs, forKey: .atMs)
            try c.encode(text, forKey: .text)
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        let atMs = try c.decode(Int.self, forKey: .atMs)
        switch kind {
        case .userInput:
            self = .userInput(atMs: atMs, text: try c.decode(String.self, forKey: .text))
        case .reasoning:
            self = .reasoning(atMs: atMs, text: try c.decode(String.self, forKey: .text))
        case .toolCall:
            self = .toolCall(
                atMs: atMs,
                tool: try c.decode(String.self, forKey: .tool),
                argsJSON: try c.decode(String.self, forKey: .argsJSON)
            )
        case .toolResult:
            self = .toolResult(
                atMs: atMs,
                durationMs: try c.decode(Int.self, forKey: .durationMs),
                tool: try c.decode(String.self, forKey: .tool),
                resultJSON: try c.decode(String.self, forKey: .resultJSON)
            )
        case .finalResponse:
            self = .finalResponse(atMs: atMs, text: try c.decode(String.self, forKey: .text))
        }
    }
}
