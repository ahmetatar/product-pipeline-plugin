# Template — `feature-analysis.md`

Path: `docs/features/[F-XXX]-[feature-slug]/feature-analysis.md`

Apply this template literally when writing the file. Replace bracketed placeholders. Section order is non-negotiable; downstream skills grep by heading.

````markdown
# [[F-XXX]] Feature Name
**Date:** [YYYY-MM-DD]
**Author:** BA Agent
**Status:** Draft
**Mode:** [greenfield | brownfield]

---

## Feature Promise
[One sentence: what this feature enables the user to do.]

## Personas Served
- [Persona Name]: [why they need this feature]

## Entry Points
- [Where/how the user accesses this feature]

## Exit Points
- [What happens after the feature interaction completes]

## Out of Scope
- [What this feature explicitly does NOT cover]

## Codebase Scan (brownfield only)
- [Existing files/modules related to this feature, with one-line description]

## Feature-Level Contracts
Types/schemas/shapes shared across stories, as a **language-agnostic table — NOT code**. Concrete
(real names, fields), not placeholders. Stories reference these by name and MUST NOT redefine them.

| Name | Kind | Inputs | Output / Shape | Notes |
|---|---|---|---|---|
| OnboardingState | type | — | step: int, completed: bool, profile: UserProfile? | shared across S-01..S-03 |

- `Kind` ∈ type / operation / endpoint / event / config.
- Neutral types only: `string`, `int`, `bool`, `list<T>`, `map<K,V>`, `datetime`, `UUID`; `?` = optional.
- The coding agent maps these to the project's language. If none, write `None.`

## Stories Overview
| ID | Story Title | Type | Depends On | File |
|---|---|---|---|---|
| [[S-01]] | ... | Core flow | — | .../stories/S-01-[slug]/story-plan.md |
| [[S-02]] | ... | Error state | [[S-01]] | .../stories/S-02-[slug]/story-plan.md |

(No bootstrap story — the technical foundation is established by `system-architect` before BA runs.)

## Feature Definition of Done
- [ ] All stories completed and individually verified
- [ ] End-to-end happy path works without interruption
- [ ] All edge cases handled per story specs
- [ ] No story left with an unresolved dependency or open blocking assumption
- [ ] Feature-Level Contracts implemented exactly as specified
````

After Phase F (GitHub Sync) runs, also insert a `**GitHub Project:** <url>` line into the header block, right after `**Mode:**`.
