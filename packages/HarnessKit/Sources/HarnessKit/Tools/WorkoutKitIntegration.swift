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

// MARK: - Time parsing

/// Parses a time string (e.g. "18:00") into `DateComponents`, validating
/// that hour is 0–23 and minute is 0–59. Returns `nil` for unparseable
/// or out-of-range inputs.
///
/// Extracted as a pure function for testability — the LLM-produced
/// `time` field in `argsJSON` cannot be trusted at face value.
public enum TimeParser: Sendable {
    /// Default time used when parsing fails (6 PM today).
    public static let defaultHour = 18
    public static let defaultMinute = 0

    /// Parse a \"HH:MM\" string into `DateComponents`.
    /// - Returns: `DateComponents` with hour/minute/calendar set, or `nil` if invalid.
    public static func parse(_ time: String) -> DateComponents? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        let hour = parts[0]
        let minute = parts[1]
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        var dc = DateComponents()
        dc.hour = hour
        dc.minute = minute
        dc.calendar = Calendar.current
        return dc
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
            var dateComponents =
                TimeParser.parse(time)
                ?? DateComponents(hour: TimeParser.defaultHour, minute: TimeParser.defaultMinute)
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
