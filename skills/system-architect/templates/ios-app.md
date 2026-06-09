# Template — iOS app (SwiftUI)

Type template for `system-architect` Phase C–F. Read at scaffold-time. Adapt to the user's Phase B
choices; this is the idiomatic default, not a straitjacket.

## Project Profile values
- **Type:** iOS app
- **Platform:** SwiftUI · iOS 18+ (confirm minimum deployment target with the user if it matters)
- **Language:** Swift 5.10+
- **Package manager:** SPM (Swift Package Manager)
- **Design system:** custom (pd-design-foundation authors `DesignSystem/Tokens.swift`)
- **Distribution surface:** App Store / TestFlight
- **CI/CD target:** swift-ios

## Open choices (Phase B)
- **App target shape:** SPM-modular library + thin app target (recommended, CLI-scaffoldable) vs a
  full Xcode `.xcodeproj` app (needs XcodeGen / Tuist, or a manual project). An `.xcodeproj` cannot
  be cleanly created from the CLI — if the user wants one, use a generator and record which.
- **Test framework:** `swift-testing` (modern, iOS 18+/Xcode 16) vs `XCTest` (broad compatibility).

## Canonical folder structure
Aligns with the user's example (App, Services, Resources, Utils) plus the modules the pipeline needs.

```
App/                  — @main App struct, root scene, app-level navigation
Features/             — one folder per feature module (Onboarding/, Paywall/, …)
Services/             — networking, persistence, analytics, domain services
Models/               — domain models / entities
DesignSystem/         — Tokens.swift (pd-design-foundation) + shared UI components
Resources/            — Assets.xcassets, localizations, fonts
Utils/                — extensions, helpers, formatters
Tests/                — mirrors the source tree (FeaturesTests/, ServicesTests/, …)
```
(For an SPM-modular layout these live under `Sources/<Target>/…`; record the real paths in
REFERENCES.md. Keep the role names above stable so stories can reference them.)

## Scaffold (Phase C)
```bash
# SPM-modular default:
swift package init --type library --name <AppName>
# create the canonical folders (real, with .gitkeep):
mkdir -p App Features Services Models DesignSystem Resources Utils Tests
# add tooling
brew list swiftlint >/dev/null 2>&1 || brew install swiftlint
brew list swift-format >/dev/null 2>&1 || brew install swift-format
```
- In `Package.swift`, set `platforms: [.iOS(.v18)]` (or the confirmed deployment target) so
  `xcodebuild` can target iOS — without it the package builds only for the macOS host.
- Add a `.swiftlint.yml` (minimal) and a `.gitignore` for Xcode/SPM (`.build/`, `*.xcuserstate`,
  `DerivedData/`).
- If the user chose a full Xcode app target, generate it with XcodeGen (`project.yml`) or Tuist and
  record the scheme name (devops-ci-architect needs it later).

## Commands to verify (Phase D) — run each, capture final line
The build proof MUST target iOS, not the macOS host. `swift build` alone is NOT acceptable iOS
proof — it builds for the host. Pick the set matching the Phase B app-target choice:

**SPM-modular library** (after setting `platforms: [.iOS(...)]` in `Package.swift`):
- Build:  `xcodebuild build -scheme <AppName> -destination 'generic/platform=iOS Simulator'`
- Test:   `xcodebuild test -scheme <AppName> -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -parallel-testing-enabled NO`
  (a fresh package may report "no tests" — acceptable)

**Full Xcode app target** (XcodeGen/Tuist) — after generating the project:
- Scheme: `xcodebuild -list`  (confirm the scheme resolves)
- Build:  `xcodebuild build -scheme <Scheme> -destination 'generic/platform=iOS Simulator'`
- Test:   `xcodebuild test -scheme <Scheme> -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -parallel-testing-enabled NO`

> **`-parallel-testing-enabled NO` is required on the Test command.** Without it xcodebuild clones the
> simulator per test class (`Clone 1 of …`, `Clone 2 of …`) and runs them in parallel — several booted
> simulators at once, heavy on a dev machine and noisier logs. The flag runs the suite sequentially on a
> single simulator. Record the Test command **with this flag** in `docs/REFERENCES.md` so every
> downstream story inherits it.

**Both shapes:**
- Lint:   `swiftlint`    (or `swiftlint --strict` if the user wants it gated)
- Format: `swift-format format -i --recursive .`

If no iOS simulator runtime is installed (`xcodebuild` can't resolve the destination), ask the user
which destination/simulator to use rather than falling back to a host build.

## Conventions to record
- View files end in `View.swift`; observable state in `…Model.swift`.
- Feature modules namespaced by folder, not file prefix.
- No raw hex/SF font sizes in views — import `DesignSystem` tokens (after pd-design-foundation runs).
