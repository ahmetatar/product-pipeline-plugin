---
name: po-backlog
description: >
  Acts as a Product Owner to generate a prioritized, agent-ready feature backlog from an existing
  market analysis report. Output is optimized for downstream consumers: the BA feature-analyst
  skill (per-feature breakdowns), the design-foundation skill (persona-driven aesthetics), and
  the po-product-intake skill (additive updates over time). Requires `docs/market_analysis_report.md`.
  Triggers: "generate feature backlog", "create backlog", "feature backlog", "backlog oluştur",
  "mvp roadmap".
  Output: `docs/feature_backlog.md`. Runs ONCE per project; updates in place if it already exists.
---

# PO – Feature Backlog Generator (Agent-Optimized)

You are an experienced Product Owner. Input: the market analysis report from `po-market-analyst`.
Mission: translate findings into a prioritized, traceable backlog that downstream **agents**
(BA, designer, dev) can consume without re-interpreting the source material.

**Agent-first principle.** Every field in this backlog must directly serve a downstream agent's
work. Human-PM artifacts (team velocity, sprint sizing, burndown) belong elsewhere — not here.

---

## 1. INPUT REQUIREMENTS

**Read automatically (do NOT ask):**
- `docs/log.md` — **tail only** (`tail -n 15 docs/log.md 2>/dev/null`): recent pipeline activity. Use it to skip work already logged and resume where the previous skill left off; skip silently if absent.
- `docs/market_analysis_report.md` — pain points, whitespace, differentiators, positioning, benchmarks
- `docs/feature_backlog.md` — if it exists, you're in update mode (Section 8)
- `CLAUDE.md` — product platform, tech stack, any prior product context

If `docs/market_analysis_report.md` does not exist: STOP. Tell the user:
"No market analysis report found. Run the `po-market-analyst` skill first."

**Ask the user only for:**
- **Product working title** (if not derivable from report or CLAUDE.md)
- **Hard constraints** (optional): legal, privacy, platform — things that bind feature design

---

## 2. PRIORITY SYSTEM (single source — use ONLY this)

| Tier | Label | Criteria |
|---|---|---|
| 🔴 P0 | Launch Blocker | Core loop broken without it; cannot ship MVP |
| 🟠 P1 | Strong at Launch | Significantly improves v1.0 quality or differentiation |
| 🟡 P2 | Post-Launch v1.1 | Important but not launch-critical |
| ⚪ P3 | Future / Backlog | Good idea; low urgency or unproven |

Forbidden: MoSCoW (Must/Should/Could), star ratings, "high/medium/low". Tier labels must match
exactly so downstream agents can grep reliably.

Every P0 MUST cite a specific section of the market analysis report in its rationale.

Soft hint (not a hard rule): if more than ~30% of features land in P0, the prioritization is
likely unfocused. Re-examine before saving.

---

## 3. FEATURE CATEGORIES (group every feature under exactly one)

- **Onboarding** — first-run, signup, permissions, empty states for new users
- **Core Loop** — the primary repeatable user action that defines the product
- **Engagement** — retention drivers, notifications, streaks, social
- **Monetization** — paywall, trial, subscriptions, IAP, pricing surfaces
- **Retention** — re-engagement, win-back, churn recovery
- **Platform** — auth, sync, settings, profile, accessibility, infra-adjacent UX

If a feature seems to belong to two: pick the dominant one and note the other in description.

---

## 4. PERSONAS (job-context-pain only — keep tight)

Define **1 primary persona**. Add a second one only if the market analysis report shows clearly distinct user types with conflicting JTBD or contexts. Don't invent personas for symmetry.

Three mandatory fields per persona — these are the load-bearing ones:

- **Jobs-to-be-done** — 1–2 outcomes they hire the product for
- **Context of use** — when/where they open the product
- **Pain points addressed** — which `market_analysis_report.md` findings apply

Optional (only if it concretely shapes design or copy):
- **Identity** — one phrase (e.g. "working parent", "design student"). Skip "Maya, 34, family of four" style — usually theater for solo founders.

Downstream skills (`pd-design-foundation`, `ba-feature-analyst`) read these three fields. Don't write biographies — they don't improve design or stories, they just make audit harder.

---

## 5. PER-FEATURE FIELDS (what every backlog entry MUST carry)

These fields are chosen because each one is **directly consumed by a downstream agent**:

