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
    private let scheduler: WorkoutScheduler

    init(scheduler: WorkoutScheduler = MockWorkoutScheduler()) {
        self.scheduler = scheduler
    }

    var name: String { "workoutkit_schedule" }
    var toolDescription: String {
        "Schedule a strength workout in the user's calendar (mocked for demo)."
    }

    func invokeJSON(_ argsJSON: String) async throws -> String {
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
