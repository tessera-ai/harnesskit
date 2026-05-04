import Foundation

/// Tessera-branded WorkoutKit namespace. Does NOT import the real
/// Apple WorkoutKit framework — entitlement risk on a fresh demo build.
public enum WorkoutKit {
    /// Hero-shot signature: `WorkoutKit.schedule` (computed property,
    /// no parens). Returns a canned scheduling tool.
    public static var schedule: any Tool {
        WorkoutKitScheduleTool()
    }
}

struct WorkoutKitScheduleTool: Tool {
    var name: String { "workoutkit_schedule" }
    var toolDescription: String {
        "Schedule a strength workout in the user's calendar (mocked for demo)."
    }

    func invokeJSON(_ argsJSON: String) async throws -> String {
        // Mocked — returns the canonical scheduling response.
        return CanonicalRun.workoutkitResultJSON
    }
}
