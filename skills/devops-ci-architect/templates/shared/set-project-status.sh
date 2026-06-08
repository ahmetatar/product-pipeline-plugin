#!/usr/bin/env bash
# Move a story's GitHub Project (v2) item to a target Status. Stack-agnostic.
#
# Usage:  set-project-status.sh <Status> <branch>
#   <Status>  one of: Todo | In-Progress | In-Test | Done
#   <branch>  the feat/** branch whose open PR closes the story issue
#
# Env (CI provides):
#   GH_TOKEN          PAT with `repo` + `project` scope (secrets.PROJECTS_TOKEN)
#   PROJECT_NUMBER    the GitHub Project (v2) number (vars.PROJECT_NUMBER)
#   GITHUB_REPOSITORY owner/name (set automatically by Actions)
#
# If PROJECT_NUMBER is empty the board isn't wired — exit 0 (no-op), don't fail CI.
set -euo pipefail

STATUS="$1"
BRANCH="$2"

if [ -z "${PROJECT_NUMBER:-}" ]; then
  echo "PROJECT_NUMBER unset — board automation off, skipping."
  exit 0
fi

OWNER="${GITHUB_REPOSITORY%/*}"
NAME="${GITHUB_REPOSITORY#*/}"

# 1. The issue this branch's PR closes (from `Closes #N` → closingIssuesReferences).
PR=$(gh pr list --repo "$GITHUB_REPOSITORY" --head "$BRANCH" --state all \
  --json number --jq '.[0].number // empty')
[ -z "$PR" ] && { echo "No PR for $BRANCH — skipping board move."; exit 0; }

ISSUE=$(gh pr view "$PR" --repo "$GITHUB_REPOSITORY" \
  --json closingIssuesReferences --jq '.closingIssuesReferences[0].number // empty')
[ -z "$ISSUE" ] && { echo "PR #$PR closes no issue (no 'Closes #N') — skipping."; exit 0; }

# 2. The project item for that issue + the project node id.
read -r ITEM_ID PROJECT_ID < <(gh api graphql -f query='
  query($o:String!,$n:String!,$i:Int!){
    repository(owner:$o,name:$n){
      issue(number:$i){ projectItems(first:20){ nodes{ id project{ number id } } } }
    }
  }' -f o="$OWNER" -f n="$NAME" -F i="$ISSUE" \
  --jq ".data.repository.issue.projectItems.nodes[]
        | select(.project.number==$PROJECT_NUMBER)
        | \"\(.id) \(.project.id)\"")
[ -z "${ITEM_ID:-}" ] && { echo "Issue #$ISSUE not on project $PROJECT_NUMBER — skipping."; exit 0; }

# 3. The Status field id + the option id for the target status.
read -r FIELD_ID OPTION_ID < <(gh api graphql -f query='
  query($p:ID!){ node(id:$p){ ... on ProjectV2 {
    field(name:"Status"){ ... on ProjectV2SingleSelectField { id options{ id name } } }
  } } }' -f p="$PROJECT_ID" \
  --jq ".data.node.field as \$f
        | \$f.options[] | select(.name==\"$STATUS\")
        | \"\(\$f.id) \(.id)\"")
[ -z "${OPTION_ID:-}" ] && { echo "Status option '$STATUS' not found on the board — skipping."; exit 0; }

# 3b. No-regress guard. The pipeline only moves a story FORWARD
# (Todo→In-Progress→In-Test→Done). A late In-Test run (workflow_run from a feat
# branch's CI) can finish AFTER the merge's release.yml has already set Done, and
# would otherwise clobber Done back to In-Test. Refuse backward moves; forward and
# same-status moves proceed. Unknown statuses (rank -1) never block.
rank() { case "$1" in Todo) echo 0;; In-Progress) echo 1;; In-Test) echo 2;; Done) echo 3;; *) echo -1;; esac; }
CURRENT=$(gh api graphql -f query='
  query($it:ID!){ node(id:$it){ ... on ProjectV2Item {
    fieldValueByName(name:"Status"){ ... on ProjectV2ItemFieldSingleSelectValue { name } }
  } } }' -f it="$ITEM_ID" --jq '.data.node.fieldValueByName.name // ""')
if [ "$(rank "$STATUS")" -lt "$(rank "$CURRENT")" ]; then
  echo "Issue #$ISSUE already '$CURRENT' — refusing to regress to '$STATUS', skipping."
  exit 0
fi

# 4. Set it.
gh api graphql -f query='
  mutation($p:ID!,$it:ID!,$f:ID!,$o:String!){
    updateProjectV2ItemFieldValue(input:{
      projectId:$p, itemId:$it, fieldId:$f, value:{singleSelectOptionId:$o}
    }){ projectV2Item{ id } }
  }' -f p="$PROJECT_ID" -f it="$ITEM_ID" -f f="$FIELD_ID" -f o="$OPTION_ID" >/dev/null

echo "Issue #$ISSUE → $STATUS"
