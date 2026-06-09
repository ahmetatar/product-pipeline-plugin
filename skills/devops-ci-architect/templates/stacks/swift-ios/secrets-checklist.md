# CI/CD Secrets Guide

The credentials your CI/CD workflows need, in one place: how to create them, how to set them as GitHub secrets, how to renew them when they expire, and how to debug when CI fails.

If you ran `devops-ci-architect` Phase F+G, secrets are already set and match is initialized — this doc is your reference for renewals (12 months later, when the GitHub PAT expires) and CI troubleshooting. If you skipped Phase F, follow "Initial setup" below.

---

## Project context

- **Match storage repo:** `<MATCH_GIT_URL>`
- **Bundle ID:** `<BUNDLE_ID>`

## Quick verify

```bash
gh secret list      # PROJECTS_TOKEN + the 5 TestFlight secrets below
gh variable list    # PROJECT_NUMBER + IOS_TEST_DELIVERY
```

Expected:

- `PROJECTS_TOKEN` ← board moves (every stack). `MATCH_*` + `APP_STORE_CONNECT_*` ← TestFlight uploads: the manual `testflight.yml`, and `in-test.yml` when `IOS_TEST_DELIVERY=testflight`.
- `IOS_TEST_DELIVERY` (variable) ← `local-simulator` (default) or `testflight`. In `testflight` mode the 5 signing secrets are REQUIRED; in `local-simulator` mode they're only needed for the manual button.
- `MATCH_PASSWORD`
- `MATCH_GIT_BASIC_AUTHORIZATION`
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY`

## In-Test board move — `PROJECTS_TOKEN` + `PROJECT_NUMBER` (used by `in-test.yml`)

Lets CI move the GitHub Project item to In-Test when CI goes green. Without them `in-test.yml` still
runs; it just skips the board step. `ci.yml`, `auto-pr.yml`, and `testflight.yml` don't need them.
(In-Progress is set client-side by `dev-story-implementer`.)

1. PAT with `repo` + `project` scope: https://github.com/settings/tokens/new?scopes=repo,project
2. ```bash
   gh secret set PROJECTS_TOKEN --body "<PAT>"
   gh variable set PROJECT_NUMBER --body "<number from your project URL>"
   gh variable set IOS_TEST_DELIVERY --body "local-simulator"   # or "testflight"
   ```

**Per-PR delivery override:** add a `deliver:testflight` or `deliver:local` label to a PR to override
`IOS_TEST_DELIVERY` for that story only. In `testflight` mode `in-test.yml` uploads each green story
to TestFlight before moving the board; in `local-simulator` mode you install locally with
`scripts/run-on-sim.sh`.

---

## Initial setup (one-time, ~5 minutes)

> **Fastest path:** `bash scripts/setup-testflight.sh` — it asks for every credential below step by
> step, then in one pass creates the match repo, sets all 5 signing secrets, and runs `fastlane match`
> (`fresh`/`nuke`/`skip`). Use it instead of the manual commands; the steps below are the reference if
> you'd rather do it by hand or need to debug one piece.

`devops-ci-architect` Phase F walks through these interactively. The steps below are the manual reference — useful if you skipped Phase F or want to understand exactly what the agent did.

### Step 1 — `MATCH_PASSWORD` (agent-generated, or your own)

Generate a strong random passphrase:

```bash
openssl rand -base64 32 | tr -d '/+=' | head -c 32
```

**Save it in your password manager NOW.** It can never be recovered — losing it means re-creating the match repo from scratch.

Set the secret:

```bash
printf '%s' "<PASSPHRASE>" | gh secret set MATCH_PASSWORD --body -
```

### Step 2 — Create a GitHub PAT for the match repo

`MATCH_GIT_BASIC_AUTHORIZATION` lets CI clone your private match repo over HTTPS.

1. **Open:** https://github.com/settings/tokens/new?scopes=repo&description=fastlane-match-ci&expiration=365
   - Scope `repo` is pre-selected; expiration set to 1 year.
2. Scroll to the bottom and click **Generate token**.
3. Copy the generated token (starts with `ghp_`). You can only see it once.
4. Encode `username:PAT` as base64 and set the secret:
   ```bash
   printf '%s:%s' "<YOUR_GITHUB_USERNAME>" "<PAT>" | base64 | tr -d '\n' | gh secret set MATCH_GIT_BASIC_AUTHORIZATION --body -
   ```

### Step 3 — Create an App Store Connect API key

This single key replaces Apple ID + 2FA for both `match` (cert creation) and `pilot`/`deliver` (TestFlight + App Store upload).

1. **Open:** https://appstoreconnect.apple.com/access/api
2. Go to the **Keys** tab. Click the **"+"** button.
3. Settings:
   - **Name:** `fastlane-ci`
   - **Access:** **App Manager** ← required; "Developer" role can NOT create distribution certs
4. Click **Generate**.
5. From the result page, grab three things:
   - **Key ID** — 10 characters, shown next to the key (e.g. `2X9ABC3D4E`)
   - **Issuer ID** — UUID shown at the top of the Keys page (e.g. `69a6de7e-...`)
   - **The .p8 file** — click **Download API Key**. **You can ONLY download this once.** Save it (e.g. `~/Downloads/AuthKey_2X9ABC3D4E.p8`).
6. Set the three secrets:
   ```bash
   gh secret set APP_STORE_CONNECT_API_KEY_ID --body "<KEY_ID>"
   gh secret set APP_STORE_CONNECT_ISSUER_ID --body "<ISSUER_ID>"
   base64 < <P8_PATH> | tr -d '\n' | gh secret set APP_STORE_CONNECT_API_KEY --body -
   ```

### Step 4 — Initialize match (LOCAL, one-time)

Required before CI can run. Creates the iOS distribution cert + provisioning profile and pushes them encrypted to the match repo.

```bash
bundle install

