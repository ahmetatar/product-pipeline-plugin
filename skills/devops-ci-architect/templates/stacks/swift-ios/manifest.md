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
| ci | `.github/workflows/ci.yml` | PR + push to `main` + push to `feat/**` | lint · build (`generic/platform=iOS Simulator`, no simulator boot). The merge gate. **No simulator tests** — see the CI-tests note under Placeholders; tests run locally (dev-story-implementer Phase D + In-Test launch). |
| in-test | `.github/workflows/in-test.yml` | `workflow_run` of CI = success, on a `feat/**` branch | resolve delivery → (testflight: signed build + upload) → board → In-Test. 3 jobs: `decide` → `testflight`(conditional) → `board`. |
| testflight | `.github/workflows/testflight.yml` | `workflow_dispatch` **only** | build signed · upload to TestFlight (no auto-submit). Manual ad-hoc ship (same `fastlane beta` lane). |

Template files: `workflows/{ci,in-test,testflight}.yml` (siblings of this manifest). No `release.yml`.
Delivery is read from the `IOS_TEST_DELIVERY` repo variable, overridable per-PR by a
`deliver:testflight` / `deliver:local` label.

## Support files
- `fastlane/{Fastfile,Appfile,Matchfile}` → repo `fastlane/`; `fastlane/Gemfile` → repo root `Gemfile`. (Used by `testflight.yml` and by `in-test.yml` in `testflight` delivery mode.)
- `scripts/run-on-sim.sh` → repo `scripts/run-on-sim.sh` (`chmod +x`). Local helper for `local-simulator` mode — build + install + launch on a booted simulator. Substitute `<SCHEME>`, `<SIMULATOR_NAME>`, `<BUNDLE_ID>`.
- `scripts/setup-testflight.sh` → repo `scripts/setup-testflight.sh` (`chmod +x`; **no substitution** — it auto-detects bundle id / team / repo at runtime). Interactive one-time TestFlight signing bootstrap: collects every credential step by step, then in one pass creates the match repo, sets the 5 signing secrets, and runs `fastlane match` (fresh / nuke→appstore / skip). This is the recommended way to do Phase E (signing secrets) + Phase F (match) — see Local setup below.
- `.gitignore` additions: `fastlane/report.xml`, `*.ipa`, `*.dSYM.zip`, `./build/`

