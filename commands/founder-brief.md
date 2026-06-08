---
description: Capture an original founder-driven product idea (mobile app, web SaaS, desktop, CLI, browser extension, API, etc.) into a market_analysis_report.md-compatible brief, bypassing keyword research. Use when you have a novel niche idea with no clear adjacent competitor category to analyze.
argument-hint: (no arguments — conversational)
---

# Founder Brief — original idea capture

Build a `docs/market_analysis_report.md` directly from the founder's idea, without running `po-market-analyst`. Product-type agnostic — works for mobile apps, web SaaS, desktop tools, CLIs, browser extensions, APIs, or anything else. The output is schema-compatible so downstream skills (po-backlog, ba-feature-analyst, etc.) work normally — but every claim is tagged `[founder-insight]` so anti-enthusiasm safeguards default derived features to P3.

## Pre-flight

1. If `docs/market_analysis_report.md` already exists: STOP and warn. Ask user "Overwrite the existing analysis (you'll lose any real market data) or cancel?" Continue only on explicit confirmation.
2. If `docs/feature_backlog.md` already exists: warn the user. This command is typically run BEFORE `po-backlog`. Continue only if user confirms they want to regenerate the analysis (po-backlog won't re-run automatically — they'll need to invoke it).

## Conversation (6 questions — ask one at a time, wait for each answer)

### Q0 — Product type / medium
> "What kind of product is this? Pick the closest match (or describe in one line):
> - **Mobile app** (iOS, Android, cross-platform)
> - **Web SaaS** (browser-based product, B2B or B2C)
> - **Desktop app** (macOS, Windows, Linux)
> - **CLI / developer tool** (terminal binary, library, SDK)
> - **Browser extension**
> - **API / backend service**
> - **Other** — describe briefly
>
> This sets the platform context for later questions (constraints, success signal) and the report header."

### Q1 — Idea + positioning
> "In 2–4 sentences: what does the product do, who is it for, what problem does it solve, and why is now the right moment to build it?"

### Q2 — Primary persona (tight, 3 fields)
> "Describe the primary user — only 3 things:
> 1. **JTBD** — what specific outcome do they hire the product for?
> 2. **Context** — when/where do they open it?
> 3. **Pain** — what frustration are they trying to relieve?
>
> 'I am the persona' is a valid answer — state it explicitly if so."

### Q3 — Pain points + differentiator
> "Two parts in one answer:
> (a) What do users do TODAY without this product? (workarounds, other tools, manual processes — observed or self-experienced)
> (b) Why hasn't anyone built this well already? (technical barrier, niche too small for incumbents, attention gap, recent enabler like a new platform API, model, or distribution channel)"

### Q4 — Hard constraints
> "Anything that binds design decisions. Pick examples relevant to your product type from Q0:
> - **Mobile:** StoreKit for subscriptions, ATT prompt, HealthKit, family-sharing, push-notification entitlements
> - **Web SaaS:** SSO/SAML for enterprise, SOC 2 expectations, multi-tenant isolation, browser compatibility floor, rate limits
> - **Desktop:** code signing, sandbox entitlements, auto-update channel, OS API access
> - **CLI / dev tool:** OS support matrix, package manager constraints, runtime/language version floor
> - **Browser extension:** manifest version (MV3), permission scope limits, store-review constraints
> - **API / backend:** uptime SLO, latency budget, data-residency, auth model (OAuth/API keys)
> - **Cross-cutting regulatory:** COPPA (under-13), GDPR, HIPAA (US health data), PCI-DSS (card data), accessibility (WCAG)
> - Or 'none observed' if applicable."

