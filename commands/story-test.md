---
description: Transition a story's GitHub Project Status from In-Progress → In-Test.
argument-hint: <S-XX> or <F-XXX/S-XX>
---

Move a story to **In-Test** on the GitHub Project board (code-side complete, awaiting manual verification).

> Note: with CI set up (`devops-ci-architect`), `in-test.yml` moves the board to In-Test automatically
> when `ci.yml` goes green on the PR (Shopify also deploys a preview first). Use this command only as a
> manual override — e.g. CI isn't wired, or you want to force the transition.

**Argument:** `$ARGUMENTS` — either `S-XX` or `F-XXX/S-XX`.

## Execute

Follow the same shape as `/story-start`, but target the `In-Test` Status option:

1. Parse `$ARGUMENTS` (see `/story-start` step 1).
2. Read `**GitHub Repo:**` and `**GitHub Project:**` from `docs/feature_backlog.md` (step 2).
3. Verify `gh auth status` (step 3).
4. Resolve `ISSUE_NUMBER` via `gh issue list --search "[$STORY_ID] in:title"` (step 4).
5. Resolve `PROJECT_NODE_ID`, `STATUS_FIELD_ID`, and the `In-Test` option id:
   ```bash
   STATUS_OPT_ID=$(echo "$FIELDS" | jq -r '.fields[] | select(.name=="Status") | .options[] | select(.name=="In-Test") | .id')
   ```
6. Resolve `ITEM_ID` (step 6).
7. Set the Status field:
   ```bash
   gh project item-edit --id "$ITEM_ID" --project-id "$PROJECT_NODE_ID" \
     --field-id "$STATUS_FIELD_ID" --single-select-option-id "$STATUS_OPT_ID"
   ```
8. **Resolve the test-delivery mode (capability-gated).** Only if this project documents a per-story
   test-delivery choice — i.e. `docs/CI.md` mentions `deliver:testflight` / `deliver:local` labels.
   `dev-story-implementer` recorded the story's choice as a `Deliver:` commit trailer, which `auto-pr.yml`
   turned into a matching PR label. Read it back off the PR so the next-step message matches what was chosen:
   ```bash
   DELIVER=$(gh pr list --repo "$REPO" --search "$STORY_ID in:title" --state all \
     --json labels --jq '.[0].labels[].name | select(startswith("deliver:"))' | head -1)
   ```
   `deliver:testflight` → testflight mode; `deliver:local` → local-simulator mode; empty / no such labels
   documented → unknown (fall through to the generic message).
9. Report — tailor **Next step** to `$DELIVER`:
   > $STORY_ID → In-Test · https://github.com/$REPO/issues/$ISSUE_NUMBER

   - **local-simulator** (`deliver:local`):
     > Next step: install the branch on your simulator and verify it (`scripts/run-on-sim.sh` if present), then run `/story-done $ARGUMENTS` — it merges the PR and marks it Done.
   - **testflight** (`deliver:testflight`):
     > Next step: once TestFlight finishes processing the build, test it on-device, then run `/story-done $ARGUMENTS` — it merges the PR and marks it Done.
   - **unknown / no per-story choice** (generic):
     > Next step: test the change (Shopify: open the unreleased version in your dev store; iOS: run the branch on your simulator), then run `/story-done $ARGUMENTS` — it merges the PR and marks it Done.

> `in-test.yml` is `workflow_run`-triggered (it fires when CI goes green) — there is nothing to
> dispatch manually. This command only sets the board status.

## Notes

- Does not modify `story-plan.md`. If you want the markdown Status synced too, run `dev-story-implementer` instead.
- If the item is already past `In-Test` (Done), STOP and confirm before reverting.
