# Tessera AI v0 SPEC

This is the contract for the v0 demo. Three implementations (Swift package, iOS app, Next.js console) must match. Do not deviate without updating this file.

The Swift module is named `Tessera`; the brand display name is "Tessera AI". The package directory is kept as `packages/HarnessKit/` for SPM stability.

## 1. Hero-shot SDK code (load-bearing — appears in the video)

```swift
import Tessera

let coach = Agent(
  name: "ForgeCoach",
  instructions: "Plan today's lift based on recovery.",
  tools: [
    HealthKit.read(.hrv, .sleep, .restingHeartRate),
    WorkoutKit.schedule
  ],
  model: .onDevice(.foundation),
  fallback: .cloud(.claude)
)

let plan = try await coach.run("Plan my workout for today")
print(plan.text)
```

## 2. SDK public API

### Agent

```swift
public struct Agent: Sendable {
  public let name: String
  public let instructions: String
  public let tools: [any Tool]
  public let model: ModelProvider
  public let fallback: ModelProvider?

  public init(
    name: String,
    instructions: String,
    tools: [any Tool],
    model: ModelProvider,
    fallback: ModelProvider? = nil
  )

  public func run(_ input: String) async throws -> AgentResponse
}

public struct AgentResponse: Sendable {
  public let text: String
  public let trace: AgentTrace
}
```

### Tool protocol

```swift
public protocol Tool: Sendable {
  var name: String { get }
  var toolDescription: String { get }
  func invokeJSON(_ argsJSON: String) async throws -> String  // JSON in, JSON out
}
```

(Internal type-safe `invoke<Args, Result>` allowed for tool implementations; the protocol uses JSON for type erasure across heterogeneous tool arrays.)

### HealthKit namespace

```swift
public enum HealthKit {
  public enum Metric: String, Sendable, CaseIterable, Codable {
    case hrv
    case sleep
    case restingHeartRate
    case activeEnergy
    case vo2Max
  }

  public static func read(_ metrics: Metric...) -> any Tool
}
```

### WorkoutKit namespace

```swift
public enum WorkoutKit {
  public static var schedule: any Tool { get }
}
```

### Models

```swift
public enum ModelProvider: Sendable {
  case onDevice(OnDeviceModel)
  case cloud(CloudModel)
}

public enum OnDeviceModel: Sendable {
  case foundation
}

public enum CloudModel: Sendable {
  case claude
  case gpt
}
```

### Trace types

```swift
public struct AgentTrace: Codable, Sendable {
  public let runId: String
  public let agentName: String
  public let modelLabel: String         // e.g. "Apple Foundation Models (on-device)"
  public let startedAt: Date
  public let totalLatencyMs: Int
  public let onDevice: Bool
  public let bytesEgressed: Int          // 0 = nothing left device
  public let events: [TraceEvent]
}

public enum TraceEvent: Codable, Sendable {
  case userInput(atMs: Int, text: String)
  case reasoning(atMs: Int, text: String)
  case toolCall(atMs: Int, tool: String, argsJSON: String)
  case toolResult(atMs: Int, durationMs: Int, tool: String, resultJSON: String)
  case finalResponse(atMs: Int, text: String)
}
```

## 3. Canonical run data (LOCK — used by Forge, console, and video)

### Input
- `"Plan my workout for today"`

### HealthKit signals (3 sequential reads — agent gathers signals it needs)

**Read 1 — recovery snapshot:**
- HRV: 58 ms
- Sleep: 7.2 hours
- Resting HR: 54 bpm
- Derived recovery score (Forge-side): 72 / 100

**Read 2 — training load:**
- Active Energy 7d: 11,200 kcal
- Δ vs prior 7d: -8% (room to push)

**Read 3 — fitness baseline:**
- VO₂ Max: 47.2 ml/kg/min
- Zone-2 target HR: 130-145 bpm

