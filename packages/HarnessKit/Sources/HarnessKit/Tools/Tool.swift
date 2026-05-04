import Foundation

/// Tessera's tool protocol — JSON-erased so heterogeneous tools can live
/// in a single `[any Tool]` array (SPEC §2). Implementations may add a
/// type-safe `invoke<Args, Result>` internally; the protocol contract is
/// `invokeJSON`.
public protocol Tool: Sendable {
    var name: String { get }
    var toolDescription: String { get }
    func invokeJSON(_ argsJSON: String) async throws -> String
}
