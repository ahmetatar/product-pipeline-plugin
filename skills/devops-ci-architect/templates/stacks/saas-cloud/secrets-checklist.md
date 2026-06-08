# CI/CD Secrets — Web SaaS (cloud)

What the workflows need, how to set it, and how to fix CI when it breaks. `devops-ci-architect`
Phase E sets these interactively; this doc is the reference for renewals and troubleshooting.

This stack is **host-agnostic**: only the board secret is required. The DB and host secrets are
optional until you wire a database / pick a host.

## Verify

```bash
gh secret list        # PROJECTS_TOKEN  (+ DATABASE_URL / host token, if set)
gh variable list      # PROJECT_NUMBER
```

## Secrets + variable

### `PROJECTS_TOKEN` + `PROJECT_NUMBER` (board moves — required; used by every stack)
Lets `in-test.yml` / `release.yml` move the GitHub Project item (In-Test, Done) when CI goes green /
on merge. Without them the workflows still run; they just skip the board step. (In-Progress is set
client-side by `dev-story-implementer`.) `auto-pr.yml` also prefers this PAT to open the PR — a PR
opened by the default `GITHUB_TOKEN` is blocked by the org "Actions can create PRs" setting and its
`Closes #N` never links to the issue; the PAT's `repo` scope avoids both.

1. Create a PAT with `repo` + `project` scope: https://github.com/settings/tokens/new?scopes=repo,project
2. ```bash
   gh secret set PROJECTS_TOKEN --body "<PAT>"
   gh variable set PROJECT_NUMBER --body "<number from your project URL, e.g. 7>"
   ```

### `DATABASE_URL` (optional — production DB migrations)
When set, `release.yml` runs `prisma migrate deploy` against it on merge to `main`. Leave it unset
until you have a production database; releases then skip migrations.

1. Get the connection string from your DB provider (Neon / Supabase / RDS / self-hosted Postgres).
2. ```bash
   printf '%s' "<postgres://…>" | gh secret set DATABASE_URL --body -
   ```

### (optional) host deploy token
Only once you fill the host-deploy block in `release.yml` (or a preview deploy in `in-test.yml`).
Name it to match what you reference there:
```bash
gh secret set VERCEL_TOKEN --body "<token>"     # or FLY_API_TOKEN / RAILWAY_TOKEN / …
```

## Renewal
- Token revoked/expired → regenerate it, re-run its `gh secret set`, revoke the old one.
- DB rotated → update `DATABASE_URL`.

## Troubleshooting
| CI error | Likely cause | Fix |
|---|---|---|
| Board not moving | `PROJECTS_TOKEN` lacks `project` scope, or `PROJECT_NUMBER` wrong | Re-create PAT with `repo`+`project`; check the variable |
| PR not opening on push | org blocks `GITHUB_TOKEN` from creating PRs | Set `PROJECTS_TOKEN` (PAT) so `auto-pr.yml` uses it |
| `prisma migrate deploy` → can't reach DB | `DATABASE_URL` missing/wrong, or DB not reachable from Actions | Set/fix the secret; confirm the DB allows the runner's egress |
| `prisma generate` fails | schema missing/invalid | `(cd apps/api && npx prisma validate)` locally; confirm it's committed |
| Release deploys nothing | host block still commented | Fill `release.yml`'s USER CUSTOM block + set the host token secret |
| Test step fails only in CI | Angular test not headless/no-watch | Use the CI form (e.g. `ng test --watch=false --browsers=ChromeHeadless`) in REFERENCES |
