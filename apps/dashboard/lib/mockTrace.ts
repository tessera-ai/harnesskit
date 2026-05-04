// Canonical run data — must match SPEC.md section 3 exactly.
// Same numbers used by the Forge iOS app and the demo video.

export type TraceEvent =
  | { kind: "userInput"; atMs: number; text: string }
  | { kind: "reasoning"; atMs: number; text: string }
  | { kind: "toolCall"; atMs: number; tool: string; argsJSON: string }
  | {
      kind: "toolResult";
      atMs: number;
      durationMs: number;
      tool: string;
      resultJSON: string;
    }
  | { kind: "finalResponse"; atMs: number; text: string };

export interface EvalScore {
  groundedness: number;
  toolSelection: number;
  instructionFollowing: number;
  latencySeconds: number;
  costUsd: number;
  bytesEgressed: number;
}

export interface RunMetadata {
  runId: string;
  agentName: string;
  modelLabel: string;
  startedAt: string; // ISO8601
  totalLatencyMs: number;
  onDevice: boolean;
  bytesEgressed: number;
  costUsd: number;
}

export interface MockRun {
  meta: RunMetadata;
  input: string;
  finalText: string;
  events: TraceEvent[];
  scorecard: EvalScore;
}

const HEALTHKIT_ARGS_1 = JSON.stringify({
  metrics: ["hrv", "sleep", "restingHeartRate"],
});
const HEALTHKIT_RESULT_1 = JSON.stringify({
  hrv: 58,
  sleep: 7.2,
  restingHeartRate: 54,
});

const HEALTHKIT_ARGS_2 = JSON.stringify({
  metrics: ["activeEnergy"],
  window: "7d",
});
const HEALTHKIT_RESULT_2 = JSON.stringify({
  activeEnergy: 11200,
  window: "7d",
  deltaVsPriorPct: -8,
});

const HEALTHKIT_ARGS_3 = JSON.stringify({
  metrics: ["vo2Max"],
});
const HEALTHKIT_RESULT_3 = JSON.stringify({
  vo2Max: 47.2,
  zone2BpmRange: [130, 145],
});

const WORKOUT_ARGS = JSON.stringify({
  workout: {
    title: "Posterior chain",
    exercises: [
      { name: "Back Squat", sets: 4, reps: 5, intensity: "85%" },
      { name: "Romanian Deadlift", sets: 3, reps: 8, intensity: "70%" },
      {
        name: "Bulgarian Split Squat",
        sets: 3,
        reps: 10,
        note: "each leg",
      },
      { name: "Cooldown", durationMin: 5, note: "Zone 2" },
    ],
  },
  startTime: "18:00",
  durationMinutes: 45,
});

const WORKOUT_RESULT = JSON.stringify({
  scheduled: true,
  workoutId: "wk_a1b2c3",
});

const FINAL_TEXT =
  "Recovery is solid (72/100), load is under last week's avg. Scheduled posterior-chain at 6 PM, ~45 min — Zone-2 cooldown tuned to your VO₂.";

export const mockRun: MockRun = {
  meta: {
    runId: "run_a1b2c3d4",
    agentName: "ForgeCoach",
    modelLabel: "Apple Foundation Models · on-device",
    startedAt: "2026-05-03T17:42:11.000Z",
    totalLatencyMs: 1200,
    onDevice: true,
    bytesEgressed: 0,
    costUsd: 0,
  },
  input: "Plan my workout for today",
  finalText: FINAL_TEXT,
  events: [
    { kind: "userInput", atMs: 0, text: "Plan my workout for today" },
    {
      kind: "reasoning",
      atMs: 12,
      text: "Need recovery signals — calling HealthKit.",
    },
    {
      kind: "toolCall",
      atMs: 24,
      tool: "healthkit_read",
      argsJSON: HEALTHKIT_ARGS_1,
    },
    {
      kind: "toolResult",
      atMs: 156,
      durationMs: 132,
      tool: "healthkit_read",
      resultJSON: HEALTHKIT_RESULT_1,
    },
    {
      kind: "reasoning",
      atMs: 200,
      text: "Recovery 72/100 — push posterior chain. Check training load.",
    },
    {
      kind: "toolCall",
      atMs: 220,
      tool: "healthkit_read",
      argsJSON: HEALTHKIT_ARGS_2,
    },
    {
      kind: "toolResult",
      atMs: 320,
      durationMs: 100,
      tool: "healthkit_read",
      resultJSON: HEALTHKIT_RESULT_2,
    },
    {
      kind: "reasoning",
      atMs: 360,
      text: "Load -8% vs last week — room for intensity. Tune Zone-2 cooldown.",
    },
    {
      kind: "toolCall",
      atMs: 380,
      tool: "healthkit_read",
      argsJSON: HEALTHKIT_ARGS_3,
    },
    {
      kind: "toolResult",
      atMs: 460,
      durationMs: 80,
      tool: "healthkit_read",
      resultJSON: HEALTHKIT_RESULT_3,
    },
    {
      kind: "reasoning",
      atMs: 500,
      text: "VO₂ 47.2 — Zone-2 130-145 bpm. Generating plan.",
    },
    {
      kind: "toolCall",
      atMs: 1110,
      tool: "workoutkit_schedule",
      argsJSON: WORKOUT_ARGS,
    },
    {
      kind: "toolResult",
      atMs: 1180,
      durationMs: 70,
      tool: "workoutkit_schedule",
      resultJSON: WORKOUT_RESULT,
    },
    { kind: "finalResponse", atMs: 1200, text: FINAL_TEXT },
  ],
  scorecard: {
    groundedness: 0.94,
    toolSelection: 1.0,
    instructionFollowing: 0.91,
    latencySeconds: 1.2,
    costUsd: 0,
    bytesEgressed: 0,
  },
};

export default mockRun;
