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

    // MARK: - HealthKit signals (3 sequential reads — see SPEC §3)

    /// Read 1 — recovery snapshot. The default result the
    /// HealthKitReadTool stub returns for any single-call invocation.
    public static let healthkitArgs1JSON =
        #"{"metrics":["hrv","sleep","restingHeartRate"]}"#
    public static let healthkitResult1JSON =
        #"{"hrv":58,"sleep":7.2,"restingHeartRate":54}"#

    /// Read 2 — training load over the last 7 days.
    public static let healthkitArgs2JSON =
        #"{"metrics":["activeEnergy"],"window":"7d"}"#
    public static let healthkitResult2JSON =
        #"{"activeEnergy":11200,"window":"7d","deltaVsPriorPct":-8}"#

    /// Read 3 — fitness baseline (VO₂ Max + Zone-2 target HR).
    public static let healthkitArgs3JSON =
        #"{"metrics":["vo2Max"]}"#
    public static let healthkitResult3JSON =
        #"{"vo2Max":47.2,"zone2BpmRange":[130,145]}"#

    /// Aliases retained for the HealthKitReadTool stub and existing tests.
    /// Point at Read 1 (recovery snapshot) — the most common single-call shape.
    public static let healthkitArgsJSON = healthkitArgs1JSON
    public static let healthkitResultJSON = healthkitResult1JSON

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
        "Recovery is solid (72/100), load is under last week's avg. Scheduled posterior-chain at 6 PM, ~45 min — Zone-2 cooldown tuned to your VO₂."

    // MARK: - Trace

    /// Canonical 14-event trace per SPEC §3 timing table.
    /// Three sequential `healthkit_read` calls (recovery, training load, VO₂)
    /// interleaved with reasoning, then `workoutkit_schedule`, then final text.
    public static func makeEvents() -> [TraceEvent] {
        [
            .userInput(atMs: 0, text: "Plan my workout for today"),
            .reasoning(atMs: 12, text: "Need recovery signals — calling HealthKit."),
            .toolCall(atMs: 24, tool: "healthkit_read", argsJSON: healthkitArgs1JSON),
            .toolResult(
                atMs: 156,
                durationMs: 132,
                tool: "healthkit_read",
                resultJSON: healthkitResult1JSON
            ),
            .reasoning(atMs: 200, text: "Recovery 72/100 — push posterior chain. Check training load."),
            .toolCall(atMs: 220, tool: "healthkit_read", argsJSON: healthkitArgs2JSON),
            .toolResult(
                atMs: 320,
                durationMs: 100,
                tool: "healthkit_read",
                resultJSON: healthkitResult2JSON
            ),
            .reasoning(atMs: 360, text: "Load -8% vs last week — room for intensity. Tune Zone-2 cooldown."),
            .toolCall(atMs: 380, tool: "healthkit_read", argsJSON: healthkitArgs3JSON),
            .toolResult(
                atMs: 460,
                durationMs: 80,
                tool: "healthkit_read",
                resultJSON: healthkitResult3JSON
            ),
            .reasoning(atMs: 500, text: "VO₂ 47.2 — Zone-2 130-145 bpm. Generating plan."),
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
