---
name: devops-ci-architect
description: >
  Sets up GitHub Actions CI/CD for a project. Every stack gets the same standard pipeline:
  push a feat branch → a PR opens (auto-pr.yml) → CI runs build + test as the merge gate (ci.yml) →
  when CI is green the board moves to In-Test, and Shopify additionally deploys the app to the store
  (in-test.yml). (dev-story-implementer set the board to In-Progress at story start.) Stacks differ
  only in their build/test commands and their on-green deploy step. iOS also ships a manual TestFlight button.
  Stack-specific details live in templates/stacks/<id>/manifest.md — adding a project type is a
  drop-in directory, no skill-body edits. ALWAYS use this skill when the user asks to set up CI/CD,
  GitHub Actions, deploy/release automation, or a build pipeline.
  Triggers: "set up CI", "github actions kur", "ci/cd workflow", "release workflow", "shopify deploy",
  "ci kur".
  Output: .github/workflows/ (ci.yml + auto-pr.yml + in-test.yml + the stack's release/distribution
  workflow) + .github/scripts/set-project-status.sh + stack support files + docs/SECRETS.md +
  docs/CI.md (standalone pipeline reference).
---

# DevOps CI Architect

You set up GitHub Actions CI/CD for a project. The pipeline is the SAME for every stack; stacks only
swap in their own build/test commands and their on-green deploy step. You never hardcode a stack —
you read the project's `CI/CD target`, load that stack's manifest, and write the files it declares.

Runs **once per project**. If the workflows already exist, you update them (Section 6).

---

## The standard pipeline (every stack)

Ordered stages. Each row: what fires it → what runs → what it does → the board Status after it.
`workflow_run` means the GitHub Actions event "a named workflow finished"; `feat/**` is the story branch glob.

| # | Trigger | Runs | Action | Board after |
|---|---|---|---|---|
| 1 | story start (manual) | `dev-story-implementer` | mark In-Progress, code, commit `Closes #N`, push to `feat/**` | **In-Progress** |
| 2 | push to `feat/**` | `auto-pr.yml` | open the PR if none exists | (unchanged) |
| 3 | PR + push to `feat/**`/`main` | `ci.yml` | build + test — the required check; PR cannot merge until green | (unchanged) |
| 4 | `workflow_run` of `ci.yml` = success on `feat/**` | `in-test.yml` | *(Shopify only: deploy the app version to the store first)*, then move the board | **In-Test** |
| 5 | user accepts → runs `/story-done` (manual) | `/story-done` | verify CI green, squash-merge the PR, move the board | **Done** |
| 6 | PR merged to `main` | `release.yml` | Shopify: release the version live · iOS: nothing (use `testflight.yml` manually) | (unchanged) |

Sequential gates: 3 must be green before 4 fires; 5 is the manual human-accept gate between 4 and 6.
Row 3 is a real gate only with **branch protection** on `main` (Section 3 · E2) requiring the CI
check — without it `ci.yml` is advisory and a red PR can still be merged.

- `auto-pr.yml` and `set-project-status.sh` are **universal** (in `templates/shared/`, no
  placeholders). Always write them, for every stack.
- `ci.yml` and `in-test.yml` are **per-stack** (in `templates/stacks/<id>/workflows/`) — same shape,
  different commands; `in-test.yml` differs only by whether it deploys before moving the board.
- The release/distribution workflow is stack-dependent: Shopify ships `release.yml` (deploy on merge),
  iOS ships a manual `testflight.yml` instead.
- **Board moves:** In-Progress is set by `dev-story-implementer` at story start (its own gh
  credentials). **In-Test is moved by GitHub Actions** (`in-test.yml`) when CI goes green — that needs
  the `PROJECTS_TOKEN` secret + `PROJECT_NUMBER` variable; if unset, the In-Test step skips silently
  and the rest still works. Done is the manual `/story-done`.

---

## 1. Inputs

