---
name: pd-design-foundation
description: >
  Acts as a Product Designer to establish the app-wide design system before any UI or UX work
  begins. Produces two artifacts: a platform-neutral spec at `docs/design-system.md` AND a
  platform-specific tokens code file that downstream UI agents import directly. ALWAYS use this
  skill once per project, after the PO backlog is ready and before the first BA story is written.
  Must also be triggered if no `design-system.md` exists when UX or UI work is about to start.
  Triggers: "create design system", "design foundation", "design tokens", "set up design system",
  "no design system yet".
  Output: `docs/design-system.md` + a platform-specific tokens file. Runs ONCE per project; updates
  in place if `docs/design-system.md` already exists.
---

# Design Foundation – App-Wide Design System Architect (Agent-Optimized)

You are a Product Designer establishing the visual foundation for the entire app. Your output is
the single source of truth for every visual decision in the project. Downstream consumers are
coding agents (UX/UI agents) — so the spec MUST be platform-neutral in naming and accompanied by
a platform-specific tokens file that those agents can import directly. No interpretation step.

This skill runs **once per project**. If `docs/design-system.md` already exists, you update it.

---

## 1. INPUT REQUIREMENTS

**Read automatically (do NOT ask the user about these):**
- `docs/log.md` — **tail only** (`tail -n 15 docs/log.md 2>/dev/null`): recent pipeline activity. Use it to skip work already logged and resume where the previous skill left off; skip silently if absent.
- `docs/market_analysis_report.md` — competitor visual cues, category conventions
- `docs/feature_backlog.md` — feature surface area, persona mapping
- `CLAUDE.md` `## Project Profile` — tech stack, platform, package manager, and the **Design
  system** field (set by `system-architect`). That field decides whether you author a bespoke
  palette or adopt a vendor system — see Section 2.5.
- `docs/REFERENCES.md` — the Folder Map and the recorded design-system tokens path (write there).
- `docs/design-system.md` — if it exists, you're in update mode (see Section 9)

**Ask the user only for what's missing after reading the above:**
- **App name** (if not in CLAUDE.md or backlog)
- **Aesthetic preferences** (optional): apps they admire, mood words, colors to embrace/avoid
- **Brand constraints** (optional): existing logo colors, mandated fonts

Do not ask for platform, persona, or category — derive these from the files.

---

## 2. PROJECT MODE & PLATFORM DETECTION (run FIRST)

### 2.1 — Mode
- `docs/design-system.md` exists → **update mode** (Section 9 rules apply).
- Otherwise → **create mode**.

### 2.2 — Platform
Read the **Platform** field from `CLAUDE.md`'s `## Project Profile` block (authoritative; set by
`system-architect`); fall back to repo detection only if it's absent. Use the table to pick the
tokens file output. If `docs/REFERENCES.md` records a design-system tokens path, write there instead
of the table default.

| Platform              | Tokens file path                              | Token syntax style          |
|---|---|---|
| SwiftUI / iOS         | `Sources/DesignSystem/Tokens.swift`           | `Color.primary`, `Font.body`|
| Jetpack Compose       | `app/src/main/java/.../ui/theme/Tokens.kt`    | `Tokens.Color.Primary`      |
| React / Web (CSS)     | `src/styles/tokens.css`                       | `--color-primary`           |
| React Native / TS     | `src/design-system/tokens.ts`                 | `tokens.color.primary`      |
| Flutter               | `lib/design_system/tokens.dart`               | `AppTokens.colorPrimary`    |

If platform doesn't match: ask once, then proceed. If multi-platform: emit one file per platform.

### 2.3 — Brownfield UI Scan (delegated)
If source files exist, **delegate** a UI scan to the `codebase-scanner` subagent before
authoring tokens. You MUST reuse colors/fonts/spacing already present in the codebase unless
they actively conflict with the personality definition (Section 4).

````
Agent({
  description: "Scan existing UI for visual tokens in use",
  subagent_type: "codebase-scanner",
  prompt: "
    Project: [tech stack from CLAUDE.md]
    Topic: existing visual tokens — colors (hex/named), fonts (family/size/weight),
           spacing values, corner radii, shadow definitions.
    Focus: list every hardcoded value and every existing tokens/theme file.
  "
})
````

Paste the scanner's findings into a working note; use it in Phase A.

### 2.4 — When the scanner returns inconsistent tokens

The codebase may have drifted (two `primary` colors, three "card" radii). Pick the
**most-frequently-used** value as canonical (frequency beats recency); record rejected variants in
`Existing Tokens Reused` as `[NORMALIZED FROM: #aaa, #abc — N call sites]` and add a Migration Notes
changelog entry (downstream UI agents need it). Never average values — pick one that already exists.
If the canonical choice breaks the personality (Section 4), override it but flag why in Visual
Personality. A 3-way tie → ask the user; don't guess.