### Workout plan
- Back Squat — 4 × 5 @ 85%
- Romanian Deadlift — 3 × 8 @ 70%
- Bulgarian Split Squat — 3 × 10 each leg
- Cooldown — 5 min Zone 2

### Schedule
- Today @ 18:00, 45 minutes

### Final text
`"Recovery is solid (72/100), load is under last week's avg. Scheduled posterior-chain at 6 PM, ~45 min — Zone-2 cooldown tuned to your VO₂."`

### Trace (14 events, total ~1200ms, on-device, 0 bytes egressed)

The agent issues three sequential `healthkit_read` calls — each with a different metric subset — interleaved with reasoning that uses each signal to inform the next decision. This is the "agentic" pattern: observe → decide → next observation. The same `healthkit_read` tool (registered once) is invoked multiple times.

| # | atMs | type | summary |
|---|---|---|---|
| 1 | 0 | userInput | "Plan my workout for today" |
| 2 | 12 | reasoning | "Need recovery signals — calling HealthKit." |
| 3 | 24 | toolCall | `healthkit_read` args `{"metrics":["hrv","sleep","restingHeartRate"]}` |
| 4 | 156 | toolResult | `healthkit_read` (132ms) → `{"hrv":58,"sleep":7.2,"restingHeartRate":54}` |
| 5 | 200 | reasoning | "Recovery 72/100 — push posterior chain. Check training load." |
| 6 | 220 | toolCall | `healthkit_read` args `{"metrics":["activeEnergy"],"window":"7d"}` |
| 7 | 320 | toolResult | `healthkit_read` (100ms) → `{"activeEnergy":11200,"window":"7d","deltaVsPriorPct":-8}` |
| 8 | 360 | reasoning | "Load -8% vs last week — room for intensity. Tune Zone-2 cooldown." |
| 9 | 380 | toolCall | `healthkit_read` args `{"metrics":["vo2Max"]}` |
| 10 | 460 | toolResult | `healthkit_read` (80ms) → `{"vo2Max":47.2,"zone2BpmRange":[130,145]}` |
| 11 | 500 | reasoning | "VO₂ 47.2 — Zone-2 130-145 bpm. Generating plan." |
| 12 | 1110 | toolCall | `workoutkit_schedule` args (full plan, 18:00, 45m) |
| 13 | 1180 | toolResult | `workoutkit_schedule` (70ms) → `{"scheduled":true,"workoutId":"wk_a1b2c3"}` |
| 14 | 1200 | finalResponse | (final text above) |

### Eval scorecard
- Groundedness: 0.94
- Tool selection: 1.00
- Instruction following: 0.91
- Latency: 1.20s
- Cost: $0.00 (on-device)
- Bytes egressed: 0

### Run metadata
- runId: `run_a1b2c3d4`
- model: `Apple Foundation Models (on-device)`
- agent: `ForgeCoach`
- timestamp: now (ISO8601)

## 4. Forge iOS app spec

SwiftUI, iOS 26 simulator target. Two screens.

### HomeView
- Centered: "Forge" title (bold), "AI strength coach" subtitle.
- Primary button: "Plan today's workout"
- On tap → loading state ("Thinking on-device" pill with spinner) → call `coach.run(...)` → push PlanView on success
- Footer pill: "Powered by Tessera AI · on-device"

### PlanView
- Top: "Today's plan" + signal-chip row showing all three derived signals:
  - "Recovery 72" (filled, heart.fill icon)
  - "Load -8% / 7d" (subtle, flame.fill icon)
  - "VO₂ 47.2" (subtle, lungs.fill icon)
- List of exercises (4 rows from canonical plan)
- Big CTA: "Schedule for 6 PM"
- On tap → toast "Scheduled · 45 min" → stay on screen
- Small text: "0 bytes left your device"

### Coach.swift

Production agent — registers the full HealthKit metric set so the model can request any subset across multiple calls. The §1 hero-shot is the *minimal* example; this is what the shipping app uses.

