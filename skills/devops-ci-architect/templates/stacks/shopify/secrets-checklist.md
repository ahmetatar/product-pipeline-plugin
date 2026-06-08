# CI/CD Secrets — Shopify app

What the workflows need, how to set it, and how to fix CI when it breaks. `devops-ci-architect`
Phase E sets these interactively; this doc is the reference for renewals and troubleshooting.

## Verify

```bash
gh secret list        # PROJECTS_TOKEN, SHOPIFY_CLI_PARTNERS_TOKEN
gh variable list      # PROJECT_NUMBER
```

## Secrets + variable

### `PROJECTS_TOKEN` + `PROJECT_NUMBER` (In-Test board move — used by every stack)
Lets `in-test.yml` move the GitHub Project item to In-Test when CI goes green. Without them the
workflow still runs; it just skips the board step. (In-Progress is set client-side by
`dev-story-implementer`, so it doesn't need these.) `auto-pr.yml` also prefers this PAT to open the
PR — a PR opened by the default `GITHUB_TOKEN` is blocked by the org "Actions can create PRs" setting
and its `Closes #N` never links to the issue; the PAT's `repo` scope avoids both. If `PROJECTS_TOKEN`
is unset, `auto-pr.yml` falls back to `GITHUB_TOKEN`.

1. Create a PAT with `repo` + `project` scope: https://github.com/settings/tokens/new?scopes=repo,project
2. ```bash
   gh secret set PROJECTS_TOKEN --body "<PAT>"
   gh variable set PROJECT_NUMBER --body "<number from your project URL, e.g. 7>"
   ```

### `SHOPIFY_CLI_PARTNERS_TOKEN` (deploy)
`shopify app deploy` in CI authenticates with this instead of an interactive login.

1. Partner Dashboard → your account → create a **CLI token**.
   https://shopify.dev/docs/apps/launch/deployment/deploy-command#automate-deployment-with-a-cicd-pipeline
2. ```bash
   printf '%s' "<TOKEN>" | gh secret set SHOPIFY_CLI_PARTNERS_TOKEN --body -
   ```

### Link the app locally (one-time, you do this — not the agent)
```bash
shopify auth login
shopify app config link     # writes/confirms shopify.app.toml
```

### (optional) host deploy secret
Only if you uncommented the host-deploy block in `release.yml`:
```bash
gh secret set FLY_API_TOKEN --body "<token>"   # or VERCEL_TOKEN, etc.
```

## Renewal
- Token revoked/expired → regenerate it, re-run its `gh secret set`, revoke the old one.

## Troubleshooting
| CI error | Likely cause | Fix |
|---|---|---|
| `shopify app deploy` → 401 / not authenticated | `SHOPIFY_CLI_PARTNERS_TOKEN` missing/expired | Re-create the token, re-set the secret |
| `No app found` | `shopify.app.toml` client_id wrong or not committed | `shopify app config link` locally, commit it |
| Board not moving | `PROJECTS_TOKEN` lacks `project` scope, or `PROJECT_NUMBER` wrong | Re-create PAT with `repo`+`project`; check the variable |
| `prisma generate` fails | schema missing/invalid | `npx prisma validate` locally; confirm it's committed |
