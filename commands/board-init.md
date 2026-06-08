---
description: Bootstrap a GitHub Project (v2) for this product and wire it into feature_backlog.md.
argument-hint: (no arguments — conversational)
---

Set up the GitHub Project board that `ba-feature-analyst` Phase F and the `/story-*` commands depend on. This is the standalone version of `po-backlog` Phase H — use it when the backlog already exists but the board doesn't.

## Pre-flight

1. `docs/feature_backlog.md` MUST exist. If not → STOP, refer user to `po-backlog`.
2. If the file already contains both `**GitHub Repo:**` and `**GitHub Project:**` lines: STOP and confirm with the user before re-creating. Re-running creates a duplicate project.
3. Run `gh auth status` and inspect the **`Token scopes:`** line — it MUST include both `repo` AND `project`. The `project` scope is required for Projects v2 and is NOT granted by a default `gh auth login`. Give the user the right one-time command up front depending on what `gh auth status` shows:
   - **Not authenticated, or token invalid/expired** → STOP: "Run `gh auth login -h github.com -s project` (this requests the `project` scope in the same login)."
   - **Authenticated but `project` missing from scopes** → STOP: "Run `gh auth refresh -h github.com -s project` (adds the scope without a full re-login)."
   - Both scopes present → continue.
   Note: `gh auth login` on an already-logged-in account just reports "already logged in" and does NOT add a missing scope — use `gh auth refresh -s project` in that case.

## Conversational setup

Ask the user (one question at a time, or batch if you can):

- **Project title?** — default to the `**Product:**` line from `feature_backlog.md`.
- **GitHub repo (`owner/name`) where story Issues will live?** — if the cwd has a git remote, propose: `gh repo view --json nameWithOwner -q .nameWithOwner`.
- **Project owner?** — default `@me`. If the repo is under an org, ask whether the project should be `@me` or the org.

## Execute

