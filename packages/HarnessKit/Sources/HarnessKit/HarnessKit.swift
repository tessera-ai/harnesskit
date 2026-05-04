/// Tessera — declarative AI agents that run on-device by default.
///
/// See SPEC.md for the v0 contract. The hero-shot construction:
///
/// ```swift
/// import Tessera
///
/// let coach = Agent(
///   name: "ForgeCoach",
///   instructions: "Plan today's lift based on recovery.",
///   tools: [
///     HealthKit.read(.hrv, .sleep, .restingHeartRate),
///     WorkoutKit.schedule
///   ],
///   model: .onDevice(.foundation),
///   fallback: .cloud(.claude)
/// )
///
/// let plan = try await coach.run("Plan my workout for today")
/// print(plan.text)
/// ```
public enum TesseraInfo {
    public static let version = "0.0.1"
}
