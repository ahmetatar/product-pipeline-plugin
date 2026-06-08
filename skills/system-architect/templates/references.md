# Template — `docs/REFERENCES.md`

Apply this template literally in Phase F. Replace bracketed placeholders with the structure you
actually scaffolded and the commands you actually ran in Phase D. Headings are a contract —
downstream skills (`ba-feature-analyst`, `dev-story-implementer`, `devops-ci-architect`) grep
`## Folder Map`, `## Key Files`, `## Verified Commands`, `## Conventions`. Do not rename them.

````markdown
# Project References
**Last Updated:** [YYYY-MM-DD]  ·  **Established by:** system-architect  ·  **Type:** [iOS app | Web SaaS | Shopify app | other]

## Folder Map
[The canonical structure you created. One line per folder, with its role. Example — replace with
the real layout from the type template you used.]
- `[root]/` — application code
  - `[root]/Features/` (or `src/features/`, `app/routes/`) — feature modules, one folder per feature
  - `[root]/Services/` — networking, persistence, domain services
  - `[root]/DesignSystem/` — design tokens + shared UI (pd-design-foundation writes the tokens file here)
- `Tests/` (or `tests/`) — test suites mirroring the source structure
- `docs/` — product / design / feature docs

## Key Files
- `[manifest]` — [`Package.swift` | `package.json` | `shopify.app.toml` + `package.json`]
- `[entry point]` — [app entry / root route]
- `[design-system tokens path]` — written by pd-design-foundation; imported by all UI
- `.env.example` — names of required env vars / secrets (no real values); local `.env` is gitignored, CI injects via secrets
- `CLAUDE.md` — Project Profile + conventions

## Verified Commands
[ONLY commands you actually ran in Phase D. Each line: the command + the final output line proving
it ran. Example shapes — replace with the real stack.]
- Build:      `[cmd]`   → `[final output line]`
- Test:       `[cmd]`   → `[final output line]`
- Typecheck:  `[cmd]`   → `[final output line]`
- Lint:       `[cmd]`   → `[final output line]`
- Format:     `[cmd]`
- Dev/run:    `[cmd]`   (local only; not used in CI verification)

## Conventions (one-liners; detail in CLAUDE.md)
- [Feature code lives in … , one module per feature]
- [View / component file suffix rule]
- [Where shared services / models live]
- [...]
````

Update rule (for downstream skills): a story that adds a new top-level directory, a new convention,
or a new command MUST include `docs/REFERENCES.md [MODIFY]` in its Touch Points. The change is part
of that story's acceptance.
