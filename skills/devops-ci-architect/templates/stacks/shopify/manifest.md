# Stack manifest — Shopify app  (target id: `shopify`)

The contract `devops-ci-architect` reads for Shopify. Skill body is stack-agnostic; everything
Shopify-specific is here. Schema: `templates/new-stack/manifest.md`.

## Applies when
- Project Profile `CI/CD target: shopify`
- Detection fallback: `shopify.app.toml` present.

## Runner
- `ubuntu-latest`.

## Workflow roles
Plus the universal `auto-pr.yml` + `set-project-status.sh` (written by the skill from `shared/`).

| Role | Repo path | Trigger | Purpose |
|---|---|---|---|
| ci | `.github/workflows/ci.yml` | PR + push to `main` + push to `feat/**` | install · lint · typecheck · build · test. The merge gate. No deploy. |
| in-test | `.github/workflows/in-test.yml` | `workflow_run` of CI = success, on a `feat/**` branch | deploy an UNRELEASED app version (`--no-release`) to preview in the dev store, then board → In-Test |
| release | `.github/workflows/release.yml` | push to `main` (ignores `docs/**`) | `shopify app deploy` (release the version live) + USER-CUSTOM host deploy |

Template files: `workflows/{ci,in-test,release}.yml` (siblings of this manifest).

## Support files
- none. `shopify.app.toml`, `package.json`, `prisma/` already live in the repo (system-architect).
- `.gitignore` additions: none.

## Placeholders
| Placeholder | Filled from |
|---|---|
| `<NODE_VERSION>` | auto-extract — or `lts/*` |
| `<PM_CACHE>` | `npm` / `pnpm` / `yarn` (setup-node cache) |
| `<PM_INSTALL>` | `npm ci` / `pnpm i --frozen-lockfile` / `yarn install --frozen-lockfile` |
| `<BUILD_COMMAND>` | Verified Commands → Build |
| `<TEST_COMMAND>` | Verified Commands → Test (none → `echo "no tests"` and warn) |
| `<LINT_COMMAND>` | Verified Commands → Lint |
| `<TYPECHECK_COMMAND>` | Verified Commands → Typecheck |

## Auto-extract
```bash
if [ -f pnpm-lock.yaml ]; then PM=pnpm; PM_INSTALL="pnpm i --frozen-lockfile"; PM_CACHE=pnpm;
elif [ -f yarn.lock ]; then PM=yarn; PM_INSTALL="yarn install --frozen-lockfile"; PM_CACHE=yarn;
else PM=npm; PM_INSTALL="npm ci"; PM_CACHE=npm; fi
if [ -f .nvmrc ]; then NODE_VERSION=$(cat .nvmrc | tr -d ' v\n'); \
else NODE_VERSION=$(jq -r '.engines.node // "lts/*"' package.json 2>/dev/null); fi
APP_NAME=$(grep -E '^name' shopify.app.toml 2>/dev/null | head -1 | awk -F'=' '{print $2}' | tr -d ' "')
```
Phase B: confirm package manager + Node version + that `shopify.app.toml` has the right client_id/scopes.

## Secrets (Phase E — after the universal `PROJECTS_TOKEN` + `PROJECT_NUMBER`)
| Name | Source / how user obtains | How skill sets it | Agent-generated? |
|---|---|---|---|
| `SHOPIFY_CLI_PARTNERS_TOKEN` | Partner Dashboard → your account → **CLI token**. https://shopify.dev/docs/apps/launch/deployment/deploy-command#automate-deployment-with-a-cicd-pipeline | `printf '%s' "<TOKEN>" \| gh secret set SHOPIFY_CLI_PARTNERS_TOKEN --body -` | no |
| _(optional)_ host token, e.g. `FLY_API_TOKEN` | only if you uncomment the host-deploy block in `release.yml` | `gh secret set <NAME> --body "<value>"` | no |

Verify `gh secret list` has `SHOPIFY_CLI_PARTNERS_TOKEN`. No certs, no key files.

## Local setup (Phase F — no destructive gate)
Interactive + browser-bound, so the agent does NOT run these — tell the user (suggest `! ` prefix):
```
shopify auth login
shopify app config link
```
If using a hosted DB: `npx prisma migrate deploy` (with `DATABASE_URL`) — host-specific, leave to the user.

## docs/CI.md content (Phase G)
```markdown
## CI Workflows
Pipeline: dev-story-implementer marks In-Progress at story start → push feat/** → PR opens (`auto-pr.yml`) → build+test (`ci.yml`, the merge gate) → on green: deploy unreleased version + board In-Test (`in-test.yml`) → `/story-done` (verify green + squash-merge) → release live (`release.yml`) + board Done.

- `.github/workflows/auto-pr.yml` — push to `feat/**` · opens the PR (title + body taken from the HEAD commit, so `Closes #N` carries into the PR body even on multi-commit branches) if none is open. Board moves are not its job.
- `.github/workflows/ci.yml` — every PR + push to main + push to `feat/**` · install + lint + typecheck + build + tests. **No deploy.** Required check for merge.
- `.github/workflows/in-test.yml` — runs when CI succeeds on a `feat/**` branch · `shopify app deploy --no-release` (unreleased preview in the dev store) · then board → In-Test.
- `.github/workflows/release.yml` — push to `main` (ignores `docs/**`), i.e. when `/story-done` squash-merges the PR · `shopify app deploy` (releases the version live); web host deploy is in the USER CUSTOM block.
- `.github/scripts/set-project-status.sh` — board helper used by the workflows (needs `PROJECTS_TOKEN` secret + `PROJECT_NUMBER` variable).

**Shopify app:** `<APP_NAME>`
**Secrets reference:** `docs/SECRETS.md`
```

## Hand-off notes
- `in-test.yml` deploys with `--no-release` → testable in the dev store, NOT live to merchants.
- `release.yml` runs `shopify app deploy` on merge but the **web server deploy is commented out** — wire your host in the USER CUSTOM block.
- If Local setup was skipped: `shopify auth login` + `shopify app config link` and set `SHOPIFY_CLI_PARTNERS_TOKEN` before the first deploy, or CI fails at the deploy step.
