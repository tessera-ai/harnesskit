# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial HarnessKit SDK: declarative `Agent` type with on-device execution and cloud fallback
- HealthKit tool with typed metric reads (HRV, sleep, resting heart rate, active energy, VO2 max)
- WorkoutKit tool for native workout scheduling
- `ModelProvider` enum: on-device (Apple Foundation Models) and cloud (Claude, GPT) backends
- `FoundationRunner` for on-device model execution
- `CloudRunner` for cloud model fallback
- `FMToolAdapter` bridging HarnessKit tools to Foundation Models tool protocol
- Structured `AgentTrace` with typed events (tool calls, reasoning, latencies, bytes egressed)
- `CanonicalRun` mock fixtures for deterministic testing
- Forge demo app (SwiftUI): HealthKit permission flow, agent-driven workout planning
- Dashboard dev console (Next.js): trace timeline visualization
- CI pipeline: Swift format check, Forge iOS build, Dashboard lint + build
- CODEOWNERS: `@byhow` and `@woshileo`
- MPL 2.0 license

### Changed
- MVP polish on SDK integration, error handling, test coverage, and app permissions

### Fixed
- Forge: keep PillLabel text on a single line
- SPEC.md: drop video-pipeline references

[Unreleased]: https://github.com/tessera-ai/harnesskit/compare/HEAD
