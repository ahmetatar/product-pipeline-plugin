---
description: Accept a story — merge its PR and move the GitHub Project Status In-Test → Done.
argument-hint: <S-XX> or <F-XXX/S-XX>
---

Accept a story you've tested: **squash-merge its PR, then move the board to Done.** This is the one
manual "I accept it" gate — run it after testing the In-Test build. (On Shopify, the merge fires
`release.yml`, which deploys the version live.)

**Argument:** `$ARGUMENTS` — either `S-XX` or `F-XXX/S-XX`.

## Execute

1. Parse `$ARGUMENTS` (see `/story-start` step 1).
2. Read repo + project coordinates from `docs/feature_backlog.md` (see `/story-start` step 2).
3. Verify `gh auth status` (scopes `repo` + `project`).
4. Resolve `ISSUE_NUMBER` (see `/story-start` step 4).

5. **Locate the open PR that closes this issue** (capture its number + head branch):
   ```bash
   read -r PR BRANCH < <(gh pr list --repo "$REPO" --state open --json number,headRefName,closingIssuesReferences \
     --jq "[.[] | select(.closingIssuesReferences[]?.number == $ISSUE_NUMBER)][0] // empty | \"\(.number) \(.headRefName)\"")
   ```
   Empty → STOP: "No open PR closes #$ISSUE_NUMBER. It may already be merged (then just set the board
   below), or `dev-story-implementer` never pushed. Tell me how to proceed."

6. **Verify CI is green** (the merge gate):
   ```bash
   gh pr checks "$PR" --repo "$REPO"
   ```
   Not all green → STOP, show the failing checks, ask how to proceed (fix on the branch and re-iterate,
   or accept the failure deliberately). Never force-merge red checks.

7. **Accept the story in `story-plan.md` on the branch FIRST, then squash-merge** — so the accepted
   state rides inside the squashed commit, not a separate trailing commit on `main`. Acceptance is
   three edits in the story file (this is the moment the boxes become true: the implementer proved
   the automated checks, the user just tested the In-Test build):
   - `**Status:**` In-Progress → `Done`
   - tick every `- [ ]` → `- [x]` under `## Acceptance Criteria`
   - tick every `- [ ]` → `- [x]` under `## Story Definition of Done`
   An AC/DoD item that is genuinely NOT met → STOP and surface it (the user decides: fix first, or
   accept deliberately and leave that box `[ ]` with a short `<!-- not verified: reason -->` note).
   The push re-runs CI, so wait for green again before merging (`Closes #N` auto-closes the issue;
   `--delete-branch` removes the remote + local branch):
   ```bash
   git checkout "$BRANCH" && git pull --ff-only          # land on the PR branch
   # Edit story-plan.md: Status → Done + tick the AC + Story-DoD checkboxes (above)
   git commit -am "docs(F-XXX): [S-YY] mark story Done" && git push
   gh pr checks "$PR" --repo "$REPO" --watch             # gate: wait for the re-run
   gh pr merge "$PR" --repo "$REPO" --squash --delete-branch
   ```
   **If this was the feature's last story, accept the feature.** After flipping this story to `Done`
   (above, before the commit), check whether every sibling story is now `Done`:
   ```bash
   grep -L '^\*\*Status:\*\* Done' docs/features/F-XXX-*/stories/*/story-plan.md
   ```
   Any files listed → other stories remain → leave `feature-analysis.md` untouched; skip the rest of this
   block. Empty output → all stories are `Done` → run the **feature-acceptance gate** before closing the
   feature (don't flip its Status silently — "all stories Done" is a proxy, not the feature DoD):

   1. Read the `## Feature Definition of Done` checklist in `feature-analysis.md`.
   2. Walk it with the user. Tick `[x]` each item you can confirm is met — items already guaranteed by the
      now-Done stories you may confirm together; items needing live/manual end-to-end proof (e.g. the happy
      path on the real store) require the user's explicit yes, since they just tested the In-Test build.
      This is the one moment the feature is verified as a whole, not story-by-story.
   3. Any item you cannot tick → STOP: list the unmet items and ask whether to (a) accept the feature anyway
      — leave those boxes `[ ]` each with a short `<!-- not verified: reason -->` note — or (b) hold the
      feature open: still close THIS story, but leave the `feature-analysis.md` header `**Status:**`
      unchanged.
   4. On acceptance, in the SAME commit as this story's `Done` flip: write the ticked DoD boxes AND set the
      `feature-analysis.md` header `**Status:**` to `Done`, so both ride into the squash-merge.
   Then land the local repo back on an up-to-date `main` so the next story branches cleanly from it
   (also covers the case where the local branch still existed):
   ```bash
   git checkout main && git pull --ff-only
   git branch -D "$BRANCH" 2>/dev/null || true   # belt-and-suspenders if a stale local branch remains
   ```

8. **Move the board to Done.** Resolve `PROJECT_NODE_ID`, `STATUS_FIELD_ID`, the `Done` option id,
   and `ITEM_ID` (same shape as `/story-start` steps 5–6), then:
   ```bash
   STATUS_OPT_ID=$(echo "$FIELDS" | jq -r '.fields[] | select(.name=="Status") | .options[] | select(.name=="Done") | .id')
   gh project item-edit --id "$ITEM_ID" --project-id "$PROJECT_NODE_ID" \
     --field-id "$STATUS_FIELD_ID" --single-select-option-id "$STATUS_OPT_ID"
   ```

9. Report:
    > $STORY_ID accepted · PR #$PR squash-merged · issue #$ISSUE_NUMBER closed · board → Done
    > Shopify: merge fired `release.yml` (live deploy). iOS: ship to TestFlight via `gh workflow run testflight.yml` when ready.

    If this closed the feature (last story), add: `· F-XXX accepted — DoD walked, feature-analysis → Done`.

## Notes

- Run this AFTER testing the In-Test build — it's the accept gate that **merges + finishes** the story. The board reached In-Progress (dev-story-implementer) and In-Test (CI) before this; you don't set those.
- If the PR is already merged (step 5 empty), skip steps 6–7, apply the same story acceptance directly on `main` (Status → Done + tick the AC + Story-DoD checkboxes), and set the board to Done. Run the same last-story check on `main` (`grep -L '^\*\*Status:\*\* Done' docs/features/F-XXX-*/stories/*/story-plan.md`); if empty, run the same **feature-acceptance gate** (walk the DoD, tick boxes) before flipping `feature-analysis.md` Status → Done in that commit.
- If the item is still in `Todo` or `In-Progress`, STOP and confirm — skipping `In-Test` usually means CI never went green / the change wasn't tested.
