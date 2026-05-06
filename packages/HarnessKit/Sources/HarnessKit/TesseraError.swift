import Foundation

/// Structured errors thrown by Tessera's public API.
///
/// Callers can switch on these to present domain-specific UI or decide
/// whether to retry. Every `Agent.run()` failure that isn't a programmer
/// error surfaces as one of these cases.
public enum TesseraError: Error, Sendable {

    /// The requested model is not usable on this device / OS / configuration.
    ///
    /// - Parameters:
    ///   - reason: Human-readable explanation (e.g. "Apple Intelligence not
    ///     enabled on this device").
    case modelUnavailable(reason: String)

    /// A registered tool threw during invocation.
    ///
    /// - Parameters:
    ///   - tool: The `Tool.name` that failed.
    ///   - underlying: The error the tool implementation threw.
    case toolError(tool: String, underlying: Error)

    /// Both the primary model and the fallback model failed.
    ///
    /// Agent.run() attempts the primary `model`; if that throws and a
    /// `fallback` is configured, it tries the fallback. If *both* fail,
    /// this case wraps both errors so the caller can inspect either.
    case fallbackFailed(primary: Error, fallback: Error)

    /// The agent was constructed with zero tools but the model needs at
    /// least one to produce a useful response.
    case noToolsRegistered

    /// The caller-supplied input is empty or otherwise invalid.
    case invalidInput(String)
}

// MARK: - LocalizedError

extension TesseraError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .modelUnavailable(let reason):
            "Model unavailable: \(reason)"
        case .toolError(let tool, let underlying):
            "Tool \"\(tool)\" failed: \(underlying.localizedDescription)"
        case .fallbackFailed(let primary, let fallback):
            "Both providers failed. Primary: \(primary.localizedDescription). Fallback: \(fallback.localizedDescription)"
        case .noToolsRegistered:
            "Agent has no tools registered."
        case .invalidInput(let detail):
            "Invalid input: \(detail)"
        }
    }
}

// MARK: - CustomStringConvertible

extension TesseraError: CustomStringConvertible {

    public var description: String {
        errorDescription ?? "Unknown TesseraError"
    }
}

// MARK: - Equatable (tests need to compare specific cases)

extension TesseraError: Equatable {

    /// Equality comparison for tests. Compares case + associated values.
    /// `Error` doesn't conform to `Equatable`, so underlying errors are
    /// compared by their `localizedDescription` strings.
    public static func == (lhs: TesseraError, rhs: TesseraError) -> Bool {
        switch (lhs, rhs) {
        case (.modelUnavailable(let a), .modelUnavailable(let b)):
            a == b
        case (.toolError(let tA, let eA), .toolError(let tB, let eB)):
            tA == tB && eA.localizedDescription == eB.localizedDescription
        case (.fallbackFailed(let pA, let fA), .fallbackFailed(let pB, let fB)):
            pA.localizedDescription == pB.localizedDescription
                && fA.localizedDescription == fB.localizedDescription
        case (.noToolsRegistered, .noToolsRegistered):
            true
        case (.invalidInput(let a), .invalidInput(let b)):
            a == b
        default:
            false
        }
    }
}
