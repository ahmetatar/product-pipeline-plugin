# Template — `docs/design-system.md`

Apply this template literally when writing the spec. Replace bracketed placeholders. Every numeric field MUST be a concrete value — no `#XXXXXX` placeholders in the final saved file.

````markdown
# Design System
**App:** [App Name]
**Platform(s):** [iOS / Android / Web / ...]
**Tokens file(s):** [path(s) — see SKILL.md Section 2.2]
**Last Updated:** [YYYY-MM-DD]
**Version:** 1.0

---

## Visual Personality
**Primary persona:** [[P1]] (and [[P2]] if backlog defines a second)
**Primary trait:** [one trait from SKILL.md Section 4.2]
**Anti-aesthetic:** [2–3 items]

**Design implications** (one line per available persona field — see SKILL.md §4.1):
- JTBD → ...
- Context → ...
- Pain points → ...
- Identity (if given) → ...

[One paragraph brief for a designer joining day one.]

---

## Existing Tokens Reused (brownfield only)
[Bullet list of colors/fonts/spacing values found by codebase-scanner that are preserved.]

---

## Colors

### Semantic Tokens
| Token | Light | Dark | Usage |
|---|---|---|---|
| `color.primary` | #XXXXXX | #XXXXXX | Primary CTAs, key highlights |
| `color.primaryPressed` | #XXXXXX | #XXXXXX | Pressed state of primary |
| `color.secondary` | #XXXXXX | #XXXXXX | Secondary actions, accents |
| `color.background` | #XXXXXX | #XXXXXX | Screen backgrounds |
| `color.surface` | #XXXXXX | #XXXXXX | Cards, sheets |
| `color.surfaceElevated` | #XXXXXX | #XXXXXX | Modals, popovers |
| `color.onPrimary` | #XXXXXX | #XXXXXX | Text/icons on primary |
| `color.onBackground` | #XXXXXX | #XXXXXX | Body text on background |
| `color.onSurface` | #XXXXXX | #XXXXXX | Body text on surface |
| `color.onSurfaceMuted` | #XXXXXX | #XXXXXX | Secondary/disabled text |
| `color.border` | #XXXXXX | #XXXXXX | Dividers, outlines |
| `color.borderFocus` | #XXXXXX | #XXXXXX | Focus ring |
| `color.error` | #XXXXXX | #XXXXXX | Errors, destructive |
| `color.warning` | #XXXXXX | #XXXXXX | Caution states |
| `color.success` | #XXXXXX | #XXXXXX | Confirmations |
| `color.info` | #XXXXXX | #XXXXXX | Informational accents |

### Contrast Audit (computed ratios)
| Foreground | Background | Light ratio | Dark ratio | WCAG AA |
|---|---|---|---|---|
| `color.onPrimary` | `color.primary` | X.X:1 | X.X:1 | ✅ / ❌ |
| `color.onBackground` | `color.background` | X.X:1 | X.X:1 | ✅ / ❌ |
| `color.onSurface` | `color.surface` | X.X:1 | X.X:1 | ✅ / ❌ |
| `color.borderFocus` | `color.background` | X.X:1 | X.X:1 | ✅ / ❌ |

### Contrast Derivation (show-your-work — required, see SKILL.md §7)
| Pair | FG hex | BG hex | L_fg | L_bg | Ratio | WCAG AA |
|---|---|---|---|---|---|---|
| `color.onPrimary` on `color.primary` (light) | #FFFFFF | #2E5BFF | 1.000 | 0.097 | 7.4:1 | ✅ |

---

## Typography
| Token | Family | Size | Weight | Line Height | Letter Spacing | Usage |
|---|---|---|---|---|---|---|
| `font.displayTitle` | ... | 36 | Bold | 42 | -0.5 | Hero titles |
| `font.largeTitle` | ... | 28 | Bold | 34 | -0.3 | Screen titles |
| `font.title` | ... | 22 | Semibold | 28 | 0 | Section headers |
| `font.headline` | ... | 17 | Semibold | 22 | 0 | Card titles |
| `font.body` | ... | 17 | Regular | 24 | 0 | Body text |
| `font.callout` | ... | 15 | Regular | 22 | 0 | Secondary body |
| `font.caption` | ... | 13 | Regular | 18 | 0.2 | Labels, hints |

---