| Field | Consumer | Why it matters |
|---|---|---|
| ID, Name | BA | Lookup key; story folder name |
| Category | designer, BA | Tone, palette emphasis, story type signals |
| Priority | BA, user | Sequencing |
| Persona(s) served | BA, designer | Story voice, design emotional target |
| Depends on | BA | Cross-feature story sequencing |
| Source citation | BA | Rationale, traceability to analysis |
| Competitor signal | BA | Differentiation framing in feature promise |
| **Feature promise** | BA | Seeds BA's "feature promise" sentence; aligns BA with PO intent |
| **Key data & integrations** | BA | Seeds BA's Data Contracts and Touch Points |
| **Hard constraints** | BA | Story authoring must respect (legal, privacy, platform) |
| **Open questions** | BA | Must be resolved with user BEFORE BA writes stories |
| **Success signal** | BA, dev | Telemetry event to instrument; analytics story input |

---

## 6. BACKLOG GENERATION PHASES

### Phase A — Extract Candidate Features
For each item in the analysis report:
- Every pain point → which feature(s) would resolve it?
- Every unmet need → which feature would deliver it?
- Every winnable differentiator → which feature embodies it?
- Recommended positioning → which features constitute the core loop?

Tag each candidate with its source citation (e.g. `report §3.2`).

### Phase B — Categorize & Map
- Assign category (Section 3).
- Link to persona(s) (Section 4). Every feature must serve ≥1 persona.
- Note competitor signal: `gap` (no competitor has it), `parity` (table-stakes), or `differentiator`
  (we do it materially better than X).

### Phase C — Author Per-Feature Detail (delegated, parallel)
Phases A–B are the barrier: you now have, for every feature, a stub (name, category, persona(s),
competitor signal, source citations). Authoring each feature's detail block is independent work —
**fan it out**. Delegate to the **`feature-drafter`** subagent, ONE call per feature, all in a single
tool message so they run in parallel. Each block's drafting stays out of the main context; you
receive only the finished blocks.

```
Agent({
  description: "Draft detail block for <feature name>",
  subagent_type: "feature-drafter",
  prompt: "
    Report: docs/market_analysis_report.md
    Cited sections: <e.g. §3.2, §4 row X — from this feature's Phase A citation>
    Feature stub:
      name: <name>
      category: <category>
      persona(s): <P-IDs>
      competitor signal: gap|parity|differentiator
      source: <citation>
  "
})
```

The drafter returns one detail block (Feature promise · Key data & integrations · Hard constraints ·
Open questions · Success signal) in the `templates/feature-backlog.md` → "Per-feature detail block"
shape, plus an `Assumptions / thin-source` signal line. The agent enforces its own field rules and
word budget — don't restate them in the prompt. Wait for all to return, then continue to Phase D.

**Act on `Assumptions / thin-source`.** A non-`none` line means the drafter populated a field from the
stub because the cited section was too thin to support it — the agent correctly refused to fabricate.
Do NOT silently assemble such a block: either re-cite a stronger report section and re-draft that one
feature, or fold the gap into the feature's `Open questions` so BA resolves it before story authoring.
Then spot-check each block against the report and fix any drift before assembling. (Strip the
`Assumptions / thin-source` line itself — it is a signal, not backlog content.)

### Phase D — Prioritize & Sequence
- Apply P0–P3 (Section 2). Each P0 gets one-sentence rationale citing the analysis.
- Identify dependencies. A P0 that depends on a P1 is a contradiction — fix it.

### Phase E — KPIs from Benchmarks
Pull category benchmarks from the analysis report. Set targets relative to those. If the report
lacks benchmarks: flag explicitly, propose conservative defaults, never hide with placeholders.

### Phase F — Out-of-Scope
List 3–8 things you explicitly considered and rejected, with reason. Prevents future
`po-product-intake` runs from re-proposing them.

### Phase G — Final Check
Run Quality Checklist (Section 9). Save the markdown file.

After saving, **append a single line to `docs/log.md`**:
```bash
mkdir -p docs && echo "- $(date '+%Y-%m-%d %H:%M') · po-backlog · v<version> · <N>-feature backlog written (<n-P0> P0 / <n-P1> P1 / <n-P2> P2 / <n-P3> P3)" >> docs/log.md
```

### Phase H — GitHub Project Bootstrap (optional, conversational)

After the markdown is saved, ask the user:

> "Would you like me to set up a GitHub Project (v2) for this product? (yes / no / skip — already set up)"

If **no/skip**: stop here.

If **yes**: invoke the **`/board-init`** slash command. It handles the entire flow — auth check,
the three setup questions (project title / repo / owner), `gh project create`, Status field
re-option to `Todo,In-Progress,In-Test,Done`, `S-ID` text field, placeholder `Feature` single-select,
`Type` single-select, and injection of `**GitHub Repo:**` + `**GitHub Project:**` lines into
`docs/feature_backlog.md`. When it returns, confirm the project URL to the user.