1. **Create the project:**
   ```bash
   PROJECT_JSON=$(gh project create --owner "$PROJECT_OWNER" --title "$TITLE" --format json)
   PROJECT_URL=$(echo "$PROJECT_JSON" | jq -r '.url')
   PROJECT_NUMBER=$(echo "$PROJECT_JSON" | jq -r '.number')
   ```

   **Fallback (known `gh` bug).** Some `gh` versions (seen on 2.87.2) fail `gh project create` — with or without `--format json` — with: `GraphQL: Variable $query is used by CreateProjectV2 but not declared (mutation CreateProjectV2.createProjectV2.projectV2.items.query)`. The `gh` client sends a malformed `createProjectV2` query. If you hit this, create the project directly via the GraphQL API instead:
   ```bash
   OWNER_ID=$(gh api graphql -f query='query{viewer{id}}' --jq '.data.viewer.id')   # for "@me"
   # For an org owner: gh api graphql -f query='query($l:String!){organization(login:$l){id}}' -f l="$ORG" --jq '.data.organization.id'
   PROJECT_JSON=$(gh api graphql -f query='
     mutation($ownerId:ID!,$title:String!){
       createProjectV2(input:{ownerId:$ownerId,title:$title}){
         projectV2{ id number url title }
       }
     }' -f ownerId="$OWNER_ID" -f title="$TITLE" --jq '.data.createProjectV2.projectV2')
   PROJECT_URL=$(echo "$PROJECT_JSON" | jq -r '.url')
   PROJECT_NUMBER=$(echo "$PROJECT_JSON" | jq -r '.number')
   ```
   (A failed `gh project create` does NOT create anything, but it still consumes the project number — so the new project's number may be >1. Verify with `gh api graphql -f query='query{viewer{projectsV2(first:20){nodes{number title}}}}'` and delete any orphan before continuing.)

   **Link the project to the repo** so it shows up under the repo's **Projects** tab (`https://github.com/$REPO/projects`). A `@me`/org project is owner-scoped and is otherwise invisible from the repo — the user will report "I can't see the project."
   ```bash
   gh project link "$PROJECT_NUMBER" --owner "$REPO_OWNER" --repo "$REPO_NAME"
   ```
   ⚠️ `gh project link` quirks: pass `--repo` as the **bare repo name** (`compliro`), NOT `owner/name` — a slash makes gh read the prefix as a conflicting owner and fail with "has different owner". And `--owner` here must be the **literal owner login** (`ahmetatar`), NOT `@me` — `@me` is not resolved for repo lookup and yields `Could not resolve to a Repository with the name '@me/<name>'`. Verify: `gh api graphql -f query='query($o:String!,$n:String!){repository(owner:$o,name:$n){projectsV2(first:10){nodes{number url}}}}' -f o="$REPO_OWNER" -f n="$REPO_NAME"`.

2. **Replace default Status options** with the 4-stage contract. ⚠️ `gh project field-edit` does **NOT exist** in the `gh` CLI (the only field commands are `field-create`, `field-delete`, `field-list`). Edit the existing Status field's options via the GraphQL `updateProjectV2Field` mutation instead:
   ```bash
   STATUS_FIELD_ID=$(gh project field-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --format json \
     | jq -r '.fields[] | select(.name=="Status") | .id')

   gh api graphql -f query='
     mutation($fieldId:ID!){
       updateProjectV2Field(input:{
         fieldId:$fieldId,
         singleSelectOptions:[
           {name:"Todo",        color:GRAY,   description:""},
           {name:"In-Progress", color:YELLOW, description:""},
           {name:"In-Test",     color:BLUE,   description:""},
           {name:"Done",        color:GREEN,  description:""}
         ]
       }){ projectV2Field{ ... on ProjectV2SingleSelectField { options{ name } } } }
     }' -f fieldId="$STATUS_FIELD_ID"
   ```
   Note: each `singleSelectOptions` entry REQUIRES `name`, `color` (enum: GRAY/BLUE/GREEN/YELLOW/ORANGE/RED/PINK/PURPLE), and `description` (`""` is fine) — omitting any of the three fails. This mutation REPLACES the whole option set, so listing all four here also drops the default "In Progress"/"Done" options. Safe at bootstrap (no items linked yet).

3. **Create `S-ID` (text):**
   ```bash
   gh project field-create "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" \
     --name "S-ID" --data-type TEXT
   ```

4. **Create `Feature` (single-select, placeholder)** — BA Phase F appends real F-XXX options later:
   ```bash
   gh project field-create "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" \
     --name "Feature" --data-type SINGLE_SELECT \
     --single-select-options "__placeholder"
   ```

5. **Create `Type` (single-select):**
   ```bash
   gh project field-create "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" \
     --name "Type" --data-type SINGLE_SELECT \
     --single-select-options "Bootstrap,Core flow,Configuration,Edge-error,Empty state,Permission-access"
   ```

6. **Write coordinates into `docs/feature_backlog.md` header** — insert two lines right after the existing `**Source:**` (or top-matter block):
   ```
   **GitHub Repo:** $REPO
   **GitHub Project:** $PROJECT_URL
   ```
   Use the Edit tool; do not overwrite the file.

7. Confirm to the user with the URL and a one-line summary of fields created.

## Important caveats (mention to user once)

- GitHub Project single-select fields do NOT auto-create options on item field-set. BA Phase F appends `F-XXX` to the `Feature` option set before adding any item — that step is non-negotiable.
- Editing single-select options is done via the GraphQL `updateProjectV2Field` mutation (there is no `gh project field-edit`). It REPLACES the entire option set; any future option edit must re-list ALL existing options or the omitted ones are deleted (and their items unlinked). This is exactly why BA Phase F must *read → append → write back* the full `Feature` option list rather than setting only the new `F-XXX`.
- The board's default view is "By Status" automatically. If grouping isn't what you expect, edit the view in the UI — there's no stable CLI flag for view configuration yet.
