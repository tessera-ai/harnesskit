import { SoftCard } from "./SoftCard";

interface MetricCardProps {
  label: string;
  value: string;
  /** 0-1 for the progress bar fill. */
  progress?: number;
  className?: string;
}

export function MetricCard({
  label,
  value,
  progress,
  className = "",
}: MetricCardProps) {
  const clamped =
    typeof progress === "number"
      ? Math.max(0, Math.min(1, progress))
      : undefined;

  return (
    <SoftCard className={`flex flex-col gap-3 ${className}`}>
      <span className="text-[14px] tracking-[-0.21px] text-slate-muted leading-none">
        {label}
      </span>
      <span className="text-[27px] font-medium tracking-[-0.44px] text-graphite leading-tight">
        {value}
      </span>
      {clamped !== undefined && (
        <div className="h-1 w-full rounded-pill bg-soft-card overflow-hidden">
          <div
            className="h-full rounded-pill bg-luminescent-violet"
            style={{ width: `${clamped * 100}%` }}
          />
        </div>
      )}
    </SoftCard>
  );
}

export default MetricCard;
