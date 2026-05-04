import Tessera

enum Coach {
    static let agent = Agent(
        name: "ForgeCoach",
        instructions: "Plan today's lift based on recovery.",
        tools: [
            HealthKit.read(.hrv, .sleep, .restingHeartRate),
            WorkoutKit.schedule
        ],
        model: .onDevice(.foundation),
        fallback: .cloud(.claude)
    )
}
