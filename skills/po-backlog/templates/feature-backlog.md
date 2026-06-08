# Template — `docs/feature_backlog.md`

Apply this template literally when writing the file. Replace bracketed placeholders. Order of sections is non-negotiable; downstream agents grep by section heading.

---

## Top-of-file structure

````markdown
# Feature Backlog & MVP Roadmap
**Product:** [Working Title]
**Date:** [YYYY-MM-DD]
**Author:** PO Agent
**Source:** docs/market_analysis_report.md
**Version:** 1.0
**GitHub Repo:** [owner/name — filled by Phase H if GitHub Project was set up, otherwise omit]
**GitHub Project:** [URL — filled by Phase H if GitHub Project was set up, otherwise omit]

---

## Product Vision
[One sentence: "A [product type] that solves [problem] for [persona] by [unique mechanism]."]

## Differentiator (one line)
[The single most important reason this product wins vs. the field.]

---

## Personas
### [[P1]] — [identity in one phrase, optional]
- **Jobs-to-be-done:** [1–2 outcomes]
- **Context:** [when/where]
- **Pain points addressed:** report §X.Y — [specific findings]

### [[P2]] — ... (only if justified by distinct JTBD/context — see SKILL.md §4)

---

## Persona × Feature Matrix
| Feature | [[P1]] | [[P2]] | [[P3]] |
|---|---|---|---|
| [[F-001]] | ✅ | ✅ |   |
| [[F-002]] |   | ✅ | ✅ |

---

## Feature Index (compact)
| ID | Feature | Category | Priority | Persona | Depends on | Competitor signal | Source |
|---|---|---|---|---|---|---|---|
| [[F-001]] | ... | Core Loop | 🔴 P0 | [[P1]] | — | gap | report §3.2 |
| [[F-002]] | ... | Onboarding | 🔴 P0 | [[P1]], [[P2]] | — | parity | report §2.1 |
| [[F-003]] | ... | Monetization | 🟠 P1 | [[P1]] | [[F-001]] | gap | report §4.5 |
````

---

## Per-feature detail block (one per feature, ordered by ID)

````markdown
### [[F-001]] — [Feature Name]
- **Category:** Core Loop  ·  **Priority:** 🔴 P0  ·  **Persona:** [[P1]]
- **Depends on:** —
- **Competitor signal:** gap (none of top 5 have this)
- **Source:** report §3.2 — "users complain X"
- **Feature promise:** User can [action] so that [outcome].
- **Key data & integrations:** needs user auth · stores user-generated content · reads system clock
- **Hard constraints:** *(example shapes — use what fits the product)* mobile: `NSMicrophoneUsageDescription` for audio capture · web SaaS: SSO required for enterprise tier · CLI: must run on macOS / Linux / Windows · cross-cutting: GDPR explicit consent before analytics
- **Open questions:**
  - Should sessions be discardable without saving, or always persisted?
- **Success signal:** First completed session within 48h of first use
- **P0 rationale** *(P0 only)*: report §3.2 — top complaint across 4 of 5 competitor reviews
````

P2 and P3 features may collapse to the compact table only — but if BA is likely to pick them up soon, write the detail block.

---

## Tail of file

````markdown
## Out of Scope (considered & rejected)
- **[Feature idea]** — Rejected because: [reason tied to persona or positioning]
- ...

## Success Metrics (derived from analysis benchmarks)
Cite the benchmark source for each target. Pick metrics that match the product type — examples below span mobile, SaaS, and tools.

- **Activation:** [target] — benchmark: report §X says top products land at Y
- **Retention (D7 / W2 / M2):** [target — choose the horizon that matches the use cadence]
- **Conversion (trial → paid, free → paid, signup → activated):** [target]
- **Quality signal (rating, NPS, CSAT, or churn):** [target]

(If the analysis lacks benchmarks, mark each metric `[needs benchmark — conservative default]` with a one-line justification.)

---

## Changelog
| Version | Date | Changes |
|---|---|---|
| 1.0 | [YYYY-MM-DD] | Initial backlog generated from market_analysis_report.md |
````
