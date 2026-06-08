# How to add a new CI/CD stack (no skill-body edits)

`devops-ci-architect` reads the Project Profile's `CI/CD target`, loads
`templates/stacks/<target>/manifest.md`, and writes what it declares. To support a new project type
you only add files here — you do NOT edit `SKILL.md`.

## The pipeline every stack follows

```
(dev-story-implementer marked In-Progress at story start)
push feat/**  →  auto-pr.yml: open PR
              →  ci.yml: build + test  (the merge gate)
CI green      →  in-test.yml: board → In-Test  (+ your on-green deploy, if any)
/story-done   →  verify CI green · squash-merge the PR · board → Done
merge to main →  release.yml (auto-deploy)  OR  a manual distribution workflow  OR  nothing
```

`auto-pr.yml` and `set-project-status.sh` are **universal** — the skill always writes them from
`templates/shared/`, you don't ship them. You ship only what's stack-specific. (In-Progress is set
client-side by `dev-story-implementer`; CI only moves the board to In-Test.)

## Steps

1. **Pick a target id** — kebab-case (e.g. `flutter`, `node-api`). Must match what `system-architect`
   writes in `CI/CD target:`.

2. **Create `templates/stacks/<target-id>/`:**
   ```
   manifest.md            # copy templates/new-stack/manifest.md and fill every section
   workflows/
     ci.yml               # build + test. Triggers: pull_request + push to main + push to feat/**
     in-test.yml          # on(workflow_run: CI completed). If success + feat branch → board → In-Test.
                          #   Add a deploy step BEFORE the board move if your stack deploys on green.
     release.yml          # OPTIONAL: auto-deploy on push to main (ignore docs/**). Omit if your
                          #   stack can't auto-release — ship a workflow_dispatch-only workflow instead
                          #   (e.g. swift-ios testflight.yml).
   secrets-checklist.md   # reference doc → docs/SECRETS.md
   <support files>/       # optional (e.g. fastlane/ for iOS)
   ```

3. **`ci.yml` must run on `push: feat/**`** (not just `pull_request`) — `auto-pr.yml` opens PRs with
   GITHUB_TOKEN, which GitHub blocks from firing `pull_request` workflows, and `in-test.yml` keys off
   CI finishing via `workflow_run`. The board move in `in-test.yml` is one line:
   `bash .github/scripts/set-project-status.sh In-Test "$BRANCH"` (guard it with
   `if: vars.PROJECT_NUMBER != ''`; pass `GH_TOKEN: ${{ secrets.PROJECTS_TOKEN }}`). Copy the iOS or
   Shopify `in-test.yml` as your starting point.

4. **Use `<PLACEHOLDER>` tokens** for anything project-specific; declare each in the manifest's
   Placeholders table (filled from auto-extract / Verified Commands / a Phase-B question). Wrap steps
   the skill should keep on update in `# === USER CUSTOM START/END ===`.

   Every workflow must declare a least-privilege `permissions:` block (`ci.yml`: `contents: read`;
   add `pull-requests: write` only where a step comments on the PR). The merge gate itself is enforced
   skill-side via branch protection (SKILL.md · E2), so stacks don't configure it.

5. **Fill `manifest.md` completely** — runner, workflow roles, support files, placeholders,
   auto-extract, the secrets loop, local setup (mark destructive steps as STOP-able gates), the
   REFERENCES.md block, hand-off notes. Write `none` where a section doesn't apply; never omit one.

Drop the directory in, set `CI/CD target: <target-id>`, run the skill. Reference examples:
`shopify/` (deploys on green + on merge) and `swift-ios/` (no auto-deploy; manual TestFlight).
