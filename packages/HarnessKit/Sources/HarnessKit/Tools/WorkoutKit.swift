import Foundation

/// Tessera-branded WorkoutKit namespace. Does NOT import the real
/// Apple WorkoutKit framework — entitlement risk on a fresh demo build.
public enum WorkoutKit {
    /// Hero-shot signature: `WorkoutKit.schedule` (computed property,
    /// no parens). Uses ``LiveWorkoutScheduler`` on iOS, mock on macOS.
    public static var schedule: any Tool {
        WorkoutKitScheduleTool(scheduler: resolveScheduler())
    }

    /// Factory with explicit scheduler for dependency injection.
    public static func schedule(
        scheduler: WorkoutScheduling
    ) -> any Tool {
        WorkoutKitScheduleTool(scheduler: scheduler)
    }

    /// Returns the live scheduler on iOS, mock on macOS.
    private static func resolveScheduler() -> WorkoutScheduling {
        #if canImport(WorkoutKit) && !os(macOS)
            return LiveWorkoutScheduler()
        #else
            return MockWorkoutScheduler()
        #endif
    }
}

public struct WorkoutKitScheduleTool: Tool {
    private let scheduler: WorkoutScheduling

    public init(scheduler: WorkoutScheduling = MockWorkoutScheduler()) {
        self.scheduler = scheduler
    }

    public var name: String { "workoutkit_schedule" }
    public var toolDescription: String {
        "Schedule a strength workout in the user's calendar."
    }

    public func invokeJSON(_ argsJSON: String) async throws -> String {
        struct Args: Decodable {
            let exercises: [CanonicalRun.Exercise]
            let time: String
            let durationMin: Int
        }
        let data = Data(argsJSON.utf8)
        let decoder = JSONDecoder()
        let args = try decoder.decode(Args.self, from: data)
        let result = try await scheduler.schedule(
            exercises: args.exercises,
            time: args.time,
            durationMin: args.durationMin
        )
        let encoded = try JSONEncoder().encode(result)
        return String(decoding: encoded, as: UTF8.self)
    }
}
