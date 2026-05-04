import Foundation

/// Canonical fixture matching SPEC §3 — used by stub runner, tools, and
/// AgentTests. The same data appears in apps/dashboard/lib/mockTrace.ts
/// (Next.js console) so the demo video stays consistent across surfaces.
public enum CanonicalRun {

    // MARK: - Run identity

    public static let runId = "run_a1b2c3d4"
    public static let agentName = "ForgeCoach"
    public static let modelLabel = "Apple Foundation Models (on-device)"
    public static let totalLatencyMs = 1200
    public static let bytesEgressed = 0

    // MARK: - HealthKit snapshot

    /// JSON the canonical `healthkit_read` call returns.
    /// Matches the canonical trace event #4.
    public static let healthkitResultJSON =
        #"{"hrv":58,"sleep":7.2,"restingHeartRate":54}"#

    public static let healthkitArgsJSON =
        #"{"metrics":["hrv","sleep","restingHeartRate"]}"#

    // MARK: - Workout plan

    public struct Exercise: Codable, Sendable, Equatable {
        public let name: String
        public let detail: String
        public init(name: String, detail: String) {
            self.name = name
            self.detail = detail
        }
    }

    public static let exercises: [Exercise] = [
        .init(name: "Back Squat", detail: "4 × 5 @ 85%"),
        .init(name: "Romanian Deadlift", detail: "3 × 8 @ 70%"),
        .init(name: "Bulgarian Split Squat", detail: "3 × 10 each leg"),
        .init(name: "Cooldown", detail: "5 min Zone 2")
    ]

    public static let scheduleTime = "18:00"
    public static let scheduleDurationMin = 45

    public static let workoutkitArgsJSON =
        #"""
        {"exercises":[{"name":"Back Squat","detail":"4 × 5 @ 85%"},{"name":"Romanian Deadlift","detail":"3 × 8 @ 70%"},{"name":"Bulgarian Split Squat","detail":"3 × 10 each leg"},{"name":"Cooldown","detail":"5 min Zone 2"}],"time":"18:00","durationMin":45}
        """#

    public static let workoutkitResultJSON =
        #"{"scheduled":true,"workoutId":"wk_a1b2c3"}"#

    // MARK: - Final text

    public static let finalText =
        "Recovery is solid (72/100). I scheduled a posterior-chain session at 6 PM, ~45 min."

    // MARK: - Trace

    /// Canonical 8-event trace per SPEC §3 timing table.
    public static func makeEvents() -> [TraceEvent] {
        [
            .userInput(atMs: 0, text: "Plan my workout for today"),
            .reasoning(atMs: 12, text: "Need recovery signals — calling HealthKit."),
            .toolCall(atMs: 24, tool: "healthkit_read", argsJSON: healthkitArgsJSON),
            .toolResult(
                atMs: 156,
                durationMs: 132,
                tool: "healthkit_read",
                resultJSON: healthkitResultJSON
            ),
            .reasoning(atMs: 200, text: "Recovery looks good. Plan posterior-chain session."),
            .toolCall(atMs: 1110, tool: "workoutkit_schedule", argsJSON: workoutkitArgsJSON),
            .toolResult(
                atMs: 1180,
                durationMs: 70,
                tool: "workoutkit_schedule",
                resultJSON: workoutkitResultJSON
            ),
            .finalResponse(atMs: 1200, text: finalText)
        ]
    }

    /// Canonical AgentTrace fixture, parameterized so a real run can
    /// substitute its own `runId` / `startedAt` / model label without
    /// reshaping events.
    public static func makeTrace(
        runId: String = runId,
        agentName: String = agentName,
        modelLabel: String = modelLabel,
        startedAt: Date = Date(),
        onDevice: Bool = true,
        bytesEgressed: Int = bytesEgressed
    ) -> AgentTrace {
        AgentTrace(
            runId: runId,
            agentName: agentName,
            modelLabel: modelLabel,
            startedAt: startedAt,
            totalLatencyMs: totalLatencyMs,
            onDevice: onDevice,
            bytesEgressed: bytesEgressed,
            events: makeEvents()
        )
    }

    public static func makeResponse(
        agentName: String = agentName,
        modelLabel: String = modelLabel,
        startedAt: Date = Date(),
        onDevice: Bool = true
    ) -> AgentResponse {
        AgentResponse(
            text: finalText,
            trace: makeTrace(
                agentName: agentName,
                modelLabel: modelLabel,
                startedAt: startedAt,
                onDevice: onDevice
            )
        )
    }
}
