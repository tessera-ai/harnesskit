# Tessera AI

Production runtime for on-device personal-data AI agents on Apple.

## Layout

- `packages/HarnessKit/` — Swift package, the SDK (module name `Tessera`)
- `apps/Forge/` — iOS demo app (SwiftUI)
- `apps/console/` — Next.js dashboard (local dev)

## Run

```
# dashboard
cd apps/dashboard && npm run dev

# Forge
open apps/Forge/Forge.xcodeproj
```
