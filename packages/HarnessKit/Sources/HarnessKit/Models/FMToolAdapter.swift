import Foundation

#if canImport(FoundationModels)
    import FoundationModels

    /// @Generable struct used as the adapter's Arguments type. FoundationModels
    /// requires Arguments to conform to `Generable`, and primitive Strings are
    /// explicitly unsupported — so we wrap the JSON payload in a single-field
    /// struct. The adapter forwards the JSON to our `Tool.invokeJSON`.
    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct FMToolArgs {
        @Guide(description: "JSON-encoded arguments for the tool.")
        var argsJSON: String
    }

    /// Adapts a Tessera `Tool` to a `FoundationModels.Tool`. The adapter
    /// stays JSON-erased on the inside (matching our protocol contract) and
    /// uses the `argsJSON` field to thread payloads through the Generable
    /// schema FM expects. SPEC §6.
    @available(iOS 26.0, macOS 26.0, *)
    struct FMToolAdapter: FoundationModels.Tool {
        typealias Arguments = FMToolArgs
        typealias Output = String

        let wrapped: any Tessera.Tool

        var name: String { wrapped.name }
        var description: String { wrapped.toolDescription }

        func call(arguments: FMToolArgs) async throws -> String {
            try await wrapped.invokeJSON(arguments.argsJSON)
        }
    }

#endif