## Spacing
| Token | Value | Usage |
|---|---|---|
| `space.xs` | 4 | Tight icon-to-label gaps |
| `space.sm` | 8 | Internal component padding |
| `space.smd` | 12 | Loose internal padding |
| `space.md` | 16 | Standard screen padding |
| `space.lg` | 24 | Between sections |
| `space.xl` | 32 | Section breaks |
| `space.xxl` | 48 | Hero breathing room |
| `space.xxxl` | 64 | Top-of-screen headroom |

---

## Corner Radius
| Token | Value | Usage |
|---|---|---|
| `radius.none` | 0 | Edge-to-edge surfaces |
| `radius.sm` | 8 | Tags, chips |
| `radius.md` | 14 | Cards, inputs |
| `radius.lg` | 20 | Sheets, large modals |
| `radius.full` | 999 | Pills, avatars |

---

## Elevation & Shadow
| Token | Light | Dark | Usage |
|---|---|---|---|
| `shadow.flat` | none | none | No lift |
| `shadow.card` | black 8% / r8 / y2 | black 24% / r8 / y2 | Card lift |
| `shadow.sheet` | black 14% / r20 / y-4 | black 32% / r20 / y-4 | Bottom sheet |
| `shadow.modal` | black 22% / r30 / y-8 | black 40% / r30 / y-8 | Full modal |

---

## Motion
| Token | Duration | Curve | Reduce Motion Alt | Usage |
|---|---|---|---|---|
| `motion.fast` | 0.15s | easeOut | instant | Button press, toggle |
| `motion.standard` | 0.25s | easeInOut | crossfade | Screen transitions |
| `motion.slow` | 0.4s | spring(0.4, 0.7) | standard | Modal present |

---

## Icons & Illustration
- **Icon set:** [SF Symbols / Material Symbols / Lucide / custom]
- **Icon sizes:** `icon.sm` 16 · `icon.md` 20 · `icon.lg` 24 · `icon.xl` 32
- **Illustration style:** [description + reference]

---

## Component Conventions

### Buttons
| Variant | Background | Text | Border | Radius | Min height |
|---|---|---|---|---|---|
| primary | `color.primary` | `color.onPrimary` | none | `radius.full` | 56 (CTA) / 44 (inline) |
| secondary | transparent | `color.primary` | 1pt `color.primary` | `radius.full` | 56 / 44 |
| destructive | `color.error` | `color.onPrimary` | none | `radius.full` | 56 / 44 |
| ghost | transparent | `color.primary` | none | `radius.full` | 44 |

States required for each: default, pressed, focused, disabled.

### Inputs
- Height: 48 (single line) / 96 (multi-line min).
- Padding: `space.md` horizontal.
- Border: 1pt `color.border`; focus → 2pt `color.borderFocus`.
- Error: 1pt `color.error` + helper text below in `font.caption` / `color.error`.

### Cards
- Background: `color.surface` · Radius: `radius.md` · Shadow: `shadow.card` · Padding: `space.md`.

### Navigation
- **Top bar:** height 44 (iOS) / 56 (Android/web); title `font.headline`; back affordance per platform.
- **Tab bar:** height 49 (iOS) / 80 (Android); icon `icon.md` + label `font.caption`.

### Modals & Sheets
- Sheet corner radius: `radius.lg` top corners only.
- Backdrop scrim: `color.onBackground` at 40% opacity.

### Toasts / Snackbars
- Duration: 4s default; persistent for errors that need action.
- Background: `color.surfaceElevated`; text `color.onSurface`; left accent bar in semantic color.

### Empty State
- Illustration (decorative, accessibilityHidden).
- Title `font.title` / `color.onBackground`; body `font.body` / `color.onSurfaceMuted`.
- CTA: primary button if action exists; none if informational.

### Loading
- **Skeleton** for known layouts: surface `color.surface`, animated shimmer `color.onSurfaceMuted` at 12%.
- **Spinner** for unknown durations only.

---

## Usage Rules (for UX & UI Agents)

1. NEVER use raw hex, raw font names, or raw px/pt in view code — always reference a token.
2. NEVER create new tokens without first adding them to this file and the tokens code file.
3. Import the tokens code file (SKILL.md Section 2.2) directly in code; this markdown is for humans/reviewers.
4. Dark mode: every color token MUST have both values; verify contrast in both modes.
5. Touch targets: ≥44×44pt (iOS) / ≥48×48dp (Android) / ≥44×44px (web touch).
6. Reduce Motion: every non-trivial animation must check the system flag and use the alt.

---

## Changelog
| Version | Date | Changes |
|---|---|---|
| 1.0 | [YYYY-MM-DD] | Initial design system established |
````
