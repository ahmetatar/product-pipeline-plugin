# Template — Web SaaS (Angular/React web + Node.js/TypeScript API)

Type template for `system-architect` Phase C–F. Read at scaffold-time. Adapt to the user's Phase B
choices.

A SaaS here is **two deployables in one monorepo**: a web client SPA (Angular or React) and a
Node.js/TypeScript API. Drop the unused app dir if the project is genuinely frontend-only or
backend-only — confirm with the user before doing so.

## Project Profile values
- **Type:** Web SaaS
- **Platform:** Web · [Angular (web) + Node.js/TS (api) | React + Vite (web) + Node.js/TS (api)]
- **Language:** TypeScript 5.x
- **Package manager:** [pnpm (default — workspaces) | npm (workspaces) | yarn]
- **Design system:** custom — pd-design-foundation writes the tokens file at the path system-architect
  records in REFERENCES (Angular: `apps/web/src/design-system/tokens.scss`; React: `apps/web/src/design-system/tokens.css` or `tokens.ts`)
- **Distribution surface:** Web host — chosen per-project by needs/cost (Vercel / Netlify / Fly.io /
  Railway / AWS / …). CI stays host-agnostic; the deploy step is a USER CUSTOM block.
- **CI/CD target:** saas-cloud

## Open choices (Phase B)
- **Frontend framework (ask):** Angular (CLI, opinionated, batteries-included) vs React + Vite (SPA).
- **Backend:** plain Node.js + TypeScript service — no opinionated framework (no NestJS). The HTTP
  layer is a library choice: Express (default, ubiquitous) vs Fastify (faster) vs native `node:http`.
- **Package manager:** pnpm (default — workspaces) vs npm (workspaces) vs yarn.
- **Database / ORM (ask — a SaaS almost always needs one):** Postgres + Prisma (default) · Postgres
  + Drizzle · SQLite + Prisma (prototype/dev only). Pick `none` ONLY if the backlog truly needs no
  persistence — confirm that explicitly with the user before skipping.
- **Test runner:** Vitest (default for React+Vite and the API) · Angular uses its own (Karma/Jasmine,
  or Jest via `@angular-builders/jest`). Whatever is chosen, its CI form must be non-interactive
  (headless, no watch) — record that exact command in REFERENCES.

## Canonical folder structure (monorepo)
```
apps/
  web/                  — frontend SPA
    src/                — Angular: src/app/ feature modules · React: src/features/ feature folders
    src/design-system/  — tokens (pd-design-foundation) + UI primitives
  api/                  — Node.js + TypeScript backend
    src/
      routes/           — one folder/router per feature (auth/, billing/, …)
      services/         — domain logic, data access
    prisma/             — schema.prisma + migrations (if Prisma) · or src/db/ (Drizzle)
packages/               — shared TS used by both (API types, validation schemas) — optional
package.json            — workspace root  ·  pnpm-workspace.yaml (or workspaces field)
```

## Scaffold (Phase C)
```bash
# workspace root (pnpm default):
pnpm init && printf 'packages:\n  - "apps/*"\n  - "packages/*"\n' > pnpm-workspace.yaml
mkdir -p apps packages

# --- frontend (pick one) ---
# Angular:
pnpm dlx @angular/cli@latest new web --directory apps/web --routing --style scss --skip-git --package-manager pnpm
# React + Vite:
pnpm create vite@latest apps/web -- --template react-ts

# --- backend: plain Node.js + TypeScript ---
mkdir -p apps/api/src && cd apps/api && pnpm init
pnpm add express                                    # or: fastify  (HTTP library — pick one)
pnpm add -D typescript tsx @types/node @types/express   # @types/express only if using express
npx tsc --init
# add scripts to apps/api/package.json:
#   "build": "tsc"   ·   "dev": "tsx watch src/index.ts"   ·   "start": "node dist/index.js"   ·   "test": "vitest run"
cd ../..

# --- database (if chosen — Prisma + Postgres default), inside the API app ---
cd apps/api && pnpm add @prisma/client && pnpm add -D prisma
pnpm prisma init --datasource-provider postgresql   # writes apps/api/prisma/schema.prisma + DATABASE_URL to .env
# define the backlog's initial model(s) in prisma/schema.prisma, then:
pnpm prisma generate

# --- shared root tooling ---
pnpm add -D -w prettier
```
- Each app keeps its own `build`/`test`/`lint`/`typecheck` scripts; add root scripts that fan out
  (`pnpm -r <script>`) so CI runs one command across both apps.
- `.gitignore`: `node_modules/`, `dist/`, `.env*`, framework caches (`.angular/`, `.vite/`). Put the
  real `DATABASE_URL` in the gitignored `.env`; a placeholder line goes in `.env.example` (SKILL Phase C).

## Commands to verify (Phase D) — run each, capture final line
CI uses the recursive (all-workspace) forms; record THOSE as the Verified Commands. Per-app
`--filter` forms are for local dev.
- Build:     `pnpm -r build`                 (per-app: `pnpm --filter web build` / `--filter api build`)
- Test:      `pnpm -r test`                  (a fresh app may have 0 tests — acceptable; Angular must run headless/no-watch)
- Typecheck: `pnpm -r exec tsc --noEmit`
- Lint:      `pnpm -r lint`
- Format:    `pnpm prettier --check .`
- DB schema: `pnpm --filter api exec prisma generate`   (record only if a DB was chosen)
- Dev/run:   `pnpm --filter web dev` · `pnpm --filter api dev`   (local only)

## Conventions to record
- One folder per feature: `apps/web/src/app/<feature>` (Angular) / `apps/web/src/features/<feature>`
  (React); `apps/api/src/routes/<feature>`.
- Frontend never imports backend internals — they talk over the API contract; shared types live in `packages/`.
- Data access goes through `apps/api/src/services` / the DB client only — no raw queries in route handlers.
- No raw hex/px in components — use `apps/web/src/design-system` tokens (after pd-design-foundation runs).
