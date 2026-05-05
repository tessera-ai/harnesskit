<h1 align="center">Tessera</h1>

<p align="center">
  <strong>The production runtime for on-device health AI agents on Apple.</strong>
</p>

<p align="center">
  <a href="https://github.com/tessera-ai/harnesskit/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="License" /></a>
  <img src="https://img.shields.io/badge/platform-iOS%2026%2B%20%7C%20macOS%2026%2B-lightgrey" alt="Platform" />
  <img src="https://img.shields.io/badge/Swift-6.0-orange" alt="Swift" />
</p>

---

Build a consumer health AI app in an afternoon instead of two quarters.

Tessera gives you typed tool calls into HealthKit and WorkoutKit, on-device execution via Apple Foundation Models with cloud fallback, structured traces for debugging, and eval-ready observability — all through a declarative Swift API. User health data never leaves the device.

**What it solves.** iOS teams building health-AI products spend 3–6 months building the same infrastructure before shipping anything: HealthKit integration, permission plumbing, model routing, tracing, and App Store 5.1.3(i) compliance. Tessera ships those pieces as an SDK. `import Tessera`, declare your tools, ship.

## Quick start

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
// "Recovery is solid (72/100), load is under last week's avg..."
```

That's it. The agent reads HRV, sleep, and resting heart rate from HealthKit, plans a workout, schedules it via WorkoutKit, and returns the result with a full execution trace. Runs on-device by default. Falls back to Claude if Apple Intelligence is unavailable.

## How it works

```
┌─────────────┐     ┌──────────────────┐     ┌───────────────────┐
│  Your App   │────▶│  Tessera Agent   │────▶│ HealthKit /       │
│  (SwiftUI)  │◀────│  (on-device)     │◀────│ WorkoutKit tools  │
└─────────────┘     └────────┬─────────┘     └───────────────────┘
                             │
                    ┌────────▼─────────┐
                    │ Apple Foundation │     ┌──────────────┐
                    │ Models (default) │     │ Cloud Fallback│
                    │ on-device · free │     │ Claude / GPT  │
                    └──────────────────┘     └──────────────┘
```

**On-device first.** Apple Foundation Models run locally at zero marginal cost and zero data egress. If the device doesn't support it (older hardware, Apple Intelligence disabled), the SDK transparently falls back to your configured cloud provider.

**Protocol-based tools.** Every platform dependency is behind a protocol (`HealthDataProvider`, `WorkoutScheduler`). Inject mocks in tests. Use the real implementations in production.

**Structured traces.** Every `Agent.run()` returns an `AgentTrace` with typed events (tool calls, reasoning, latencies, bytes egressed). Feed them into your eval pipeline, replay harness, or dev console.

**Compliant by construction.** Tessera never stores user health data. The SDK executes on-device and returns results to your app. Zero server-side health data. This is the only architecture compliant with App Store guideline 5.1.3(i) without a privacy review dance.

## Installation

### Swift Package Manager

Add the dependency to your `Package.swift`:

```swift
dependencies: [
  .package(path: "path/to/HarnessKit")
]
```

Or via Xcode: **File → Add Package Dependencies →** point to the repo URL.

### Requirements

- Xcode 26+ (for Foundation Models SDK)
- iOS 26+ / macOS 26+ deployment target
- Swift 6.0

## Public API

### Agent

```swift
public struct Agent: Sendable {
  public init(
    name: String,
    instructions: String,
    tools: [any Tool],
    model: ModelProvider,
    fallback: ModelProvider? = nil
  )
  public func run(_ input: String) async throws -> AgentResponse
}
```

### Tools

```swift
// HealthKit — reads biometric data
HealthKit.read(.hrv, .sleep, .restingHeartRate, .activeEnergy, .vo2Max)

// WorkoutKit — schedules workouts
WorkoutKit.schedule
```

### Models

```swift
// On-device (default)
.onDevice(.foundation)

// Cloud fallback
.cloud(.claude)
.cloud(.gpt)
```

### Traces

```swift
let response: AgentResponse = try await agent.run("...")
response.trace        // AgentTrace with run metadata
response.trace.events // [TraceEvent] — typed timeline of the run
```

Every trace includes: run ID, agent name, model label, latency, bytes egressed, and a sequence of structured events (user input, reasoning, tool calls, tool results, final response).

## Testing

```bash
cd packages/HarnessKit
swift test
# 62 tests, 0 failures
```

All tools use mock providers by default, so tests run without HealthKit entitlements or Apple Intelligence.

## Examples

### Forge — AI Strength Coach

A complete iOS app in `apps/Forge/` that demonstrates:
- HealthKit permission flow
- Agent-driven workout planning
- Dynamic PlanView rendering from trace events
- Stocketa design system (SwiftUI)

### Dashboard — Dev Console

A Next.js app in `apps/dashboard/` that shows:
- Trace timeline visualization
- Eval scorecard display
- Agent run metadata

## Project structure

```
packages/HarnessKit/         Swift SDK (module: Tessera)
├── Sources/HarnessKit/
│   ├── Agent.swift           Core agent type
│   ├── TesseraError.swift    Structured error types
│   ├── AgentConfiguration.swift
│   ├── Tools/
│   │   ├── Tool.swift        Protocol definition
│   │   ├── HealthKit.swift   HealthKit namespace + tool
│   │   ├── HealthKitIntegration.swift  Live/Mock providers
│   │   ├── WorkoutKit.swift  WorkoutKit namespace + tool
│   │   └── WorkoutKitIntegration.swift Live/Mock schedulers
│   ├── Models/
│   │   ├── ModelProvider.swift
│   │   ├── FoundationRunner.swift      On-device execution
│   │   ├── CloudRunner.swift           Cloud fallback
│   │   └── FMToolAdapter.swift         Foundation Models bridge
│   ├── Trace/
│   │   └── Trace.swift       TraceEvent + AgentTrace
│   └── Mocks/
│       └── CanonicalRun.swift Deterministic fixture data
├── Tests/HarnessKitTests/    62 tests
apps/Forge/                   iOS demo app (SwiftUI)
apps/dashboard/               Dev console (Next.js)
```

## Comparison

| | Tessera | Terra API | LangChain Swift |
|---|---|---|---|
| **Execution** | On-device (Foundation Models) | Cloud API only | No built-in runner |
| **HealthKit** | Typed tool calls, direct read | Cloud proxy, data leaves device | Manual integration |
| **WorkoutKit** | Native scheduling | Not supported | Not supported |
| **Data privacy** | Zero egress by default | Data flows through cloud servers | Depends on implementation |
| **App Store compliance** | 5.1.3(i) by construction | Requires data-sharing disclosure | Manual |
| **Traces** | Built-in, structured | Not included | Manual instrumentation |

## License

MIT