```swift
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
```

### Visual language (Stocketa design system — light mode)
- Background: Canvas `#e0dde2` (soft warm-neutral)
- Surface: Soft Card — fill `rgba(83,116,152,0.07)`, radius 18, soft layered shadow
- Text: Graphite `#000000` primary, Slate `#9aa1b2` secondary
- Accent: Luminescent Violet `#995bb9` (headings, icons, primary CTA fill)
- Outline: Midnight Indigo `#3a4766` for ghost buttons / borders
- Font: SF Pro (system) with Stocketa-matched letter-spacing — Body 16/-0.26, Subheading 19 weight 600 / -0.32, Heading 27 weight 500 / -0.44, Display use sparingly weight 800
- Radii: 18 cards, 100 pill (buttons, tags), 22 default
- Spacing: 8 base, 16 element, 32 between groups, 40 section
- "Soft-edged transparency on cloud-white" — no heavy shadows, no saturated fills

## 5. Console (Next.js) spec

App directory: `apps/dashboard/` (npm reserved "console", so renamed). Single page (`app/page.tsx`). Local dev (`npm run dev`).

### Layout
- Top bar (h-16, transparent over Canvas, no border): wordmark "Tessera AI" left in Graphite weight 600, center pill "Forge / Production" outlined Midnight Indigo, right small avatar circle
- Left sidebar (w-56, transparent, no border): nav items as feature-list rows — Traces (active, Luminescent Violet icon), Evals, Tools, Agents, Settings
- Main column: trace detail view, max-width ~960, generous padding (40 section gap)

### Trace detail view
- Header: H1 "ForgeCoach" weight 800 Luminescent Violet (Heading LG 53/800), subhead "Plan my workout for today" Slate. Right: ghost pill buttons "Replay" "Share"
- Metadata strip in a single Soft Card (radius 18): run id, timestamp, model "Apple Foundation Models · on-device" badge, latency 1.20s, cost $0.00, "0 bytes egressed" pill
- Two-column body (gap 40):
  - Left (flex-1): vertical trace timeline rendered as soft cards or feature-list rows — each event a row with violet leading icon (Lucide), title bold, body text Slate, mono span for argsJSON
  - Right (w-80): EvalScorecard — 4 stacked Soft Cards, each with metric label (Slate caption) + value (Heading 27 weight 500 Graphite) + tiny progress bar in Luminescent Violet

### Components (in `components/`)
- `Sidebar.tsx`
- `RunMetadata.tsx`
- `TraceTimeline.tsx` (renders array of events)
- `EvalScorecard.tsx`

### Mock data
`lib/mockTrace.ts` exports a single `mockRun` matching the canonical run data above. Trace events typed.

### Tech
- Next.js 15+ (App Router) — to be scaffolded as `apps/dashboard`
- Tailwind v4 with CSS custom properties (theme tokens below)
- No shadcn. Custom Tailwind classes against the `@theme` block (Stocketa palette is too custom; shadcn would fight it).
- Lucide for icons
- Inter via `next/font/google` as Averta substitute
- Mono spans in `JetBrains Mono` or default Geist Mono for tool args

### Tailwind v4 theme (`app/globals.css`)
```css
@theme {
  --color-canvas: #e0dde2;
  --color-ash: #f0f0f0;
  --color-graphite: #000000;
  --color-slate-muted: #9aa1b2;
  --color-cloud-mist: #a5afcb;
  --color-stone-gray: #abbdcf;
  --color-blue-violet: #5b638c;
  --color-luminescent-violet: #995bb9;
  --color-indigo-outline: #3a4766;
  --color-soft-card: rgba(83, 116, 152, 0.07);

  --font-display: 'Inter', system-ui, sans-serif;

  --radius-card: 18px;
  --radius-pill: 100px;
  --radius-default: 22px;

  --shadow-soft: 0 4px 15px 0 rgba(97,110,124,0.114),
                 inset 0 1px 1px 0 rgba(255,255,255,0.39),
                 0 1px 1px 0 rgba(34,50,94,0.08);
}

body { background: var(--color-canvas); font-family: var(--font-display); letter-spacing: -0.26px; }
```

