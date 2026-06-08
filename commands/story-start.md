---
description: Transition a story's GitHub Project Status from Todo → In-Progress and assign yourself.
argument-hint: <S-XX> or <F-XXX/S-XX>
---

Move a story to **In-Progress** on the GitHub Project board.

> Note: `dev-story-implementer` already moves the board to In-Progress when it starts a story. Use
> this command only as a manual override — e.g. you're starting a story by hand, or want to flag it
> as started without running the implementer.

**Argument:** `$ARGUMENTS` — either `S-XX` (search across all features) or `F-XXX/S-XX` (filter by feature label).

## Execute

1. Parse `$ARGUMENTS`. If it contains `/`, split into `FEATURE_ID` and `STORY_ID`; otherwise `FEATURE_ID` is empty and `STORY_ID` is the whole string. If `STORY_ID` doesn't match `^S-\d{2}$`, STOP and ask the user for a valid story id.

2. Read `docs/feature_backlog.md`. Extract:
   - `**GitHub Repo:**` → `REPO` (`owner/name`)
   - `**GitHub Project:**` URL → `PROJECT_OWNER` (path segment after `/users/` or `/orgs/`) and `PROJECT_NUMBER` (last path segment)

   If either line is missing → STOP: "No GitHub Project configured for this project. Run `/board-init` first, or check `docs/feature_backlog.md`."

3. Verify `gh auth status` succeeds. If not → STOP: "Run `gh auth login` (scopes: `repo`, `project`)."

4. Resolve the Issue number for this story:
   ```bash
   FILTER=( --repo "$REPO" --search "[$STORY_ID] in:title" --json number,title,labels )
   if [[ -n "$FEATURE_ID" ]]; then FILTER+=( --label "feature:$FEATURE_ID" ); fi
   gh issue list "${FILTER[@]}"
   ```
   - 0 matches → STOP: "No issue found for $STORY_ID. Has BA Phase F run for this feature?"
   - 2+ matches → STOP, show titles, ask user to disambiguate with `F-XXX/S-XX` form.
   - 1 match → capture `ISSUE_NUMBER`.

5. Resolve Project node id, Status field id, and the `In-Progress` option id:
   ```bash
   PROJECT_NODE_ID=$(gh project view "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --format json | jq -r '.id')

   FIELDS=$(gh project field-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --format json)
   STATUS_FIELD_ID=$(echo "$FIELDS" | jq -r '.fields[] | select(.name=="Status") | .id')
   STATUS_OPT_ID=$(echo "$FIELDS"  | jq -r '.fields[] | select(.name=="Status") | .options[] | select(.name=="In-Progress") | .id')
   ```
   If `STATUS_OPT_ID` is empty → STOP: "Project Status field has no `In-Progress` option. Run `/board-init` to repair, or fix in the UI."

6. Resolve the Project item id for the issue:
   ```bash
   ITEMS=$(gh project item-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --format json --limit 200)
   ITEM_ID=$(echo "$ITEMS" | jq -r --argjson n "$ISSUE_NUMBER" '.items[] | select(.content.number == $n) | .id')
   ```
   If empty → STOP: "Issue #$ISSUE_NUMBER is not on the project board. Re-run BA Phase F or add it manually."

7. Set Status = In-Progress and assign self:
   ```bash
   gh project item-edit --id "$ITEM_ID" --project-id "$PROJECT_NODE_ID" \
     --field-id "$STATUS_FIELD_ID" --single-select-option-id "$STATUS_OPT_ID"
   gh issue edit "$ISSUE_NUMBER" --repo "$REPO" --add-assignee @me
   ```

8. Report:
   > Started **$STORY_ID** ($FEATURE_ID): https://github.com/$REPO/issues/$ISSUE_NUMBER · Status → In-Progress

## Notes

- This command does NOT touch any source files or `story-plan.md` Status. Use `dev-story-implementer` for the full implementation flow; use this command when you want only the board transition.
- If invoked while the item is already `In-Progress` or beyond, the call is a no-op for Status but the assignee is still added.
