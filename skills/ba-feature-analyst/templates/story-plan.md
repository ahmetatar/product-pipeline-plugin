# Template — `story-plan.md`

Path: `docs/features/[F-XXX]-[feature-slug]/stories/[S-XX]-[story-slug]/story-plan.md`

Apply this template literally when writing each story file. Replace bracketed placeholders. Every section is mandatory unless explicitly marked optional inside the template.

````markdown
# [[S-XX]] Story Title
**Feature:** [[F-XXX]] Feature Name
**Type:** [Bootstrap / Core flow / Configuration / Edge-error / Empty state / Permission-access]
**Depends on:** [[S-XX]], [[S-YY]]  — or `—` if none
**Date:** [YYYY-MM-DD]
**Author:** BA Agent
**Status:** Draft

---

## User Story
As [[P1]] (or [[P2]] if backlog defines a second persona), I want to [action], so that [outcome].

## Acceptance Criteria
- [ ] AC1: [Specific, binary, testable]
- [ ] AC2: ...
- [ ] AC3: ...
(Minimum 3. No subjective language: "feels smooth", "looks good" are forbidden.)

## Non-Goals
- [Adjacent work the agent MUST NOT do in this story, even if tempting]

## Touch Points
List every file the coding agent will create or change. Tag with `[NEW] / [MODIFY] / [DELETE]`.
- `Sources/Features/Onboarding/WelcomeView.swift` [NEW]
- `Sources/AppState.swift` [MODIFY — add `onboardingCompleted: Bool`]

## Read First
Files/docs the coding agent MUST load into context before writing code.
- `CLAUDE.md` — conventions
- `docs/design-system.md` — tokens for spacing/color
- `Sources/Features/Auth/AuthCoordinator.swift` — reuse coordinator pattern

## Data Contracts
Types/schemas/operations introduced or modified by this story, as a **language-agnostic table — NOT
code**. In greenfield, MUST be concrete (real names, inputs, outputs, fields — not placeholder).
Reference Feature-Level Contracts by name; do NOT redefine. Describe shape ONLY — never the
implementation logic; the coding agent writes that.

| Name | Kind | Inputs | Output / Shape | Notes |
|---|---|---|---|---|
| OnboardingState | type | — | step: int, completed: bool, profile: UserProfile? | |
| completeOnboarding | operation | profile: UserProfile | OnboardingState (async) | persists profile |

- `Kind` ∈ type / operation / endpoint / event / config.
- Neutral types only: `string`, `int`, `bool`, `list<T>`, `map<K,V>`, `datetime`, `UUID`; `?` = optional.
- The coding agent maps these to the project's language (TS, Swift, …). If nothing new, write `None.`

## Design References
- **Design:** required | n/a — `required` = UI story needing a visual design before coding.
- **Claude Design output:** `design/` under this story folder (Claude Design HTML export + handoff bundle), or `—` if not yet produced.
- Components: [from design-system.md]
- Tokens: [color/spacing/typography to use]

## Edge Cases
| Scenario | Expected Behavior |
|---|---|
| [What could go wrong or be unusual] | [How the system handles it] |

(Mandatory if the story touches user input, network, persistence, or state changes.)

## Observable Behavior
What the system MUST emit or persist as a side-effect of this story. Prevents the coding agent
from inventing ad-hoc analytics, state machines, or storage shapes.

- **State transitions:** [list each state and the trigger to transition out, or `—`]
- **Events / telemetry:** [event name + payload shape the story MUST emit, or `—`]
- **Persistence:** [what is written, where, when; what is read on entry, or `—`]
- **Must NOT emit:** [events/state/storage explicitly out of scope for this story]

## Verification
Commands MUST match the project's tech stack — derive from `CLAUDE.md`, existing `package.json` /
`Package.swift` / `pyproject.toml` / `Makefile` / CI config. Do NOT use generic placeholders.
In greenfield, use the exact Verified Commands recorded in `docs/REFERENCES.md` by `system-architect`.

**Automated:** (examples — replace with the actual stack)
- Swift/SPM:      `swift test --filter OnboardingTests` · `swift build` · `swiftlint`
- Swift/Xcode:    `xcodebuild test -scheme App -destination 'platform=iOS Simulator,name=iPhone 15'`
- Node/TS:        `npm test -- onboarding` · `tsc --noEmit` · `npm run lint`
- Python:         `pytest tests/onboarding` · `mypy .` · `ruff check .`

**Manual:**
1. [Step-by-step walkthrough that proves the happy path]
2. [Step-by-step walkthrough for each edge case]

## Story Definition of Done
- [ ] All ACs check-marked
- [ ] All Touch Points implemented as specified
- [ ] `docs/REFERENCES.md` updated if any structural change was introduced
- [ ] Lint, type check, and tests pass
- [ ] Manual verification steps executed successfully
- [ ] Observable Behavior emitted exactly as specified (no extra events/state/storage)
- [ ] Blocking Assumptions: empty, OR each item has a recorded **Resolution:** line below it
      confirming how it was resolved with the user before coding began

## Blocking Assumptions (resolve BEFORE coding)
The coding agent MUST stop and ask the user to confirm each item below before writing any code.
Do NOT guess.
- [ ] [Assumption that requires human confirmation]

(If empty, write `None.`)
````

After Phase F (GitHub Sync) runs, also insert a `**GitHub Issue:** <url>` line into the header block, right after `**Author:**`.
