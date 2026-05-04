import { RotateCcw, Share2 } from "lucide-react";
import { Sidebar } from "@/components/Sidebar";
import { RunMetadata } from "@/components/RunMetadata";
import { TraceTimeline } from "@/components/TraceTimeline";
import { EvalScorecard } from "@/components/EvalScorecard";
import { GhostButton } from "@/components/ui/GhostButton";
import { Pill } from "@/components/ui/Pill";
import { mockRun } from "@/lib/mockTrace";

export default function Home() {
  return (
    <div className="min-h-screen flex flex-col bg-canvas text-graphite">
      <TopBar />
      <div className="flex flex-1 px-6">
        <Sidebar />
        <main className="flex-1 max-w-[960px] mx-auto px-6 py-8 flex flex-col gap-10">
          <Header
            agentName={mockRun.meta.agentName}
            input={mockRun.input}
          />
          <RunMetadata meta={mockRun.meta} />
          <div className="flex gap-10 items-start">
            <div className="flex-1 min-w-0">
              <TraceTimeline events={mockRun.events} />
            </div>
            <div className="w-80 shrink-0">
              <EvalScorecard score={mockRun.scorecard} />
            </div>
          </div>
        </main>
      </div>
    </div>
  );
}

function TopBar() {
  return (
    <header className="h-16 px-8 flex items-center justify-between bg-transparent">
      <span className="text-[18px] font-semibold tracking-[-0.32px] text-graphite">
        Tessera AI
      </span>
      <Pill variant="outline">Forge / Production</Pill>
      <div className="h-8 w-8 rounded-full bg-soft-card shadow-soft" />
    </header>
  );
}

function Header({ agentName, input }: { agentName: string; input: string }) {
  return (
    <div className="flex items-start justify-between gap-6">
      <div className="flex flex-col gap-2">
        <h1 className="text-[53px] font-extrabold tracking-[-0.44px] leading-[1.05] text-luminescent-violet">
          {agentName}
        </h1>
        <p className="text-[19px] font-medium tracking-[-0.32px] text-slate-muted">
          {input}
        </p>
      </div>
      <div className="flex items-center gap-3 pt-3">
        <GhostButton>
          <RotateCcw size={16} strokeWidth={1.75} />
          Replay
        </GhostButton>
        <GhostButton>
          <Share2 size={16} strokeWidth={1.75} />
          Share
        </GhostButton>
      </div>
    </div>
  );
}
