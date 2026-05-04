import Tessera

enum Coach {
    static let agent = Agent(
        name: "ForgeCoach",
        instructions: "Plan today's lift based on recovery, training load, and aerobic baseline. Gather signals progressively.",
        tools: [
            HealthKit.read(.hrv, .sleep, .restingHeartRate, .activeEnergy, .vo2Max),
            WorkoutKit.schedule
        ],
        model: .onDevice(.foundation),
        fallback: .cloud(.claude)
    )
}