## Placeholders
| Placeholder | Filled from |
|---|---|
| `<XCODE_VERSION>` | auto-extract — or `latest-stable` |
| `<LINT_COMMAND>` | Verified Commands → Lint (else the template's `command -v swiftlint` guard) |
| `<SCHEME>` | auto-extract (the build-only gate uses `xcodebuild build -scheme <SCHEME> -destination 'generic/platform=iOS Simulator'`) |
| `<SIMULATOR_NAME>` | Phase B — default `iPhone 17 Pro Max`; must be a simulator the chosen Xcode ships |
| `<BUNDLE_ID>` | auto-extract / ask |
| `<TEAM_ID>` | auto-extract / ask |
| `<MATCH_GIT_URL>` | derived in Phase B (match repo SSH URL) |

> **CI is build-only — no simulator tests (deliberate).** GitHub's ephemeral macOS runners often have
> **no iOS simulator runtime pre-installed** (especially with a bleeding-edge Xcode). The first
> `xcodebuild test` then **silently downloads a multi-GB runtime (~10 min) on EVERY run** (never cached;
> the `OS=` pin is irrelevant — `build` passes in ~90s because it needs only the SDK, but `test` hangs
> on the boot/download). Confirmed signature: a single ~10-min silent gap in the Test step, then
> `IDETestOperationsObserverDebug: 6xx elapsed`. Even unit tests pay it (an iOS app's tests still boot a
> simulator). So the `ci.yml` gate runs **lint + build** with a `generic/platform=iOS Simulator`
> destination (resolves no device → no runtime needed). **Tests are not lost** — this pipeline runs them
> locally: `dev-story-implementer` Phase D (automated) before push, and the In-Test simulator launch
> after. A project that genuinely needs CI tests (e.g. a runner image with the runtime baked in, or a
> nightly job that accepts the download) can add a Test step running the Verified test command.
> `<BUILD_COMMAND>` / `<TEST_COMMAND>` are intentionally NOT used by `ci.yml` for this reason.

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

Then create the two per-story delivery **labels** — `auto-pr.yml` applies one from the commit
`Deliver:` trailer and `in-test.yml`'s `decide` reads it; `gh pr create --label` fails if the label
doesn't pre-exist, so this is required setup, not optional:
```bash
gh label create "deliver:testflight" --color 1D76DB --description "in-test.yml: build+upload signed to TestFlight before In-Test" 2>/dev/null || true
gh label create "deliver:local"      --color BFD4F2 --description "in-test.yml: verify only; install locally via scripts/run-on-sim.sh" 2>/dev/null || true
```

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

> **Recommended path: `scripts/setup-testflight.sh`.** It folds Phase E (the 5 signing secrets) and
> Phase F (match) into one interactive run: it asks for every credential up front, prints a summary,
> then on confirmation creates the match repo, sets the secrets, and runs `fastlane match`. Its
> `[fresh/nuke/skip]` cert prompt **is** the safety gate below — a human picks `nuke`, the script never
> revokes on its own. Hand the user this single command instead of the copy-paste blocks:
> `bash scripts/setup-testflight.sh` (some fastlane prompts — Apple ID password, 2FA, login-keychain
> password — are inherent and still appear). The manual steps below are the reference/fallback for when
> the script can't be used or a step needs debugging.

1. **Safety gate (STOP-able):** ask whether an iOS Distribution cert already exists for `<TEAM_ID>` (https://developer.apple.com/account/resources/certificates/list). If yes → STOP; surface the options (manual `.p12` import / `match nuke distribution`) and WAIT. Never run `match nuke` automatically — it breaks every existing build's update path. (`setup-testflight.sh` enforces this via its `[fresh/nuke/skip]` prompt — the user chooses.)
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
Pipeline: dev-story-implementer marks In-Progress at story start → push feat/** → PR opens (`auto-pr.yml`) → lint+build (`ci.yml`, the merge gate) → on green, `in-test.yml` runs the **delivery** then moves the board to In-Test → `/story-done` (verify green + squash-merge + board Done).

> **Why no tests in CI:** ephemeral runners have no iOS simulator runtime pre-installed, so `xcodebuild test` silently downloads a multi-GB runtime (~10 min) every run (the OS pin is irrelevant). Tests run **locally** instead — `dev-story-implementer` Phase D (automated) + the In-Test simulator launch — so the CI gate is lint+build only (`generic/platform=iOS Simulator`, no simulator boot, ~90s).

**Test delivery — chosen per story, default `local-simulator`.** `in-test.yml`'s `decide` job resolves the mode in this order: a `deliver:testflight` / `deliver:local` **PR label** wins; else the `IOS_TEST_DELIVERY` repo variable; else `local-simulator`.
- `local-simulator` — CI verifies the build only. Right after `dev-story-implementer` pushes, it launches the app on your simulator (`scripts/run-on-sim.sh`) **in parallel with CI** — that's the build you visually test *during* In-Test. When it looks right you run `/story-done`; find a bug and it's fixed on the same branch, re-pushed, **and re-launched on your simulator** (CI re-runs in parallel) for another pass. Re-launch any branch by hand with `scripts/run-on-sim.sh` (`SIMULATOR="<other device>"` to override). CI can't reach your local simulator, so a launch is always local.
- `testflight` — on green CI, `in-test.yml` builds signed + uploads to TestFlight (no auto-submit), comments the PR, then moves the board. Test on-device when Apple finishes processing (~5–30 min).

**How the label gets there (per-story, no manual step):** `dev-story-implementer` asks the local/testflight question at story start (Gate 9) and writes a `Deliver: local` / `Deliver: testflight` trailer into the story commit. `auto-pr.yml` reads that trailer and applies the matching `deliver:*` label when it opens the PR — so the choice is set minutes before CI goes green, with no race. To override an open PR by hand, just add/swap the `deliver:*` label before CI finishes.

- `.github/workflows/auto-pr.yml` — push to `feat/**` · opens the PR (title + body taken from the HEAD commit, so `Closes #N` carries into the PR body even on multi-commit branches; reads the `Deliver:` trailer → applies the `deliver:*` label) if none is open.
- `.github/workflows/ci.yml` — every PR + push to main + push to `feat/**` · lint + build only (`generic/platform=iOS Simulator`, no simulator boot). The merge gate. Tests run locally, not here.
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