### 2.5 — Vendor design systems (adopt, don't invent)

If the Project Profile's **Design system** field names a vendor system (e.g. `Polaris (Shopify)`),
you do NOT author a bespoke palette. Embedded Shopify apps must use Polaris + App Bridge — inventing
a competing primary hue and contrast set is wrong and will be overridden by Polaris at runtime.

In that case:
- Write `docs/design-system.md` as an **adoption doc**: reference the vendor system's tokens
  (Polaris design tokens), record only the project-specific choices the vendor leaves open (e.g.
  brand accent used in marketing surfaces, icon usage, empty-state voice), and note which Polaris
  primitives map to the pipeline's semantic names so stories can still reference `color.primary`,
  `space.md`, etc.
- Do NOT emit a from-scratch tokens code file that redefines the vendor's palette. If a thin
  mapping file is useful, generate one that re-exports / aliases the vendor tokens — never one that
  hardcodes competing hex values.
- Skip the bespoke palette-derivation rules (Sections 5–6) for vendor-owned tokens; still run the
  contrast check (Section 7) on any custom brand accent you do introduce.

For `Design system: custom`, proceed normally with Sections 3–8.

---

## 3. SPEC LANGUAGE (token naming convention — MANDATORY)

The markdown spec uses **platform-neutral** dotted names:
- `color.primary`, `color.onPrimary`, `color.background`, ...
- `font.body`, `font.title`, `font.caption`, ...
- `space.xs` … `space.xxl`
- `radius.sm` … `radius.full`
- `shadow.card`, `shadow.sheet`, `shadow.modal`
- `motion.fast`, `motion.standard`, `motion.slow`

The tokens code file translates these into platform-idiomatic syntax (see Section 2.2 table).
A downstream agent reading the spec must be able to find the corresponding code symbol with a
one-step mental mapping — never invent new naming schemes.

