# iOS / SwiftUI gotchas & verified patterns

Reusable, hard-won iOS knowledge for any **SwiftUI + SwiftData + CloudKit (private DB)** app this
pipeline builds. These were verified on a real project (the Ruyana iPhone app) — concrete examples are
kept because they're the fastest way to recognize the same trap in a new project. Treat each as a
default to reach for, not a rule to apply blindly.

---

## 1. Value-based `NavigationLink` holding a SwiftData `@Model` crashes

**Symptom:** pushing a detail from a `List` of SwiftData `@Model`s with **value-based** navigation —
`NavigationLink(value: model)` + `.navigationDestination(for: Model.self)` — crashes at launch with
`EXC_BAD_ACCESS` / over-release (`_swift_release_dealloc`) during root `body` evaluation, especially on
a list that also swipe-**deletes** those same models and/or has a multi-year-seeded store.

**Fix:** use a **view-based** link instead:

```swift
NavigationLink { DetailView(model: model) } label: { RowView(model) }   // ✅
// NOT: NavigationLink(value: model) + .navigationDestination(for: Model.self)  // ✗ crashes
```

**Why:** SwiftUI's navigation-path machinery mismanages the reference-counted `@Model` held as a
navigation *value*, particularly in a list that deletes those models.

**Apply:** for any list→detail push of a SwiftData `@Model`, use the view-based `NavigationLink`. Don't
"simplify" it back to `navigationDestination(for: <@Model>.self)`.

---

## 2. Xcode build re-extracts strings → `.xcstrings` churn; never `git commit -a`

**Symptom:** running `xcodebuild build`/`test` (or any run-on-sim script) triggers Xcode's automatic
Swift string extraction, which **rewrites the source `Localizable.xcstrings`** — re-serializing the
whole file (cosmetic churn) and adding spurious auto-generated entries (e.g. a `%@`-arg variant
`"%@ nokta"` alongside the real `Int` key `"%lld nokta"`), sometimes with no `en`/`tr` values. A
`git commit -aqm "…"` then silently sweeps hundreds of lines of reformatting + untranslated keys into
the commit, and it rides into the squash-merge.

**Apply:**
- After any build/test/run, stage the catalog with an **explicit path**
  (`git add <app>/Resources/Localizable.xcstrings`) and **review its diff** — never `git commit -a` in
  an iOS repo with a String Catalog.
- Prefer a targeted `Edit` (string replacement) over full JSON re-serialization to avoid re-churning.
- If the build added a spurious `%@`-variant key, give it both `tr`+`en` (durable — it may re-appear on
  the next extraction) or delete it. The live runtime key for `Text("\(intCount) nokta")` is
  `%lld nokta`, not `%@ nokta`.

---

## 3. Deterministic XCUITest harness (store DI seam + launch-arg overrides)

XCUITests run against the app's real store + persistent `UserDefaults`, so they're non-deterministic
unless isolated. The harness that makes "fresh-state" assertions reliable **without resetting the
simulator**:

- **Store isolation:** make the model container an injectable seam (e.g. a `ModelContainerProviding`
  protocol). Inject the CloudKit provider in production; swap to an **in-memory** provider — seeded with
  the minimum rows the flow needs (e.g. one `Person` if create-flows require it) — when a launch arg
  like `UITEST_EPHEMERAL` is present. (No leading dash → it's not an `NSArgumentDomain` key, so it won't
  collide with the value args below.)
- **Routing / locale via `NSArgumentDomain` launch args (no app code needed):**
  `-onboardingCompleted YES` (skip onboarding → straight to Home), `-appLockEnabled NO` (**bypass any
  Face ID / app-lock gate — it leaks into UI tests from prior runs and otherwise covers the screen**),
  `-AppleLanguages (tr)` + `-AppleLocale tr_TR` (pin the source language so label-based queries match
  the source copy).
- **Querying:** rows wrapped in a `Button` merge their child `Text`s into the button label → query with
  `app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "…"))`, not `staticTexts`.

**Apply:** reuse these exact launch args for any new XCUITest; extend the in-memory provider's seed if a
flow needs more than the minimum.

---

## 4. CLI screenshot of a SwiftUI subview via `ImageRenderer` (no simulator drive)

To visually verify a SwiftUI view from the CLI without tapping through the running app: write a
throwaway `@MainActor` Swift Testing test that builds an in-memory `ModelContainer` (`.none` CloudKit),
seeds the needed `@Model`s, renders the view with `ImageRenderer(content:)` (`renderer.scale = 3`),
writes `uiImage.pngData()` to `/tmp/*.png`, then Read the PNG. Flip
`.environment(\.colorScheme, .dark)` for a dark pass. Delete the test after review.

**Gotchas:** `ImageRenderer` does **not** render `ScrollView` scrollable content or a `NavigationStack`
(you get a blank background or a placeholder) — so render the target **subview in isolation**, not the
whole screen. This is a reason to extract a section into its own `internal View` struct (testable +
snapshot-able). Omit an explicit height so it sizes to content. The test host locale is `en`, so the
snapshot doubles as an English-localization check.

(For a full-screen pass that *does* need the live navigation/scroll, drive it through the XCUITest
harness in §3 with `XCTAttachment(screenshot:)` + `xcrun xcresulttool export attachments` instead.)

---

## 5. iCloud restore-on-launch: CloudKit-marker + `@Query`, never a `Duration`-through-closure timeout

For "detect a returning user on cold launch and restore from their iCloud **before** showing
onboarding," the working pattern is a **marker + reactive query**, not a timeout/poll:

- Write a lightweight **CKRecord "recovery marker"** (metadata only — timestamps) into the user's own
  private CloudKit DB on onboarding completion. On launch, a `checkPresence()` →
  `exists` / `missing` / `inconclusive` decides returning-vs-new **quickly**, before the heavier
  SwiftData rows sync down.
- The root view holds a **`@Query`** for the model and pushes its live count into the launch
  coordinator via `.onChange(of: people.count, initial: true)`, so it reacts the instant CloudKit syncs
  the first row — no manual fetch-poll.
- `missing` / `inconclusive` / no-account ⇒ go to onboarding (never trap the user); add a **"Set up
  fresh instead"** escape for the marker-exists-but-row-never-arrives case.

**The landmine (verified on a real device, not reproduced on the simulator):** passing a 16-byte
**`Duration` as an argument through an `async` closure *value*** corrupted it on device — a
confirmed-correct `.seconds(10)` arrived inside the callee as ~1.6e11 s — so timeouts never fired and
the launch gate hung forever. Direct `async` calls (`Task.sleep(for:)`) were fine; only the
**closure-value argument crossing** corrupted.

**Takeaway:** don't pass `Duration` (or other multi-word structs) as arguments through stored `async`
closure values — pass `Int`/scalars, or avoid the timeout pattern entirely (the marker + `@Query`
design needs no `Duration` at all).
