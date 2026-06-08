# Template — `docs/market_analysis_report.md`

Apply this template literally when writing the report. Replace bracketed placeholders. Section numbering (§1–§12) is **stable contract** — `po-backlog` cites these IDs. Do not rename or reorder.

````markdown
# App Store Market Analysis Report
**Keyword(s):** [...]
**Platform:** iOS / Android / both
**Market / locale:** [e.g. US App Store]
**Date:** [YYYY-MM-DD]
**Author:** PO Agent
**Version:** 1.0

---

## §1 — Executive Summary
[3–4 sentences: category opportunity, key finding, recommended direction.]

---

## §2 — Apps Analyzed
| ID | Name | Developer | Rating / Reviews | Model | Last Update | Source |
|---|---|---|---|---|---|---|
| A1 | ... | ... | 4.2 / 12,400 | Sub | 2025-03 | url |
| A2 | ... | ... | 3.7 / 4,200 | Free + IAP | 2024-08 | url |

(8–12 rows. Apps the researcher could not resolve are listed in Appendix §10.)

---

## §3 — Per-App Profiles
Profiles are reproduced from the `competitor-researcher` output, lightly normalized for
readability. Evidence tags are preserved.

### §3.1 — A1: [App Name]
[Full profile block from subagent]

### §3.2 — A2: [App Name]
[...]

---

## §4 — Feature × Competitor Matrix
| Feature | A1 | A2 | A3 | ... | Verdict |
|---|---|---|---|---|---|
| [feature name] | ✅ | ❌ | partial | | gap / parity / differentiator |
| ... | | | | | |

Legend: ✅ has it · ❌ doesn't have it · partial = limited/weak implementation.
Verdict definitions in Phase F. po-backlog copies the Verdict column into its `competitor signal` field.

---

## §5 — Common Pain Points (cross-cutting)
### §5.1 — [Pain title]
- **Frequency:** appears in N of M competitors (A1, A3, A4, …)
- **Severity:** low / medium / high
- **Evidence:**
  - "[paraphrased complaint]" — A1, [url]
  - "[paraphrased complaint]" — A3, [url]
- **Inferred volume:** ~X review mentions across the field

### §5.2 — ...

---

## §6 — Unmet Needs (Whitespace)
### §6.1 — [Need title]
- **Why it's unmet:** [no competitor solves it, or solves it weakly]
- **Feasibility:** easy / medium / hard / requires-partnership / regulated
- **Evidence link to pain points:** §5.1, §5.3

---

## §7 — Winnable Differentiators
### §7.1 — [Differentiator title]
- **Mechanism:** how a new entrant wins on this dimension
- **Evidence:** which competitor data supports this (cite §3.X / §5.X)

---

## §8 — Category Benchmarks (for po-backlog's KPIs)
- **Rating:** range [X–Y], median Z
- **Reviews:** median N, top quartile threshold
- **Pricing:** typical subscription [tier/price], typical trial length, common IAPs
- **Update cadence:** median months between updates
- **Notable extremes:** any outliers worth calling out

---

## §9 — Audience Signals (for po-backlog's personas)
- **Apparent demographics:** [inferred from review language] — ...
- **Context of use:** ...
- **Emotional states (entering):** ...
- **Jobs-to-be-done implied:** ...

(All entries tagged `[inferred]` unless reviews explicitly state demographics.)

---

## §10 — Risk Factors
What makes apps fail in this category — drawn from negative themes across §3 and §5.

### §10.1 — Regulatory & Platform Constraints Observed
Hard constraints that bind any new entrant in this category. po-backlog copies these into its
`Hard constraints` per-feature field — if you don't surface them here, they get hallucinated.

- **Regulatory:** [e.g. COPPA for under-13, GDPR consent surfaces, health data regulations]
- **Platform:** [e.g. App Store requires StoreKit for subscriptions, App Tracking Transparency
  prompt before tracking, family-sharing rules for kid apps]
- **Data/privacy:** [e.g. ATT requirement, third-party SDK disclosures]

Each item should cite a §3 example where the constraint is visible (e.g. competitor A2's privacy
label shows X) or be tagged `[inferred from category — no direct §3 anchor]`.

---

## §11 — Recommended Product Positioning
One paragraph: kind of app, who it serves, core promise, why it wins.
Must reference §5/§6/§7 explicitly.

---

## §12 — Appendix: Limitations & Skipped Apps
- **Apps the researcher could not resolve:** [list with reason]
- **Locale gaps:** [e.g. "TR-specific signals were sparse; report leans on US App Store data"]
- **Confidence caveats:** [anything that should soften the recommendations]
````