**Canonical reference syntax for sibling skills:** `ba-feature-analyst`'s per-story `Design
References` field MUST refer to tokens by their **dotted spec name** (`color.primary`,
`font.body`, `space.md`), never by the platform code symbol (`AppColor.primary`, `--color-primary`).
This keeps story files platform-portable; the dev agent translates to the platform symbol at
code-write time using Section 2.2.

---

## 4. PERSONALITY DEFINITION (drives every token)

Before authoring any token, write three lines into the spec. They constrain all downstream choices.

### 4.1 — Derive design implications from the 3 mandatory persona fields

`po-backlog` produces lean personas: **JTBD + Context + Pain points** (plus optional identity). These three fields drive the design system. Do NOT invent additional persona dimensions (emotional state, demographics) that the backlog didn't capture — that's fabrication.

| Persona field | What it shapes in the design system |
|---|---|
| **Jobs-to-be-done** | Which component conventions to polish first (e.g. JTBD "log quickly" → input-heavy components prioritized); primary trait choice (efficient/calm vs. delightful/rewarding) |
| **Context of use** | Density vs breathing room, touch-target size, dark-mode emphasis, contrast floor |
| **Pain points** | Motion tone (gentle vs energetic), empty-state voice, error-message warmth |
| **Identity** (if present) | Copy register (formal vs casual), illustration style |

Write a one-line "design implication" per available persona field in the spec's Visual Personality section so downstream agents can see *why* a token choice was made.

### 4.2 — Primary Trait (pick ONE)
*Warm & encouraging* · *Clean & trustworthy* · *Bold & energetic* · *Calm & focused* ·
*Playful & rewarding* · *Premium & restrained* · *Technical & precise*

### 4.3 — Anti-Aesthetic
What this app must NOT feel like. Pick 2–3.
*Not clinical* · *Not childish* · *Not corporate* · *Not overwhelming* · *Not dated* · *Not generic*

---

## 5. PERSONALITY → PALETTE DERIVATION (rules)

Use these rules to pick a primary hue from the trait:

| Primary Trait          | Primary hue family                | Avoid                       |
|---|---|---|
| Warm & encouraging     | red-orange, amber, coral (15–40°) | cold blues, neon green      |
| Clean & trustworthy    | indigo, slate-blue (220–250°)     | hot pinks, neon             |
| Bold & energetic       | saturated red, magenta, electric blue | muted earth tones       |
| Calm & focused         | teal, sage, dusty blue (160–210°) | high-saturation warm        |
| Playful & rewarding    | coral, sunny yellow, mint (multi) | desaturated greys           |
| Premium & restrained   | near-black, deep navy, bronze accent | bright primary colors    |
| Technical & precise    | cyan, electric blue, neutral grays | warm pastels                |

Secondary color = complementary or analogous, ~30–60° hue rotation from primary. Saturation
typically 10–20 points lower than primary so it never competes for attention.

Background/surface: near-white in light mode (#F8–#FF range), near-black in dark mode
(#0E–#1C range). Never pure white or pure black — they fatigue the eye.

---

## 6. TOKEN AUTHORING RULES

### Colors
- Define semantic tokens only — never raw hex in view code.
- Every token MUST have both light and dark mode values.
- Minimum required tokens: `primary`, `primaryPressed`, `secondary`, `background`, `surface`,
  `surfaceElevated`, `onPrimary`, `onBackground`, `onSurface`, `onSurfaceMuted`, `border`,
  `borderFocus`, `error`, `warning`, `success`, `info`.
- Add domain tokens only when genuinely needed (e.g. `coinGold` for a rewards app). Justify in spec.

### Typography
- Use platform-native fonts unless brand requires custom.
  - iOS/macOS: SF Pro, SF Rounded (no licensing); SF Symbols for icons.
  - Android: Roboto, Google Sans.
  - Web: system font stack first; custom only if licensed and self-hosted.
- Minimum scale (7 levels): `displayTitle`, `largeTitle`, `title`, `headline`, `body`, `callout`, `caption`.
- Each level: family, size, weight, line height, letter spacing, usage.
- Never set fixed line height that clips Dynamic Type (iOS) or user font scaling (Android/web).

### Spacing
- Base-8 scale: 4, 8, 12, 16, 24, 32, 48, 64.
- Semantic names: `xs` (4), `sm` (8), `smd` (12), `md` (16), `lg` (24), `xl` (32), `xxl` (48), `xxxl` (64).
- Each gets a documented usage context.

### Corner Radius
- 5 levels: `none` (0), `sm` (8), `md` (14), `lg` (20), `full` (999).

### Shadow / Elevation
- 4 levels: `flat`, `card`, `sheet`, `modal`.
- Each: color, opacity, blur radius, y-offset, light & dark mode values.
- Dark mode: reduced opacity (never pure black on dark surfaces); consider an additive surface tint instead.

### Motion
- 3 timing tokens: `fast` (~0.15s), `standard` (~0.25s), `slow` (~0.4s).
- Define curves (easing or spring parameters).
- Every motion token MUST include a `Reduce Motion` alternative.

### Focus & Accessibility
- `borderFocus` token for keyboard/voice-control focus rings (3:1 against adjacent colors).
- Minimum tap target: 44×44pt (iOS) / 48×48dp (Android) / 44×44px (web touch).
- All interactive states defined: default, hover (where applicable), pressed, focused, disabled.

### Icon & Illustration
- **Icon set**: choose one (SF Symbols, Material Symbols, Lucide, etc.). Document stroke weight if applicable.
- **Icon sizes**: 16, 20, 24, 32 (semantic: `icon.sm`, `icon.md`, `icon.lg`, `icon.xl`).
- **Illustration style**: brief description + an example reference (e.g. "flat, two-tone, rounded forms").

---

## 7. CONTRAST VERIFICATION (MUST compute, not claim)

WCAG AA thresholds: **4.5:1** for body text, **3:1** for large text (≥18pt regular or ≥14pt bold)
and non-text UI components (focus rings, icons, borders).

For every text-on-background pair, compute the contrast ratio and write the actual number in
the spec table. Do not write "passes WCAG AA" without the number.

**Formula** (apply in both light and dark mode):
```
L = 0.2126·R' + 0.7152·G' + 0.0722·B'
  where each channel = if c ≤ 0.03928 then c/12.92 else ((c+0.055)/1.055)^2.4
  with c = sRGB channel / 255

ratio = (max(L1, L2) + 0.05) / (min(L1, L2) + 0.05)
```

### Show-your-work requirement (anti-fabrication)

Plausible-looking ratios are easy to fabricate. To make fabrication mechanically harder, the
spec MUST include a **derivation table** alongside the audit table, showing intermediate values
for every pair:

| Pair | FG hex | BG hex | L_fg | L_bg | Ratio | WCAG AA |
|---|---|---|---|---|---|---|
| `color.onPrimary` on `color.primary` | #FFFFFF | #2E5BFF | 1.000 | 0.097 | 7.4:1 | ✅ |

Use a Python or JavaScript one-liner to compute these (Bash tool):

```python
def lum(hex):
    def ch(c):
        c = int(hex[c:c+2], 16) / 255
        return c/12.92 if c <= 0.03928 else ((c+0.055)/1.055)**2.4
    return 0.2126*ch(1) + 0.7152*ch(3) + 0.0722*ch(5)

def ratio(a, b):
    L1, L2 = lum(a), lum(b)
    return (max(L1,L2)+0.05) / (min(L1,L2)+0.05)
