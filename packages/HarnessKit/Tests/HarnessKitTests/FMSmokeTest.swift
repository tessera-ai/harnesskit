// Smoke test: verify the FoundationModels SDK shape we plan to depend on
// actually compiles against the iOS 26.4 SDK. We do NOT assert that the
// model is *available* at runtime (simulator typically lacks Apple
// Intelligence) — just that the API surface matches our assumptions:
//   - `Tool` protocol with `Arguments: Generable`, `Output: PromptRepresentable`
//   - `@Generable` macro on a struct
//   - `LanguageModelSession(model:tools:instructions:)` initializer
//   - `session.respond(to: String)` returning `Response<String>`

#if canImport(FoundationModels) && !os(macOS)
import FoundationModels
import XCTest

@available(iOS 26.0, macOS 26.0, *)
@Generable
struct FMSmokeArgs {
    @Guide(description: "Anything")
    var query: String
}

@available(iOS 26.0, macOS 26.0, *)
struct FMSmokeTool: Tool {
    typealias Arguments = FMSmokeArgs
    typealias Output = String

    var name: String { "smoke_echo" }
    var description: String { "Echoes the input query back." }

    func call(arguments: FMSmokeArgs) async throws -> String {
        return "echo:\(arguments.query)"
    }
}

@available(iOS 26.0, macOS 26.0, *)
final class FMSmokeTest: XCTestCase {
    // This test is compile-only. Running it on simulator will likely throw
    // because Apple Intelligence is unavailable in the simulator runtime.
    func testCompilesAgainstFMTypes() async throws {
        // Build a session with our tool. If this compiles, the FM Tool
        // protocol shape we're targeting in FoundationRunner is correct.
        let tool = FMSmokeTool()
        let session = LanguageModelSession(
            tools: [tool],
            instructions: "Smoke test."
        )
        // Touch the API but don't fail the test if the model is unavailable.
        do {
            let response = try await session.respond(to: "test")
            _ = response.content
        } catch {
            // Expected on simulator without AI assets — we only care about compile.
            print("FMSmokeTest: respond threw (expected on sim): \(error)")
        }
    }
}
#endif
