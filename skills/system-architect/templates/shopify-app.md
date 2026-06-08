# Template — Shopify app (React Router 7 + Polaris)

Type template for `system-architect` Phase C–F. Read at scaffold-time. Adapt to the user's Phase B
choices.

> **Framework note (verified 2026-05):** Shopify's official app framework is now **React Router 7**.
> Remix and React Router merged at React Router v7, and Shopify's Remix template is in maintenance —
> its README says: *"Remix is now React Router … For new projects, use the Shopify App Template -
> React Router instead."* So **new** apps use React Router 7 (`@shopify/shopify-app-react-router`).
> Only choose Remix when extending a pre-existing Remix app.

## Project Profile values
- **Type:** Shopify app
- **Platform:** Shopify embedded · React Router 7 (official `shopify-app-template-react-router`)
- **Language:** TypeScript
- **Package manager:** npm (Shopify CLI default; pnpm/yarn also supported)
- **Design system:** **Polaris (Shopify)** — embedded apps MUST use Polaris (web components) + App
  Bridge. pd-design-foundation ADOPTS Polaris (it does not invent a bespoke palette). Record this clearly.
- **Distribution surface:** Shopify App Store / Partner Dashboard (review + listing)
- **CI/CD target:** shopify

## Open choices (Phase B)
- **Framework:** **React Router 7 (default — official for new apps)** vs Remix (legacy; only for an
  existing Remix codebase). Do not start a new app on Remix.
- **Database:** Prisma + SQLite (template default, fine for dev) vs Postgres (for production).
- **Package manager:** npm (default) vs pnpm.
- **Extensions needed?** theme app extension / checkout UI / admin action — scaffold an `extensions/`
  folder only if the backlog implies them.

## Canonical folder structure
The React Router template is a fork of the old Remix template, so the shape is the same.
```
app/                  — React Router app
  app/routes/         — routes incl. auth/* , webhooks/* , app/* (embedded admin)
  app/components/     — Polaris-based UI components
  app/services/       — domain logic, Shopify Admin API clients
  app/models/         — data models (Prisma-backed)
  app/db.server.ts    — Prisma client
prisma/               — schema.prisma + migrations
extensions/           — Shopify extensions (only if needed)
shopify.app.toml      — app config (scopes, webhooks, app URL)
tests/                — unit/integration tests
```

## Scaffold (Phase C)
```bash
# Official React Router 7 template — you MUST pass --template (bare `shopify app init` may still
# scaffold the legacy Remix template):
shopify app init --template=https://github.com/Shopify/shopify-app-template-react-router
# the template already includes: React Router 7, Polaris, App Bridge, Prisma, ESLint, Prettier, a Dockerfile
mkdir -p app/services app/models tests
```
- The template ships `package.json` scripts (`build`, `dev`, `lint`, `setup`/`prisma`), a
  `.gitignore`, and a `Dockerfile`. Do NOT re-init those.
- `shopify app dev` requires a Partner account + a dev store; note this in the hand-off (the user
  must run `shopify app config link` / log in — suggest they do it via `! shopify auth login`).
- **REST is removed from `@shopify/shopify-app-react-router`** — use the GraphQL Admin API. Don't
  scaffold REST helpers.
- Non-embedded (separate-tab) apps are **not supported** by the React Router package; this template
  assumes an embedded app.

## Commands to verify (Phase D) — run each, capture final line
- Build:     `npm run build`
- Typecheck: `npm run typecheck`  (or `npx tsc --noEmit` if no script)
- Lint:      `npm run lint`
- Format:    `npx prettier --check .`
- Prisma:    `npx prisma generate`  (confirms schema is valid)
- Dev/run:   `shopify app dev`       (local only; needs Partner auth — not a CI command)
- Deploy:    `shopify app deploy`    (record for devops; pushes extensions/config to Shopify)

## Conventions to record
- **UI is Polaris (web components) + App Bridge.** No bespoke design tokens — pd-design-foundation
  records Polaris adoption rather than authoring a palette.
- **Admin API is GraphQL** (REST is removed from the React Router package); use the template's
  authenticated GraphQL client. Never hardcode access tokens.
- Webhooks + OAuth live under `app/routes/`; respect the template's session storage.
- Required scopes and webhooks are declared in `shopify.app.toml` — treat it as a contract.