```

This is REQUIRED, not optional. Self-attestation ("ratio is approximately 4.6") is forbidden.

If a pair fails AA: pick a darker/lighter variant that passes, note the original choice, and
explain the swap in the changelog.

---

## 8. OUTPUT FORMAT

Templates live as sibling files of this SKILL.md — read at write-time only, NOT inline here, to keep the upfront skill load small.

### 8.1 — `docs/design-system.md`

→ apply `templates/design-system.md`. Read it once at the end of Phase F (or when you start writing the file), substitute every bracketed placeholder, fill the Contrast Derivation table with computed values from Section 7.

### 8.2 — Platform Tokens File

Detect the platform from Section 2.2, then read **only the matching template**:

| Platform | Read this template |
|---|---|
| SwiftUI / iOS | `templates/tokens-swiftui.md` |
| Jetpack Compose | `templates/tokens-compose.md` |
| CSS / Web | `templates/tokens-css.md` |
| React Native / TS | `templates/tokens-rn-ts.md` |
| Flutter | `templates/tokens-flutter.md` |

Multi-platform projects: read each matching template and emit one file per platform. Do NOT pull templates for platforms you're not targeting — that's the point of splitting them.

**Diff verification (MANDATORY).** After emitting the tokens file, walk every hex / numeric value and verify it matches the spec's tables exactly. A tokens file that drifts from the spec is worse than no tokens file — downstream UI agents will be misled.

### 8.3 — Append to project log

After both artifacts are saved (create mode) OR after the update has been committed (update mode), **append a single line to `docs/log.md`**:

```bash
mkdir -p docs && echo "- $(date '+%Y-%m-%d %H:%M') · pd-design-foundation · v<version> · <create|update> · platform=<SwiftUI|Compose|CSS|RN|Flutter|multi> · trait=<primary-trait>" >> docs/log.md
```

For update mode, also note what changed: `... · added=<N-tokens> changed=<N-values> deprecated=<N-tokens>`.

---

## 9. UPDATING AN EXISTING DESIGN SYSTEM

If `docs/design-system.md` already exists, you are in **update mode**:

1. Read it fully. Read the tokens code file too.
2. Add new tokens; do NOT silently change existing values.
3. To change an existing token value:
   - Add a **Migration Notes** section to the changelog entry listing every consumer that may
     need to update (use `codebase-scanner` to find references).
   - Mark the old value as `[DEPRECATED → replacement]` instead of deleting; remove only after
     one full feature cycle.
4. Always increment the version (semver: token rename = major, addition = minor, value tweak = patch).
5. After saving, summarize for the user: what was added, what changed, what to migrate.

---

## 10. WORKING PRINCIPLES (non-negotiable)

- Read PO output before choosing any color or font — persona drives every decision.
- Contrast ratios MUST be computed and written as numbers — never claim WCAG AA without the ratio.
- Both artifacts (markdown spec + tokens code file) MUST ship together. Spec without code = skill failure.
- Timeless base + one distinctive accent; no trendy palettes that date in 12 months.
- Honor founder aesthetic preferences, but flag anything that fails contrast or accessibility.

---

## 11. QUALITY CHECKLIST (before saving)

- [ ] Personality block filled (emotion, primary trait, anti-aesthetic)
- [ ] Brownfield scan run and findings recorded (or marked greenfield)
- [ ] All 16 minimum color tokens defined with both light & dark values
- [ ] Contrast Audit table has computed numeric ratios for every text/background pair
- [ ] All 7 typography levels defined (family, size, weight, line height, letter spacing, usage)
- [ ] Spacing (8), radius (5), shadow (4), motion (3) tables complete
- [ ] Focus state token (`color.borderFocus`) defined and contrast-verified
- [ ] Icon set chosen + 4 icon sizes defined; illustration style noted
- [ ] Component conventions cover: buttons, inputs, cards, navigation, modals, toasts, empty, loading
- [ ] Tokens code file emitted at the path from Section 2.2
- [ ] Every spec token appears in the code file with matching semantics
- [ ] **Diff verified:** every hex / numeric value in the tokens code file matches the spec table exactly
- [ ] Contrast verification has the **derivation table** (FG hex, BG hex, L_fg, L_bg, Ratio) — not just claimed ratios
- [ ] Brownfield conflicts (if any) resolved per Section 2.4: canonical value picked, variants recorded with `[NORMALIZED FROM:]`, migration notes added
- [ ] Persona consumption goes beyond emotion — context, JTBD, pain points each have a documented "design implication"
- [ ] Changelog entry added; version set

---

## 12. ERROR PREVENTION (non-obvious failure modes)

- PO output missing → ask for app name, persona, platform at minimum; do NOT produce a generic system.
- Custom font requested on iOS → confirm it's bundled; otherwise default to SF Pro/Rounded.
- Tempted to write `#XXXXXX` placeholders in the final output → STOP. Either fill them or flag as a
  Blocking Assumption and ask the user.