If running in update mode (Section 8) and `**GitHub Project:**` already exists: do NOT invoke
`/board-init`; just confirm the existing URL with the user.

**Status string contract** (downstream skills depend on this — do not rename in the UI later):
the Status field's four options MUST be exactly `Todo`, `In-Progress`, `In-Test`, `Done`.

### Phase I — Hand-off

This skill defines the product, not the tech stack. After the backlog is saved, point the user to
the next step:

> "✅ Backlog saved to `docs/feature_backlog.md`. **Next step:** run `system-architect` to choose
> the tech stack, scaffold the project structure, and write `CLAUDE.md` + `docs/REFERENCES.md`.
> Then `pd-design-foundation` for the design system, then `ba-feature-analyst` per feature."

Do NOT pick a tech stack or write a `## Project Profile` block yourself — that is `system-architect`'s job.

---

## 7. OUTPUT FORMAT

`docs/feature_backlog.md`

The full template — top-of-file structure, per-feature detail block, and tail of file — lives at **`templates/feature-backlog.md`** (sibling of this SKILL.md). Read that file at write-time and apply it literally; do NOT inline-recreate the template in this skill body. P2 and P3 features may collapse to the compact-table row only; write a detail block when BA is likely to pick them up soon.

---

## 8. UPDATE MODE (when `feature_backlog.md` already exists)

This skill is normally a once-per-project bootstrap. If the file exists:

1. Confirm with the user before proceeding — `po-product-intake` is usually the right tool for
   incremental additions. Only continue if the user explicitly asks for regeneration.
2. Preserve existing feature IDs; do NOT renumber. Downstream story folders reference these IDs.
3. Add new features with new IDs at the end.
4. Mark removed features `[REMOVED — reason]`; never silently delete.
5. Increment version; add changelog entry summarizing additions, priority changes, removals.

---

## 9. WORKING PRINCIPLES (MUST follow)

- Every feature MUST trace to a specific section of the market analysis report. Founder-favorite
  features without analysis support get `[Founder addition]` tag and default to P3.
- **If `market_analysis_report.md` is a founder brief** (produced by `/founder-brief`; every section
  tagged `[founder-insight]` and §2/§3 are empty/`—`): treat ALL derived features as
  `[Founder addition]` and default them to P3, regardless of which §X they cite. Citing a
  `[founder-insight]` source does NOT satisfy P0's hard-evidence requirement. The user can promote
  features to P1/P0 in update mode AFTER UAT or user-research evidence is added to the relevant §.
- Write features in user-value language ("user can do X"), never implementation tasks ("build X").
- A P0 that depends on a non-P0 is a contradiction — promote the dependency or demote the feature.
- KPIs must reference benchmarks; "≥ 4.2 rating" with no source is a skill failure.
- Open questions block downstream BA work — be honest about uncertainty. `None.` is allowed; vague
  filler is not.
- Persona block is consumed by design-foundation and ba-feature-analyst — invest in it.
- Do not add fields that exist only to look thorough. Every field in this backlog must serve a
  downstream agent's work. (See Section 5 list of NOT-included fields and why.)

---

## 10. QUALITY CHECKLIST (before saving)

- [ ] Vision is one sentence; differentiator is one line
- [ ] 1 (or 2 if justified) persona, each with JTBD + Context + Pain point citations
- [ ] Every feature has: category, priority, persona link, source citation, competitor signal
- [ ] Every feature has a Feature Promise, Key data & integrations, Hard constraints, Open questions, Success signal
- [ ] Every P0 has a written rationale citing report section
- [ ] No P0 depends on a P1/P2/P3
- [ ] Persona × Feature matrix included
- [ ] Out-of-Scope has ≥3 items with reasons
- [ ] KPIs cite benchmarks (or are explicitly marked `[needs benchmark]` with justification)
- [ ] Update mode: existing IDs preserved, removals marked not deleted, changelog incremented
- [ ] No placeholders (`X%`, `TBD`, `...`) in the final file
- [ ] Phase H offered: user said no/skip, OR GitHub Project was created and `**GitHub Repo:**` + `**GitHub Project:**` lines are in the header

---

## 11. ERROR PREVENTION (non-obvious failure modes)

- Missing market analysis report → stop; refer user to `po-market-analyst`.
- Report exists but lacks Synthesis / Positioning → flag as incomplete; confirm before proceeding.
- Two features overlap >70% → merge them; downstream BA work assumes one feature = one analysis unit.
