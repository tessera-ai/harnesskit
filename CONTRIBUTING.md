# Contributing to HarnessKit

Thanks for your interest. This guide covers how to contribute effectively.

## Quick start

1. Fork the repository
2. Create a feature branch: `feat/<short-description>`
3. Make your changes
4. Ensure all CI checks pass locally (see below)
5. Open a pull request against `main`

## Code style

- **Swift**: We use [swift-format](https://github.com/apple/swift-format) with the configuration in `.swift-format`. Run `swift-format format --in-place --recursive <path>` before committing.
- **TypeScript**: ESLint config is in `apps/dashboard/eslint.config.mjs`. Run `npm run lint` from `apps/dashboard/`.
- **Commits**: Use [Conventional Commits](https://www.conventionalcommits.org/) — `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`.

## Running tests

```bash
# HarnessKit SDK tests (62 tests, all mock-based)
cd packages/HarnessKit
swift test

# Dashboard lint + build
cd apps/dashboard
npm ci && npm run lint && npm run build
```

## CI

All PRs must pass:

- **Swift format check** — strict lint via `swift-format`
- **Forge build** — Xcode build for iOS Simulator (Xcode 26)
- **Dashboard build + lint** — Next.js lint and production build

CI runs on `macos-15` (Swift) and `ubuntu-latest` (Node). You don't need to replicate these exactly — just ensure `swift test` and `npm run lint` pass locally.

## Pull request process

- PRs require review from a maintainer (`@byhow` or `@woshileo` per `CODEOWNERS`).
- Keep PRs focused — one concern per PR makes review faster.
- If your change affects the public API (`Agent`, `Tool`, `ModelProvider`, `AgentTrace`), update the README API section and tests accordingly.
- If you're adding a new tool, include both the implementation and mock provider.

## Architecture notes

- **On-device first.** User health data never leaves the device. Cloud fallback is for model inference only — never for data storage or processing.
- **Protocol-based dependencies.** Every platform dependency (`HealthDataProvider`, `WorkoutScheduler`) is behind a protocol. Mocks live in `Mocks/`.
- **Structured traces.** Every `Agent.run()` returns an `AgentTrace`. Changes to trace events should be backward-compatible.

## Reporting issues

- **Bugs**: Open an issue with reproduction steps, expected vs. actual behavior, and device/OS info.
- **Security vulnerabilities**: See [SECURITY.md](SECURITY.md) — do not file public issues for security bugs.

## License

By contributing, you agree that your contributions will be licensed under the [Mozilla Public License 2.0](LICENSE).