APP_STORE_CONNECT_API_KEY_KEY_ID="<KEY_ID>" \
APP_STORE_CONNECT_API_KEY_ISSUER_ID="<ISSUER_ID>" \
APP_STORE_CONNECT_API_KEY_KEY_FILEPATH="<P8_PATH>" \
MATCH_PASSWORD="<PASSPHRASE>" \
bundle exec fastlane match appstore
```

⚠️ **If your team already has a distribution cert** outside of match, this will conflict. Either manually export the existing `.p12` into the match repo first, or run `bundle exec fastlane match nuke distribution` to revoke and recreate (**destructive: breaks future installs of existing builds**).

### Step 5 — Cleanup

```bash
rm <P8_PATH>
# .p8 content is safely in the GitHub secret + your match repo
```

---

## Renewal

### `MATCH_GIT_BASIC_AUTHORIZATION` — PAT expires ~yearly

GitHub emails you before expiration. To renew:

1. New token: https://github.com/settings/tokens/new?scopes=repo&description=fastlane-match-ci&expiration=365
2. Update secret:
   ```bash
   printf '%s:%s' "<YOUR_USERNAME>" "<NEW_PAT>" | base64 | tr -d '\n' | gh secret set MATCH_GIT_BASIC_AUTHORIZATION --body -
   ```
3. Revoke the expired PAT at https://github.com/settings/tokens.

### `APP_STORE_CONNECT_API_KEY` (3 secrets) — if revoked or stops working

1. New key: https://appstoreconnect.apple.com/access/api → Keys → "+" · Role: **App Manager** · download `.p8`.
2. Update all three (commands as in Step 3 above).
3. Delete local `.p8` and revoke the old key in App Store Connect.

### `MATCH_PASSWORD` — only rotate if compromised

```bash
bundle exec fastlane match change_password
# Enter old → new → new
printf '%s' "<NEW_PASSWORD>" | gh secret set MATCH_PASSWORD --body -
```

Anyone else using this match repo must receive the new password out-of-band.

---

## Troubleshooting (CI error → likely fix)

| CI error message | Likely cause | Fix |
|---|---|---|
| `Could not find git remote` (match step) | `MATCH_GIT_BASIC_AUTHORIZATION` expired or missing `repo` scope | Renew PAT (above) |
| `Match decryption failed` | `MATCH_PASSWORD` secret mismatches the match repo's actual passphrase | Set secret to the passphrase used when match was initialized |
| `Could not get App Store Connect access token` | One of the 3 ASC secrets wrong, or `.p8` base64 has trailing newline | Re-encode with `base64 < file \| tr -d '\n'` and re-set |
| `pilot upload` → "No App Store Connect access" | API key role is "Developer" not "App Manager" | Re-create key with App Manager role |
| Codesigning errors despite secrets set | `setup_ci` or `match readonly` missing in CI run | Check Fastfile has `setup_ci if ENV["CI"]` and `match(... readonly: ENV["CI"] ? true : false)` |
