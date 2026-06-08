# Stack manifest — Web SaaS (cloud)  (target id: `saas-cloud`)

The contract `devops-ci-architect` reads for a Web SaaS monorepo (Angular/React web + Node.js/TS
API). Skill body is stack-agnostic; everything SaaS-specific is here. Schema:
`templates/new-stack/manifest.md`.

**Host-agnostic by design.** The host (Vercel / Netlify / Fly.io / Railway / AWS / …) is chosen
per-project by needs and cost, so CI never hardcodes one — the deploy step lives in `release.yml`'s
USER CUSTOM block. CI runs build + test + the board moves regardless of host.

## Applies when
- Project Profile `CI/CD target: saas-cloud`
- Detection fallback: `pnpm-workspace.yaml` OR a `package.json` with `workspaces`, alongside `apps/web`
  and/or `apps/api` — and NO `shopify.app.toml` (that's the `shopify` stack).

## Runner
- `ubuntu-latest`.

## Workflow roles
Plus the universal `auto-pr.yml` + `set-project-status.sh` (skill writes them from `shared/`).

| Role | Repo path | Trigger | Purpose |
|---|---|---|---|
| ci | `.github/workflows/ci.yml` | PR + push to `main` + push to `feat/**` | install · lint · typecheck · build · test (recursive across workspaces). The merge gate. No deploy. |
| in-test | `.github/workflows/in-test.yml` | `workflow_run` of CI = success, on a `feat/**` branch | board → In-Test. No deploy by default (host-agnostic); optional per-branch preview lives in a USER CUSTOM block. |
| release | `.github/workflows/release.yml` | push to `main` (ignores `docs/**`) | build · run DB migrations (if `DATABASE_URL` set) · USER-CUSTOM host deploy · board → Done |

Template files: `workflows/{ci,in-test,release}.yml` (siblings of this manifest).

## Support files
- none. `package.json`, `pnpm-workspace.yaml`, `apps/`, `prisma/` already live in the repo (system-architect).
- `.gitignore` additions: none (system-architect already covers `node_modules/`, `dist/`, `.env*`, framework caches).

## Placeholders
| Placeholder | Filled from |
|---|---|
| `<NODE_VERSION>` | auto-extract (`.nvmrc` / `.tool-versions` / `package.json` engines) — or `lts/*` |
| `<PM_CACHE>` | `npm` / `pnpm` / `yarn` (setup-node cache) |
| `<PM_INSTALL>` | `npm ci` / `pnpm i --frozen-lockfile` / `yarn install --frozen-lockfile` |
| `<BUILD_COMMAND>` | Verified Commands → Build (recursive form, e.g. `pnpm -r build`) |
| `<TEST_COMMAND>` | Verified Commands → Test (recursive; none → `echo "no tests"` and warn) |
| `<LINT_COMMAND>` | Verified Commands → Lint |
| `<TYPECHECK_COMMAND>` | Verified Commands → Typecheck |

> Use the **recursive (all-workspace)** command forms from REFERENCES (`pnpm -r …` / `npm run -ws …` /
> `yarn workspaces foreach -A run …`), so one CI step covers both `apps/web` and `apps/api`. If the
> Verified Commands list only per-app `--filter` forms, ask the user for / derive the recursive form.

## Auto-extract
```bash
if [ -f pnpm-lock.yaml ]; then PM=pnpm; PM_INSTALL="pnpm i --frozen-lockfile"; PM_CACHE=pnpm;
elif [ -f yarn.lock ]; then PM=yarn; PM_INSTALL="yarn install --frozen-lockfile"; PM_CACHE=yarn;
else PM=npm; PM_INSTALL="npm ci"; PM_CACHE=npm; fi
if [ -f .nvmrc ]; then NODE_VERSION=$(cat .nvmrc | tr -d ' v\n');
elif [ -f .tool-versions ]; then NODE_VERSION=$(awk '/^nodejs/{print $2}' .tool-versions);
else NODE_VERSION=$(jq -r '.engines.node // "lts/*"' package.json 2>/dev/null); fi
HAS_PRISMA=$([ -f apps/api/prisma/schema.prisma ] && echo yes || echo no)
```
Phase B: confirm package manager + Node version + the recursive build/test/lint/typecheck commands.
If `HAS_PRISMA=yes`, note that `release.yml` will run `prisma migrate deploy` once `DATABASE_URL` is set.

## Secrets (Phase E — after the universal `PROJECTS_TOKEN` + `PROJECT_NUMBER`)
This stack ships no host coupling, so it has no mandatory stack secret. Two optional ones:

| Name | Source / how user obtains | How skill sets it | Agent-generated? |
|---|---|---|---|
| _(optional)_ `DATABASE_URL` | the production DB connection string (Neon / Supabase / RDS / your Postgres). Enables `prisma migrate deploy` on release. | `printf '%s' "<URL>" \| gh secret set DATABASE_URL --body -` | no |
| _(optional)_ host token, e.g. `VERCEL_TOKEN` / `FLY_API_TOKEN` / `RAILWAY_TOKEN` | only if you fill the host-deploy block in `release.yml` (or a preview deploy in `in-test.yml`) | `gh secret set <NAME> --body "<value>"` | no |

If the user hasn't chosen a host yet, set neither now — `release.yml` skips migrations (no
`DATABASE_URL`) and the deploy block stays commented; CI + board moves still work. Verify `gh secret list`.

