import Foundation

public struct AgentTrace: Codable, Sendable {
    public let runId: String
    public let agentName: String
    public let modelLabel: String
    public let startedAt: Date
    public let totalLatencyMs: Int
    public let onDevice: Bool
    public let bytesEgressed: Int
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

public enum TraceEvent: Codable, Sendable {
    case userInput(atMs: Int, text: String)
    case reasoning(atMs: Int, text: String)
    case toolCall(atMs: Int, tool: String, argsJSON: String)
    case toolResult(atMs: Int, durationMs: Int, tool: String, resultJSON: String)
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
