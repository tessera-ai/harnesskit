# Tessera (HarnessKit)

Declarative AI agents that run on-device by default, with optional cloud fallback.

The Swift Package is named **Tessera** (`import Tessera`) but lives in the `packages/HarnessKit/` directory. This split is intentional: "HarnessKit" is the development directory name, while "Tessera" is the public module identity consumed by apps.

## Requirements

- Swift 6.0+
- Xcode 26+ (beta)
- iOS 26+ / macOS 26+

**Platform notes:**
- **iOS 26+**: Full functionality including Apple Foundation Models (on-device inference) and HealthKit.
- **macOS 26+**: Foundation Models are not available on macOS. The SDK compiles and runs correctly but automatically falls back to the canonical stub path for on-device model requests. Cloud model execution works on all platforms.
- HealthKit and WorkoutKit integrations are iOS-only (guarded by `canImport`).

## Build & Test

```bash
swift build
swift test
```

Tests run on macOS via the stub path (no Apple Intelligence required). All 26 tests should pass.

## Quick Start

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

let response = try await coach.run("Plan my workout for today")
print(response.text)   // The model's final answer
print(response.trace)  // Full structured trace of the run
```

## Architecture

### Core Types

| Type | Description |
|------|-------------|
| `Agent` | Declarative agent descriptor with tools, model, and optional fallback |
| `AgentResponse` | Result of a run: text + structured trace |
| `AgentTrace` | Codable, replayable event log of a run |
| `TraceEvent` | Discriminated union: userInput, reasoning, toolCall, toolResult, finalResponse |
| `ModelProvider` | `.onDevice(.foundation)` or `.cloud(.claude)` / `.cloud(.gpt)` |
| `AgentConfiguration` | Runtime flags (e.g. force stub path for testing) |
| `TesseraError` | Typed errors: modelUnavailable, toolError, fallbackFailed, etc. |

### Tool Protocols

| Protocol | Description |
|----------|-------------|
| `Tool` | Base protocol: `invokeJSON(_:String) async throws -> String` |
| `HealthDataProvider` | Abstract HealthKit data access; inject mocks in tests |
| `WorkoutScheduler` | Abstract workout scheduling; inject mocks in tests |
| `CloudModelRunner` | Abstract cloud model execution; inject stubs or real clients |

### Namespaces

- **`HealthKit`** — Tessera's HealthKit namespace (does not import Apple's HealthKit directly). Provides `HealthKit.read(.hrv, .sleep)` and `HealthKit.Metric` enum.
- **`WorkoutKit`** — Tessera's WorkoutKit namespace. Provides `WorkoutKit.schedule` computed property.

Both default to mock implementations that return canonical fixture data. Production apps inject `LiveHealthDataProvider` or `LiveWorkoutScheduler` for real platform integration.

## Testing

Tests use `@testable import Tessera` and the canonical fixture path (no real model required). The test suite covers:

- Agent construction and hero-shot compilation
- On-device and cloud model dispatch
- Fallback routing (primary fails → fallback)
- Tool JSON contracts (HealthKit read, WorkoutKit schedule)
- Trace Codable round-trip
- Model provider label exhaustiveness
- Error path coverage

## File Layout

```
Sources/HarnessKit/
├── Agent.swift                  # Agent, AgentResponse
├── AgentConfiguration.swift     # AgentConfiguration
├── HarnessKit.swift             # Module metadata (TesseraInfo)
├── TesseraError.swift           # TesseraError (typed errors)
├── Models/
│   ├── ModelProvider.swift      # ModelProvider, OnDeviceModel, CloudModel
│   ├── FoundationRunner.swift   # On-device Foundation Models runner
│   ├── CloudRunner.swift        # CloudModelRunner protocol + stub
│   └── FMToolAdapter.swift      # FoundationModels.Tool adapter
├── Tools/
│   ├── Tool.swift               # Tool protocol
│   ├── HealthKit.swift          # HealthKit namespace + Metric
│   ├── HealthKitIntegration.swift  # HealthDataProvider, MockHealthDataProvider, LiveHealthDataProvider
│   ├── WorkoutKit.swift         # WorkoutKit namespace
│   └── WorkoutKitIntegration.swift # WorkoutScheduler, ScheduledWorkout, mocks
├── Trace/
│   └── Trace.swift              # AgentTrace, TraceEvent
└── Mocks/
    └── CanonicalRun.swift       # Canonical fixture data (SPEC §3)
```