## Local setup (Phase F — no destructive gate)
- `none` mandatory. Host setup (CLI login, linking the project, provisioning the DB) is host-specific
  and per-project — leave it to the user when they pick a host. If a DB is already provisioned, the
  user runs `(cd apps/api && npx prisma migrate deploy)` against it once before/with the first release
  (or sets `DATABASE_URL` and lets `release.yml` do it).

## docs/CI.md content (Phase G)
```markdown
## CI Workflows
Pipeline: dev-story-implementer marks In-Progress at story start → push feat/** → PR opens (`auto-pr.yml`) → lint+typecheck+build+test (`ci.yml`, the merge gate) → on green: board In-Test (`in-test.yml`) → `/story-done` (verify green + squash-merge) → build+migrate+deploy (`release.yml`) + board Done.

This stack is **host-agnostic** — the host deploy is a USER CUSTOM block in `release.yml`, filled when you pick a host (Vercel / Netlify / Fly.io / Railway / AWS / …).

- `.github/workflows/auto-pr.yml` — push to `feat/**` · opens the PR (`gh pr create --fill`, so `Closes #N` carries into the PR body) if none is open. Board moves are not its job.
- `.github/workflows/ci.yml` — every PR + push to main + push to `feat/**` · install + lint + typecheck + build + tests across both workspaces. **No deploy.** Required check for merge.
- `.github/workflows/in-test.yml` — runs when CI succeeds on a `feat/**` branch · board → In-Test. No deploy by default; add a per-branch preview in its USER CUSTOM block if you run one.
- `.github/workflows/release.yml` — push to `main` (ignores `docs/**`), i.e. when `/story-done` squash-merges · build → `prisma migrate deploy` (if `DATABASE_URL` set) → host deploy (USER CUSTOM) → board → Done.
- `.github/scripts/set-project-status.sh` — board helper used by the workflows (needs `PROJECTS_TOKEN` secret + `PROJECT_NUMBER` variable).

**Host:** chosen per-project — wire it in `release.yml`'s USER CUSTOM block.
**Secrets reference:** `docs/SECRETS.md`
```

## Hand-off notes
- **Host-agnostic.** CI, board moves, build/test, and DB migrations are wired; the actual host deploy
  is the commented USER CUSTOM block in `release.yml` — fill it (and set the host token secret) when
  you choose a host. Until then merges build + migrate + move the board to Done but deploy nothing.
- **DB migrations** run on release only when the `DATABASE_URL` secret is set and a Prisma schema
  exists. Drizzle: swap `prisma migrate deploy` for your migrate command in `release.yml`.
- **Optional preview environments** (per-branch) go in `in-test.yml`'s USER CUSTOM block; the board
  move runs whether or not you add one.
- If the recursive workspace commands aren't in REFERENCES yet, add them — CI runs one command across
  `apps/web` + `apps/api`, not per-app.
```