**Read automatically (don't ask):**
- `docs/log.md` — `tail -n 15` only: skip work already logged; skip silently if absent.
- `CLAUDE.md` `## Project Profile` — the **`CI/CD target`** field picks the stack (+ platform / package manager for context).
- `docs/REFERENCES.md` `## Verified Commands` — the build/test/lint/typecheck commands you substitute. A contract; never invent commands.
- `docs/feature_backlog.md` — `**GitHub Repo:**`, `**GitHub Project:**` URL (→ `PROJECT_NUMBER`), product name.
- `.github/workflows/` — if any file the stack declares already exists → update mode (Section 6).

**Stop if missing:**
- No `CI/CD target` in the Project Profile → STOP: "Run `system-architect` first — it sets the `CI/CD target` I use to pick the stack." (Or let the user name a target id from `ls templates/stacks/`.)
- No `## Verified Commands` in `docs/REFERENCES.md` → STOP: "Run `system-architect` first (it writes verified build/test/lint commands), or add them to `docs/REFERENCES.md`."
- `gh` not authenticated → STOP: "Run `gh auth login` (scopes: `repo`, `project`)."

---

## 2. Pick the stack

1. Read `CI/CD target` → `TARGET`.
2. Load `templates/stacks/$TARGET/manifest.md`:
   - **Exists** → it drives everything below.
   - **Missing directory** → STOP: "No CI/CD stack for `$TARGET`. Available: <`ls templates/stacks/`>. To add one, copy `templates/new-stack/` into `templates/stacks/$TARGET/` and fill the manifest — see `templates/new-stack/HOWTO.md`."
   - **No Project Profile at all** → match each manifest's `Applies when` detection signal against the repo; one match → propose it; none/many → ask.

From here the manifest is the source of truth.

---

## 3. Generate

### A. Extract values
Run the manifest's **Auto-extract** snippet; mark anything ambiguous `<unknown>`. Pull
build/test/lint/typecheck from `REFERENCES.md` `## Verified Commands`. Read `PROJECT_NUMBER` from the
`**GitHub Project:**` URL in `feature_backlog.md` (the last path segment).

### B. Confirm (one block)
Show all auto-detected values in ONE block; ask the user to confirm or override. Ask each `<unknown>`
as a single follow-up. Honor any Phase-B note in the manifest (e.g. iOS match-repo creation only
after confirmation). Don't proceed until every field has a value.

### C. Write the workflows + scripts
- **Universal (always, from `templates/shared/`):**
  - `auto-pr.yml` → `.github/workflows/auto-pr.yml` (no substitution).
  - `set-project-status.sh` → `.github/scripts/set-project-status.sh` (no substitution; `chmod +x` or call via `bash`).
- **Per-stack (from `templates/stacks/$TARGET/workflows/`):** write every file in the manifest's
  Workflow-roles table to its repo path, substituting every placeholder from the Placeholders table.
- Write the manifest's **Support files** (substituted); apply its `.gitignore` additions if missing.
- Preserve anything between `# === USER CUSTOM START ===` / `END` markers on update.

### D. `docs/SECRETS.md`
Substitute the stack's `secrets-checklist.md` → `docs/SECRETS.md` (reference doc for renewals).

### E. Set secrets + the board variable (interactive)
Ask once: "Set up CI secrets now? Needed: `PROJECTS_TOKEN` (lets CI move the board to In-Test) +
<the manifest's secrets>. (yes / later via docs/SECRETS.md)". If later: skip E + F, point to
`docs/SECRETS.md`.

If yes, then for the In-Test board move (universal):
- `PROJECTS_TOKEN` — a PAT with `repo` + `project` scope (https://github.com/settings/tokens/new?scopes=repo,project). `gh secret set PROJECTS_TOKEN --body "<PAT>"`.
- `PROJECT_NUMBER` — `gh variable set PROJECT_NUMBER --body "<the number from the project URL>"`.

Then loop the **manifest's Secrets table** in order (generate-and-show for `Agent-generated? yes`;
otherwise show the "how to obtain" URLs, collect the value, run the set command). **Never** echo a
secret into a workflow or commit it — all credentials are `${{ secrets.* }}`.

Verify: `gh secret list` shows every required name; `gh variable list` shows `PROJECT_NUMBER`.

### E2. Branch protection — enforce the merge gate (needs repo admin)
`ci.yml` is called "the merge gate," but that is only real if GitHub blocks merges until it passes.
Protect `main` so the gate is enforced, not just conventional. If `gh` lacks admin on the repo, warn
and point here instead of failing.

The required check name is the CI job's `name:` from the `ci.yml` you just wrote (e.g.
`Lint · Build · Test` / `Lint · Typecheck · Build · Test`). Because `ci.yml` also runs on push to
`feat/**`, that check lands on the PR head commit, so the gate resolves without a `pull_request` run.

The PUT returns the full branch-protection object on success — large and useless in context. Discard
it and check the exit code; only surface output on failure.