### Visual language
- Light mode only. Canvas bg, no borders unless ghost-button outline.
- Soft Card for every elevated surface — never opaque white blocks.
- Pills (100 radius) for any tag, badge, or secondary action.
- Primary CTAs: filled Luminescent Violet, white text, pill.
- Ghost buttons: Midnight Indigo 1px outline, transparent fill, pill.
- Letter-spacing matters — apply -0.26 body, -0.32 subheading, -0.44 heading.
- Sparing use of weight 800 — only main headings.

## 5b. Stocketa primitive components (write inline, no shadcn)

Each component a plain React functional component in `components/ui/`:
- `<SoftCard>` — div with `bg-soft-card rounded-card shadow-soft p-4` (translucent fill, 18 radius, soft layered shadow)
- `<Pill>` — span with `inline-flex items-center gap-1.5 rounded-pill px-3 py-1 text-caption` (variants: outline = 1px Midnight Indigo border, transparent fill; filled = Luminescent Violet bg, white text; subtle = bg-ash, graphite text)
- `<GhostButton>` — button with 1px Midnight Indigo outline, transparent fill, pill radius, py-3 px-7, weight 400 indigo text
- `<PrimaryButton>` — button with Luminescent Violet fill, white text, pill radius
- `<MetricCard>` — SoftCard variant with caption label + value Heading 27/500 + tiny progress bar

## 6. Foundation Models integration

In `Sources/HarnessKit/Models/FoundationRunner.swift`:

```swift
#if canImport(FoundationModels)
import FoundationModels
// Real implementation: LanguageModelSession with tools adapted to FM Tool protocol
#else
// Stub: returns canonical response + trace synchronously (~1200ms simulated)
#endif
```

When real:
- `LanguageModelSession(tools: [adapted...], instructions: agent.instructions)`
- `session.respond(to: input)`
- Capture tool calls into TraceEvent stream
- Adapter converts our `any Tool` into FM `Tool` (define in `FMToolAdapter.swift`)

When stubbed (fallback for builds without FM):
- Sleep 1200ms total, return canonical AgentResponse with full trace events at the canonical timings

NOTE: Xcode 26.4.1 is installed (verified) — implement the real FoundationModels path, keep the stub as a `#else` branch.

## 7. File layout (target state)

```
/Users/siowl/Projects/harnesskit/
├── README.md
├── SPEC.md                              ← this file
├── .gitignore
├── packages/HarnessKit/
│   ├── Package.swift
│   ├── Sources/HarnessKit/
│   │   ├── HarnessKit.swift
│   │   ├── Agent.swift
│   │   ├── Tools/
│   │   │   ├── Tool.swift
│   │   │   ├── HealthKit.swift
│   │   │   └── WorkoutKit.swift
│   │   ├── Models/
│   │   │   ├── ModelProvider.swift
│   │   │   ├── FoundationRunner.swift
│   │   │   └── CloudRunner.swift
│   │   ├── Trace/
│   │   │   └── Trace.swift
│   │   └── Mocks/
│   │       └── CanonicalRun.swift
│   └── Tests/HarnessKitTests/
│       └── AgentTests.swift
├── apps/Forge/                          ← iOS app (Xcode project to be generated)
│   └── Forge/
│       ├── ForgeApp.swift
│       ├── Coach.swift
│       └── Views/
│           ├── HomeView.swift
│           └── PlanView.swift
└── apps/dashboard/                      ← Next.js (scaffolded)
    ├── app/page.tsx
    ├── app/layout.tsx
    ├── components/{Sidebar,RunMetadata,TraceTimeline,EvalScorecard}.tsx
    └── lib/mockTrace.ts
```