### Q5 — Success signal
> "One telemetry event that would PROVE the product works for a user. Example shape by product type:
> - **Mobile app:** 'returns within 7 days of install', 'completes first session in under 5 minutes', 'starts a second subscription cycle'
> - **Web SaaS:** 'invites a teammate within 24h of signup', 'completes the first core workflow in session 1', 'returns on day 2', 'connects an integration'
> - **CLI / dev tool:** 'runs the tool a second time within a week', 'gets integrated into a CI pipeline or shell config'
> - **Browser extension / desktop:** 'used on day 2 after install', 'pinned/kept enabled after first week'
> - **Any product:** the activation event (the moment they 'got it') or the repeat-use event (the moment they're hooked)
>
> Be specific — vague metrics weaken downstream story-writing."

## Compose the report

Read `~/.claude/skills/po-market-analyst/templates/market-analysis-report.md` for the §1–§12 schema. Fill it as follows (every prose claim ends with `[founder-insight]`).

**Header overrides** (the template assumes App Store; you must adapt for non-mobile product types from Q0):
- **Title line:** if Q0 is "Mobile app", keep `# App Store Market Analysis Report`. Otherwise write `# Market Analysis Report` (drop "App Store").
- **Platform line:** write the Q0 answer literally (e.g. "Web SaaS", "CLI / developer tool", "Browser extension", "API / backend service", "Desktop (macOS)"). For mobile, keep "iOS / Android / both".
- **Keyword(s) line:** write `Founder brief — no keyword search performed.`
- **Market / locale line:** if not mobile, write the relevant distribution surface (e.g. "Web — global", "npm registry — global", "Chrome Web Store — global"). For mobile, keep "[locale] App Store".

| Section | Source | Notes |
|---|---|---|
| §1 Executive Summary | from Q1 | 3–4 sentences |
| §2 Apps Analyzed | empty table + `**None identified — founder-led brief.** See §12.` | For non-mobile products, the table header still applies — just leave it empty. |
| §3 Per-App Profiles | `—` | |
| §4 Feature × Competitor Matrix | omit table; write `Not applicable — no competitors profiled. Each feature is by definition a `gap`.` | |
| §5 Common Pain Points | from Q3(a) | One §5.x entry per distinct pain; "Frequency: founder-observed (N=1)"; tag `[founder-insight]` |
| §6 Unmet Needs (Whitespace) | from Q1 problem + Q3(b) | This is the heart of the brief; tag `[founder-insight]` |
| §7 Winnable Differentiators | from Q3(b) | The mechanism; tag `[founder-insight]` |
| §8 Category Benchmarks | `No category benchmarks (no comparable products analyzed). Targets will be set post-launch from real telemetry — see §5 success signal.` | |
| §9 Audience Signals | from Q2 | JTBD/Context/Pain; tag `[founder-insight]` |
| §10 Risk Factors | brief risks the founder can name (e.g. "low awareness — needs education", "platform gatekeeper may reject if X", "incumbent may copy quickly") | tag `[founder-insight]` |
| §10.1 Regulatory & Platform | from Q4, scoped to Q0's product type | Write product-type-appropriate constraints. Mobile → StoreKit/ATT/HealthKit. Web SaaS → SSO/SOC2/multi-tenant/CORS. CLI → OS matrix/package manager. Browser ext → MV3/permission scope. Cross-cutting → COPPA/GDPR/HIPAA/PCI/WCAG. If "none observed", write that explicitly. |
| §11 Positioning | derive from Q1 | One paragraph; reference §6 and §7 |
| §12 Appendix | `**Limitations:** Founder-led brief. No market data. No per-product profiles. All claims are `[founder-insight]`. Once UAT or user research generates real signals, update sections in place or supersede with a competitor-research run.` | |

Also write the Q5 telemetry event into §1 (one line: `**Success signal:** <event>`) — po-backlog reads this as the seed for its KPI section.

Write the file to `docs/market_analysis_report.md`.

## Log

```bash
mkdir -p docs && echo "- $(date '+%Y-%m-%d %H:%M') · founder-brief · idea=\"<one-line title from Q1>\" · all-claims-tagged-founder-insight" >> docs/log.md
```

## Hand-off

Tell the user:

> 📝 Founder brief saved to `docs/market_analysis_report.md`.
>
> **Important:** every claim is tagged `[founder-insight]`. When `po-backlog` reads this, it treats the report as evidence-light: **every feature defaults to `[Founder addition]` at P3**, regardless of which §X you cite. This is the anti-enthusiasm rule working as designed — kanıtsız fikir ve UAT'lı fikir aynı önceliği almaz.
>
> To promote features to P1/P0 later, add evidence to the relevant § section (UAT findings, user research, observed behavior) and re-run `po-backlog` in update mode.
>
> **Next step:** run `po-backlog` to generate the feature backlog.

## Notes

- Do NOT invent persona details beyond what the user gave in Q2. If they said "I am the persona", §9 reflects that — no fabricated "Maya, 34, working parent" archetypes.
- Do NOT use `[verified — url]` or `[inferred from N reviews]` tags. These imply external evidence which doesn't exist here. `[founder-insight]` is the only valid tag.
- Do NOT skip §10.1. If the user said "none observed" in Q4, write that literally. Empty regulatory section silently degrades to "hallucinate constraints later" downstream.
- Do NOT default §10.1 to iOS-only constraints when Q0 indicates a non-mobile product type. A web SaaS brief that lists "StoreKit required" is a tell that the model ignored Q0 — re-read it.
- This is a one-shot command. If the user wants to revise after writing, they edit the file directly or re-run the command (with overwrite confirmation).