```bash
OWNER_REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
gh api -X PUT "repos/$OWNER_REPO/branches/main/protection" --input - >/dev/null <<JSON && echo "branch protection: enabled on main" || echo "branch protection: FAILED (likely no repo admin) — see E2"
{
  "required_status_checks": { "strict": false, "contexts": ["<CI_CHECK_NAME>"] },
  "enforce_admins": false,
  "required_pull_request_reviews": { "required_approving_review_count": 0 },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
```
- `required_approving_review_count: 0` → a PR is required but no human approval is, so `/story-done`'s
  squash-merge still works while PR + green CI stay mandatory.
- `enforce_admins: false` keeps the owner from being locked out; the gate still holds for the normal flow.
- Do NOT enable `strict` — it would force a rebase on every `main` change (churn for an autonomous loop).

### F. Local setup (only if E ran; follow the manifest's Local setup)
Run the manifest's Local-setup steps in order. **Honor every step marked a STOP-able safety gate** —
present options and WAIT; never run a destructive command automatically. Interactive/browser steps:
instruct the user (suggest the `! ` prefix) instead of running them. `none` → skip.

### G. Write `docs/CI.md`
Write the manifest's CI-pipeline block exactly as specified (substituted) to `docs/CI.md` — the
standalone pipeline reference `dev-story-implementer` reads to know the pipeline exists.

### H. Log + hand off
```bash
mkdir -p docs && echo "- $(date '+%Y-%m-%d %H:%M') · devops-ci-architect · stack=<TARGET> · secrets=<yes|skipped> · local-setup=<yes|skipped|none>" >> docs/log.md
```
Hand off using the manifest's **Hand-off notes** plus: the workflow paths, `docs/SECRETS.md`, the
secrets/local-setup result, and a one-line recap of the standard pipeline (dev marks In-Progress →
push → PR opens → CI → In-Test on green → `/story-done` merges + Done).

---

## 4. Working principles

- **The manifest is the contract.** All stack behavior lives in `templates/stacks/<target>/manifest.md`. No stack logic in this skill body — if something's missing, fix the manifest.
- **Verified Commands are the contract.** Build/test/lint/typecheck come from `REFERENCES.md`, never invented. Missing → STOP and ask the user to add it.
- **`ci.yml` is validation-only.** Deploy lives in `in-test.yml` (on green) and `release.yml` (on merge). Never add a deploy step to `ci.yml`.
- **The merge gate is enforced, not assumed.** Branch protection on `main` (E2) makes the CI check required; skip it only when `gh` lacks repo admin, and say so.
- **Least privilege.** Every workflow declares a `permissions:` block; the default `GITHUB_TOKEN` is otherwise over-scoped. `ci.yml` needs only `contents: read`.
- **No secrets in files.** Every credential is `${{ secrets.* }}`; never commit a `.env`, key, or token.
- **Honor safety gates.** Any Local-setup step the manifest marks destructive (cert/key revocation, data-wiping migration) is STOP-able — surface options and wait.
- **Don't over-deploy.** `in-test.yml` deploys UNRELEASED previews (Shopify `--no-release`); releasing live happens only on merge. Don't make it more aggressive.
- **Preserve USER CUSTOM blocks** on update; don't touch unrelated workflows.

---

## 5. Update mode (files already exist)

For each file the stack declares that already exists in `.github/`:
1. Read it. Is it structurally this skill's output, or foreign?
2. Foreign → STOP, confirm overwrite (warn about lost customizations).
3. Ours → re-substitute placeholders from the latest `REFERENCES.md` + manifest; **preserve** everything between `# === USER CUSTOM START/END ===`.
4. A newly-declared file that doesn't exist yet → create it. Don't delete unrelated workflows.
5. Append an update line to `docs/log.md`.

---

## 6. Checklist (before done)

- [ ] `CI/CD target` resolved; manifest loaded (or missing-stack STOP shown)
- [ ] `REFERENCES.md` `## Verified Commands` present; commands pulled from there, not invented
- [ ] Auto-extract run; every `<unknown>` resolved; user confirmed the summary
- [ ] Universal files written: `auto-pr.yml`, `set-project-status.sh`
- [ ] Per-stack workflows written; every placeholder substituted (none left); YAML valid
- [ ] Support files written (or `none`); `.gitignore` additions applied
- [ ] `docs/SECRETS.md` written
- [ ] Secrets + `PROJECT_NUMBER` handled — done (`gh secret list` / `gh variable list`) OR deferred
- [ ] Branch protection on `main` requires the CI check (E2) — applied OR admin-skip warned
- [ ] Every workflow has a `permissions:` block (least privilege)
- [ ] Local setup handled — done OR `none` OR safety-gated and waiting
- [ ] `docs/CI.md` written (pipeline reference)
- [ ] `docs/log.md` appended; no secret/key/`.env` committed
