import Foundation

// MARK: - ScheduledWorkout

/// Result of scheduling a workout through Apple's WorkoutKit framework.
public struct ScheduledWorkout: Sendable, Codable {
    public let scheduled: Bool
    public let workoutId: String

    public init(scheduled: Bool, workoutId: String) {
        self.scheduled = scheduled
        self.workoutId = workoutId
    }
}

// MARK: - WorkoutScheduler protocol

/// Abstracts workout scheduling so tests can inject a mock and the live
/// app uses Apple's WorkoutKit framework.
public protocol WorkoutScheduler: Sendable {
    func schedule(
        exercises: [CanonicalRun.Exercise],
        time: String,
        durationMin: Int
    ) async throws -> ScheduledWorkout
}

// MARK: - MockWorkoutScheduler

/// Returns the canonical fixture — keeps tests deterministic and backward-
/// compatible with the demo trace.
struct MockWorkoutScheduler: WorkoutScheduler {
    func schedule(
        exercises: [CanonicalRun.Exercise],
        time: String,
        durationMin: Int
    ) async throws -> ScheduledWorkout {
        ScheduledWorkout(scheduled: true, workoutId: "wk_a1b2c3")
    }
}

// MARK: - LiveWorkoutScheduler (Apple WorkoutKit, iOS only)

#if canImport(WorkoutKit) && !os(macOS)
import WorkoutKit

/// Thin wrapper around Apple's WorkoutKit scheduler. Uses fully-qualified
/// type names to avoid collisions with our own ``WorkoutKit`` namespace enum.
struct LiveWorkoutScheduler: WorkoutScheduler {
    func schedule(
        exercises: [CanonicalRun.Exercise],
        time: String,
        durationMin: Int
    ) async throws -> ScheduledWorkout {
        // Build a workout plan from exercises.
        // Each exercise maps to a WorkoutStep in a single WorkoutPlan.
        let steps: [WorkoutStep] = exercises.map { exercise in
            WorkoutStep(.custom(
                name: exercise.name,
                detail: exercise.detail
            ))
        }

        let plan: WorkoutPlan
        if steps.count == 1 {
            plan = WorkoutPlan(steps[0])
        } else {
            plan = WorkoutPlan(steps)
        }

        // Schedule via Apple's default scheduler.
        let appleScheduler = AppleWorkoutScheduler.default
        let scheduledPlan = try await appleScheduler.schedule(plan)

        return ScheduledWorkout(
            scheduled: true,
            workoutId: scheduledPlan.id.uuidString
        )
    }
}

/// Type alias to disambiguate Apple's WorkoutKit.WorkoutScheduler from
/// our ``WorkoutScheduler`` protocol.
private typealias AppleWorkoutScheduler = WorkoutKit.WorkoutScheduler
#endif
