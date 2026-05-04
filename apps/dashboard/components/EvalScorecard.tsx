import { MetricCard } from "./ui/MetricCard";
import type { EvalScore } from "@/lib/mockTrace";

interface Props {
  score: EvalScore;
  /** Used to scale the latency progress bar visually. */
  latencyTargetSeconds?: number;
}

export function EvalScorecard({ score, latencyTargetSeconds = 2 }: Props) {
  const latencyProgress = Math.max(
    0,
    Math.min(1, 1 - score.latencySeconds / latencyTargetSeconds),
  );

  return (
    <div className="flex flex-col gap-3">
      <MetricCard
        label="Groundedness"
        value={score.groundedness.toFixed(2)}
        progress={score.groundedness}
      />
      <MetricCard
        label="Tool selection"
        value={score.toolSelection.toFixed(2)}
        progress={score.toolSelection}
      />
      <MetricCard
        label="Instruction following"
        value={score.instructionFollowing.toFixed(2)}
        progress={score.instructionFollowing}
      />
      <MetricCard
        label="Latency"
        value={`${score.latencySeconds.toFixed(2)}s`}
        progress={latencyProgress}
      />
    </div>
  );
}

export default EvalScorecard;
