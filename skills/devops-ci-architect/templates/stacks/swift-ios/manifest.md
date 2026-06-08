# Stack manifest — Swift iOS  (target id: `swift-ios`)

The contract `devops-ci-architect` reads for iOS. Skill body is stack-agnostic; everything
iOS-specific is here. Schema: `templates/new-stack/manifest.md`.

## Applies when
- Project Profile `CI/CD target: swift-ios`
- Detection fallback: `*.xcodeproj/` OR `Package.swift` OR `Project.swift` present.

## Runner
- `macos-latest`.

## Workflow roles
iOS has no automated store *release* (App Store can't auto-publish), so the pipeline ends at In-Test.
But how a story gets in front of you for In-Test testing is a **delivery choice** (see Phase B):
- **`local-simulator`** (default): CI verifies the build; you install the branch on your own
  simulator with `scripts/run-on-sim.sh`. A cloud runner cannot reach your local simulator, so this
  step is local by nature — `in-test.yml` only moves the board.
- **`testflight`**: on green CI, `in-test.yml` builds signed + uploads to TestFlight (no auto-submit)
  BEFORE moving the board, so a real-device build is processing by the time the story is In-Test.

`testflight.yml` remains the manual ad-hoc "ship this branch now" button regardless of mode. Plus the
universal `auto-pr.yml` + `set-project-status.sh` (written from `shared/`).

| Role | Repo path | Trigger | Purpose |
|---|---|---|---|
| ci | `.github/workflows/ci.yml` | PR + push to `main` + push to `feat/**` | lint · build · test (unsigned, simulator). The merge gate. |
| in-test | `.github/workflows/in-test.yml` | `workflow_run` of CI = success, on a `feat/**` branch | resolve delivery → (testflight: signed build + upload) → board → In-Test. 3 jobs: `decide` → `testflight`(conditional) → `board`. |
| testflight | `.github/workflows/testflight.yml` | `workflow_dispatch` **only** | build signed · upload to TestFlight (no auto-submit). Manual ad-hoc ship (same `fastlane beta` lane). |

Template files: `workflows/{ci,in-test,testflight}.yml` (siblings of this manifest). No `release.yml`.
Delivery is read from the `IOS_TEST_DELIVERY` repo variable, overridable per-PR by a
`deliver:testflight` / `deliver:local` label.

## Support files
- `fastlane/{Fastfile,Appfile,Matchfile}` → repo `fastlane/`; `fastlane/Gemfile` → repo root `Gemfile`. (Used by `testflight.yml` and by `in-test.yml` in `testflight` delivery mode.)
- `scripts/run-on-sim.sh` → repo `scripts/run-on-sim.sh` (`chmod +x`). Local helper for `local-simulator` mode — build + install + launch on a booted simulator. Substitute `<SCHEME>`, `<SIMULATOR_NAME>`, `<BUNDLE_ID>`.
- `.gitignore` additions: `fastlane/report.xml`, `*.ipa`, `*.dSYM.zip`, `./build/`

## Placeholders
| Placeholder | Filled from |
|---|---|
| `<XCODE_VERSION>` | auto-extract — or `latest-stable` |
| `<BUILD_COMMAND>` | Verified Commands → Build |
| `<TEST_COMMAND>` | Verified Commands → Test |
| `<LINT_COMMAND>` | Verified Commands → Lint (else the template's `command -v swiftlint` guard) |
| `<SCHEME>` | auto-extract |
| `<SIMULATOR_NAME>` | Phase B — default `iPhone 17 Pro Max`; must be a simulator the chosen Xcode ships |
| `<BUNDLE_ID>` | auto-extract / ask |
| `<TEAM_ID>` | auto-extract / ask |
| `<MATCH_GIT_URL>` | derived in Phase B (match repo SSH URL) |

## Auto-extract
```bash
BUNDLE_ID=$(grep -h -oE 'PRODUCT_BUNDLE_IDENTIFIER = [^;]+' *.xcodeproj/project.pbxproj 2>/dev/null | head -1 | awk -F'= ' '{print $2}' | tr -d ' ";')
TEAM_ID=$(grep -h -oE 'DEVELOPMENT_TEAM = [A-Z0-9]{10}' *.xcodeproj/project.pbxproj 2>/dev/null | head -1 | awk -F'= ' '{print $2}' | tr -d ' ;')
SCHEME=$(xcodebuild -list -json 2>/dev/null | jq -r '.project.schemes[0] // empty')   # >1 scheme → mark <multiple>
if [ -f .xcode-version ]; then XCODE_VERSION=$(cat .xcode-version | tr -d ' \n'); else XCODE_VERSION="latest-stable"; fi
REPO_OWNER=$(gh repo view --json owner -q .owner.login 2>/dev/null)
REPO_NAME=$(gh repo view --json name -q .name 2>/dev/null)
MATCH_REPO_SUGGESTION="${REPO_OWNER}/${REPO_NAME}-match"
```
Phase B: confirm BUNDLE_ID, TEAM_ID, XCODE_VERSION, SCHEME, SIMULATOR_NAME; derive
`<MATCH_GIT_URL>` = `git@github.com:<MATCH_REPO_SUGGESTION>.git`. If the match repo doesn't exist,
create it private AFTER user confirmation: `gh repo create "$MATCH_REPO_SUGGESTION" --private`.

**Also ask the test-delivery default** (sets the `IOS_TEST_DELIVERY` variable in Phase E):
> "How do you want to test iOS PRs by default?
>  · **local-simulator** (recommended) — CI verifies the build; you install the branch on your
>    simulator with `scripts/run-on-sim.sh`. No signing secrets needed for the per-story flow.
>  · **testflight** — CI uploads each green story to TestFlight before In-Test (real-device testing).
>    Requires the signing secrets below + the match bootstrap, on every story.
>  You can override per-PR with a `deliver:testflight` / `deliver:local` label."
If `testflight`: the signing secrets (Phase E) and the match bootstrap (Phase F) are REQUIRED, not
optional — `in-test.yml` runs on every green story. If `local-simulator`: they're only needed for the
ad-hoc `testflight.yml` button.

## Secrets (Phase E — after the universal `PROJECTS_TOKEN` + `PROJECT_NUMBER`)
First set the delivery default as a **variable**:
`gh variable set IOS_TEST_DELIVERY --body "<local-simulator|testflight>"` (from the Phase B answer;
unset behaves as `local-simulator`).

The secrets below are for **signing + TestFlight upload**. `ci.yml` never needs them (unsigned
simulator build). `in-test.yml` needs them **only in `testflight` delivery mode**; `testflight.yml`
(manual) always needs them. So: in `testflight` mode set them now (required); in `local-simulator`
mode they're optional until you first use the manual TestFlight button.

| Name | Source / how user obtains | How skill sets it | Agent-generated? |
|---|---|---|---|
| `MATCH_PASSWORD` | `openssl rand -base64 32 \| tr -d '/+=' \| head -c 32` (user saves in pw manager) | `printf '%s' "<PASSPHRASE>" \| gh secret set MATCH_PASSWORD --body -` | yes |
| `MATCH_GIT_BASIC_AUTHORIZATION` | GitHub PAT (`repo` scope): https://github.com/settings/tokens/new?scopes=repo&description=fastlane-match-ci&expiration=365 | `printf '%s:%s' "<USERNAME>" "<PAT>" \| base64 \| tr -d '\n' \| gh secret set MATCH_GIT_BASIC_AUTHORIZATION --body -` | no |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API key (App Manager): https://appstoreconnect.apple.com/access/api | `gh secret set APP_STORE_CONNECT_API_KEY_ID --body "<KEY_ID>"` | no |
| `APP_STORE_CONNECT_ISSUER_ID` | same page (Issuer ID UUID) | `gh secret set APP_STORE_CONNECT_ISSUER_ID --body "<ISSUER_ID>"` | no |
| `APP_STORE_CONNECT_API_KEY` | the downloaded `.p8` (once!) | `base64 < "<P8_PATH>" \| tr -d '\n' \| gh secret set APP_STORE_CONNECT_API_KEY --body -` | no |

Keep `PASSPHRASE`, `KEY_ID`, `ISSUER_ID`, `P8_PATH` in memory through Local setup. Verify `gh secret list`.

## Local setup (Phase F — HAS A SAFETY GATE)
Needed for any TestFlight upload: the manual `testflight.yml`, and `in-test.yml` when delivery is
`testflight` (then it's REQUIRED at setup, or the first green story fails). `ci.yml` and
`local-simulator` mode need no bootstrap — `scripts/run-on-sim.sh` just needs Xcode locally.

1. **Safety gate (STOP-able):** ask whether an iOS Distribution cert already exists for `<TEAM_ID>` (https://developer.apple.com/account/resources/certificates/list). If yes → STOP; surface the options (manual `.p12` import / `match nuke distribution`) and WAIT. Never run `match nuke` automatically — it breaks every existing build's update path.
2. `bundle install` (fail → `brew install ruby` + `gem install bundler`).
3. ```bash
   APP_STORE_CONNECT_API_KEY_KEY_ID="<KEY_ID>" \
   APP_STORE_CONNECT_API_KEY_ISSUER_ID="<ISSUER_ID>" \
   APP_STORE_CONNECT_API_KEY_KEY_FILEPATH="<P8_PATH>" \
   MATCH_PASSWORD="<PASSPHRASE>" \
   bundle exec fastlane match appstore
   ```
4. Cleanup: offer to `rm "<P8_PATH>"` (safe in the secret + match repo).

## docs/CI.md content (Phase G)
```markdown
## CI Workflows
Pipeline: dev-story-implementer marks In-Progress at story start → push feat/** → PR opens (`auto-pr.yml`) → lint+build+test (`ci.yml`, the merge gate) → on green, `in-test.yml` runs the **delivery** then moves the board to In-Test → `/story-done` (verify green + squash-merge + board Done).

**Test delivery (`IOS_TEST_DELIVERY` variable, default `local-simulator`; per-PR override via `deliver:testflight` / `deliver:local` label):**
- `local-simulator` — CI verifies; install the branch on your simulator with `scripts/run-on-sim.sh` (`SIMULATOR="<other device>"` to override). CI can't reach your local simulator, so this step is local.
- `testflight` — on green CI, `in-test.yml` builds signed + uploads to TestFlight (no auto-submit), comments the PR, then moves the board. Test on-device when Apple finishes processing (~5–30 min).

- `.github/workflows/auto-pr.yml` — push to `feat/**` · opens the PR (`gh pr create --fill`, so `Closes #N` carries into the PR body) if none is open.
- `.github/workflows/ci.yml` — every PR + push to main + push to `feat/**` · lint + build + tests (unsigned, simulator). Required check for merge.
- `.github/workflows/in-test.yml` — on green CI of a `feat/**` branch · `decide` delivery → (`testflight`: signed build + TestFlight upload) → board → In-Test.
- `.github/workflows/testflight.yml` — `workflow_dispatch` **only** · `gh workflow run testflight.yml` · ad-hoc signed build + TestFlight upload (no auto-submit).
- `scripts/run-on-sim.sh` — local: build + install + launch the app on a simulator (`local-simulator` mode).
- `.github/scripts/set-project-status.sh` — board helper used by the workflows (needs `PROJECTS_TOKEN` secret + `PROJECT_NUMBER` variable).

**Match storage:** `<MATCH_GIT_URL>`
**Secrets reference:** `docs/SECRETS.md`
```

## Hand-off notes
- **Test delivery is your choice.** Default `local-simulator` (run `scripts/run-on-sim.sh` to put the
  branch on your simulator) or `testflight` (auto-upload per green story). Change the default with
  `gh variable set IOS_TEST_DELIVERY ...`; override one PR with a `deliver:testflight`/`deliver:local` label.
- **CI cannot deploy to your local simulator** — that's why `local-simulator` mode does the install
  via a local script, not in CI. Only TestFlight (a real cloud-distributable build) is CI-driven.
- **No auto-release.** Merging to `main` still ships nothing to the App Store — `in-test.yml`
  (testflight mode) and `testflight.yml` upload to TestFlight only. Submitting for review stays manual.
- TestFlight does NOT auto-submit (`pilot skip_submission: true`). Build number = commit count
  (`in-test.yml` checks out full history for this).
- **testflight delivery requires the match bootstrap + signing secrets up front**, else the first
  green story fails at upload. `local-simulator` mode needs neither — only Xcode locally.
- Match is read-only in CI; only the local bootstrap (`bundle exec fastlane match appstore`) creates artifacts.
