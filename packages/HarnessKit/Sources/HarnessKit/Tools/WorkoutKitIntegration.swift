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

// MARK: - WorkoutScheduling protocol

/// Abstracts workout scheduling so tests can inject a mock and the live
/// app uses Apple's WorkoutKit framework.
public protocol WorkoutScheduling: Sendable {
    func schedule(
        exercises: [CanonicalRun.Exercise],
        time: String,
        durationMin: Int
    ) async throws -> ScheduledWorkout
}

// MARK: - MockWorkoutScheduler

/// Returns the canonical fixture — keeps tests deterministic and backward-
/// compatible with the demo trace.
public struct MockWorkoutScheduler: WorkoutScheduling {
    public init() {}

    public func schedule(
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

    /// Thin wrapper around Apple's WorkoutKit scheduler.
    ///
    /// Maps HarnessKit exercises into a `CustomWorkout` wrapped in a
    /// `WorkoutPlan`, then schedules via Apple's `WorkoutScheduler.shared`.
    public struct LiveWorkoutScheduler: WorkoutScheduling {
        public init() {}

        public func schedule(
            exercises: [CanonicalRun.Exercise],
            time: String,
            durationMin: Int
        ) async throws -> ScheduledWorkout {
            // Build a custom workout from our exercise list.
            // Map each exercise into a workout block with a time-based goal.
            let minutesPer = Double(durationMin) / Double(max(exercises.count, 1))
            let blocks = exercises.map { exercise -> IntervalBlock in
                self.makeBlock(exercise: exercise, minutesPer: minutesPer)
            }

            let customWorkout = CustomWorkout(
                activity: .traditionalStrengthTraining,
                location: .indoor,
                displayName: "Forge Strength",
                warmup: nil,
                blocks: blocks,
                cooldown: nil
            )

            let plan = WorkoutPlan(.custom(customWorkout))

            // Parse time string (e.g. "18:00") into DateComponents.
            let timeParts = time.split(separator: ":").compactMap { Int($0) }
            var dateComponents = DateComponents()
            if timeParts.count >= 2 {
                dateComponents.hour = timeParts[0]
                dateComponents.minute = timeParts[1]
            } else {
                // Default to 6 PM today.
                dateComponents.hour = 18
                dateComponents.minute = 0
            }
            dateComponents.calendar = Calendar.current

            try await WorkoutScheduler.shared.schedule(plan, at: dateComponents)

            // schedule(_:at:) returns Void on success. Use the plan's id.
            return ScheduledWorkout(
                scheduled: true,
                workoutId: plan.id.uuidString
            )
        }

        private func makeBlock(
            exercise: CanonicalRun.Exercise,
            minutesPer: Double
        ) -> IntervalBlock {
            let step = WorkoutStep(
                goal: .time(minutesPer, .minutes)
            )
            let intervalStep = IntervalStep(.work, step: step)
            return IntervalBlock(
                steps: [intervalStep],
                iterations: 1
            )
        }
    }
#endif
