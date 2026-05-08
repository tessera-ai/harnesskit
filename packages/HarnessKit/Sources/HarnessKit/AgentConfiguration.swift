import Foundation

/// Configuration options that control agent runtime behavior.
///
/// Use this to force the canonical stub path even when real platform
/// APIs are available, for deterministic testing or demo modes.
public struct AgentConfiguration: Sendable {
    /// When `true`, the agent skips real Foundation Models calls and
    /// returns the canonical stub response (SPEC §3) immediately.
    /// When `false` (default), the agent attempts real on-device inference
    /// when available.
    public var useCanonicalFixture: Bool

    public init(useCanonicalFixture: Bool = false) {
        self.useCanonicalFixture = useCanonicalFixture
    }
}
