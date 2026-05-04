import {
  MessageSquare,
  Brain,
  Wrench,
  CheckCircle2,
  Sparkles,
  LucideIcon,
} from "lucide-react";
import { SoftCard } from "./ui/SoftCard";
import type { TraceEvent } from "@/lib/mockTrace";

interface Props {
  events: TraceEvent[];
}

interface RowMeta {
  Icon: LucideIcon;
  title: string;
  body: string;
  mono?: string;
  monoLabel?: string;
}

function describe(event: TraceEvent): RowMeta {
  switch (event.kind) {
    case "userInput":
      return {
        Icon: MessageSquare,
        title: "User input",
        body: event.text,
      };
    case "reasoning":
      return {
        Icon: Brain,
        title: "Reasoning",
        body: event.text,
      };
    case "toolCall":
      return {
        Icon: Wrench,
        title: `Tool call · ${event.tool}`,
        body: "Agent invoked tool with arguments.",
        mono: prettyJson(event.argsJSON),
        monoLabel: "args",
      };
    case "toolResult":
      return {
        Icon: CheckCircle2,
        title: `Tool result · ${event.tool}`,
        body: `Returned in ${event.durationMs}ms.`,
        mono: prettyJson(event.resultJSON),
        monoLabel: "result",
      };
    case "finalResponse":
      return {
        Icon: Sparkles,
        title: "Final response",
        body: event.text,
      };
  }
}

function prettyJson(raw: string): string {
  try {
    return JSON.stringify(JSON.parse(raw), null, 2);
  } catch {
    return raw;
  }
}

function formatAt(ms: number): string {
  if (ms < 1000) return `${ms}ms`;
  return `${(ms / 1000).toFixed(2)}s`;
}

export function TraceTimeline({ events }: Props) {
  return (
    <ol className="flex flex-col gap-3">
      {events.map((event, idx) => {
        const { Icon, title, body, mono, monoLabel } = describe(event);
        return (
          <li key={idx}>
            <SoftCard className="flex gap-4 px-5 py-4">
              <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-default bg-luminescent-violet/12 text-luminescent-violet">
                <Icon size={16} strokeWidth={1.75} />
              </div>
              <div className="flex flex-1 flex-col gap-2 min-w-0">
                <div className="flex items-baseline justify-between gap-3">
                  <span className="text-[15px] font-semibold tracking-[-0.26px] text-graphite">
                    {title}
                  </span>
                  <span className="font-mono text-[12px] tracking-[-0.18px] text-slate-muted">
                    {formatAt(event.atMs)}
                  </span>
                </div>
                <p className="text-[15px] tracking-[-0.26px] text-slate-muted">
                  {body}
                </p>
                {mono && (
                  <div className="rounded-default bg-soft-card px-3 py-2.5">
                    {monoLabel && (
                      <div className="mb-1 text-[11px] uppercase tracking-[0.08em] text-slate-muted">
                        {monoLabel}
                      </div>
                    )}
                    <pre className="font-mono text-[12px] leading-relaxed text-graphite whitespace-pre-wrap break-words">
                      {mono}
                    </pre>
                  </div>
                )}
              </div>
            </SoftCard>
          </li>
        );
      })}
    </ol>
  );
}

export default TraceTimeline;
