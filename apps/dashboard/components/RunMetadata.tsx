import { Cpu, Clock, DollarSign, ShieldCheck, Hash } from "lucide-react";
import { SoftCard } from "./ui/SoftCard";
import { Pill } from "./ui/Pill";
import type { RunMetadata as RunMeta } from "@/lib/mockTrace";

interface Props {
  meta: RunMeta;
}

function formatTimestamp(iso: string): string {
  try {
    const d = new Date(iso);
    return d.toLocaleString(undefined, {
      month: "short",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit",
    });
  } catch {
    return iso;
  }
}

export function RunMetadata({ meta }: Props) {
  const latencySec = (meta.totalLatencyMs / 1000).toFixed(2);

  return (
    <SoftCard className="px-5 py-4">
      <div className="flex flex-wrap items-center gap-2">
        <Pill variant="subtle" className="font-mono">
          <Hash size={12} strokeWidth={2} className="text-slate-muted" />
          {meta.runId}
        </Pill>
        <Pill variant="subtle">
          <Clock size={12} strokeWidth={2} className="text-slate-muted" />
          {formatTimestamp(meta.startedAt)}
        </Pill>
        <Pill variant="outline">
          <Cpu size={12} strokeWidth={2} />
          {meta.modelLabel}
        </Pill>
        <Pill variant="subtle">
          <Clock size={12} strokeWidth={2} className="text-slate-muted" />
          {latencySec}s
        </Pill>
        <Pill variant="subtle">
          <DollarSign size={12} strokeWidth={2} className="text-slate-muted" />
          ${meta.costUsd.toFixed(2)}
        </Pill>
        <Pill variant="filled">
          <ShieldCheck size={12} strokeWidth={2} />
          {meta.bytesEgressed} bytes egressed
        </Pill>
      </div>
    </SoftCard>
  );
}

export default RunMetadata;
