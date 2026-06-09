#!/usr/bin/env bash
# setup-testflight.sh — interactive one-time TestFlight signing bootstrap (swift-ios stack).
#
# Replaces the copy-paste credential dance: it COLLECTS every value up front (step by step),
# shows a summary, then on your confirmation runs the whole thing in ONE pass —
#   create the private match repo · set the 5 signing secrets · fastlane match (nuke→appstore or fresh).
# Re-runnable. Secrets are read silently and piped straight into `gh secret set` / fastlane env —
# never written to disk, never echoed (the generated MATCH_PASSWORD is shown ONCE so you can save it).
#
# Some fastlane prompts (Apple ID password, 2FA code, login-keychain password) are inherent and will
# still appear interactively — they can't be scripted away safely. This script removes the rest.
#
# Prereqs: gh (authed, scopes repo+project) · Ruby >= 3.0 with bundler · the repo's Gemfile + fastlane/
# already generated (devops-ci-architect). Run from the iOS project root.
set -euo pipefail

ask()        { local p="$1" d="${2:-}" v; read -r -p "$p${d:+ [$d]}: " v || true; printf '%s' "${v:-$d}"; }
ask_secret() { local p="$1" v; read -r -s -p "$p: " v || true; printf '\n' >&2; printf '%s' "$v"; }
have()       { command -v "$1" >/dev/null 2>&1; }
die()        { echo "✗ $*" >&2; exit 1; }

# ---- prereqs ----
have gh   || die "gh not found — https://cli.github.com"
gh auth status >/dev/null 2>&1 || die "gh not authenticated — run: gh auth login (scopes: repo, project)"
have bundle || die "bundler not found — install Ruby >= 3.0 then: gem install bundler"
ruby -e 'exit(Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.0"))' 2>/dev/null \
  || die "Ruby >= 3.0 required (have: $(ruby -v 2>/dev/null)). e.g. 'brew install ruby' + put it on PATH."
[ -d fastlane ] || die "no fastlane/ here — run this from the iOS project root (devops-ci-architect generates it)."

echo "▸ Auto-detecting project values…"
BUNDLE_ID=$(grep -h -oE 'PRODUCT_BUNDLE_IDENTIFIER = [^;]+' ./*.xcodeproj/project.pbxproj 2>/dev/null | head -1 | awk -F'= ' '{print $2}' | tr -d ' ";')
TEAM_ID=$(grep -h -oE 'DEVELOPMENT_TEAM = [A-Z0-9]{10}' ./*.xcodeproj/project.pbxproj 2>/dev/null | head -1 | awk -F'= ' '{print $2}' | tr -d ' ;')
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null) || die "not in a GitHub repo (gh repo view failed)."
GH_USER=$(gh api user -q .login 2>/dev/null || true)

# ===================== PHASE 1: COLLECT =====================
echo
echo "=== TestFlight setup — I'll ask for everything first, then run it all at once ==="
echo
BUNDLE_ID=$(ask "Bundle ID" "$BUNDLE_ID")
TEAM_ID=$(ask "Team ID (your App Store Connect API key must belong to this team)" "$TEAM_ID")
GH_USER=$(ask "GitHub username" "$GH_USER")
MATCH_REPO=$(ask "Match repo (created private if missing)" "${REPO}-match")

echo
echo "— App Store Connect API key (role: App Manager, team $TEAM_ID): https://appstoreconnect.apple.com/access/api"
ASC_KEY_ID=$(ask "  Key ID")
ASC_ISSUER_ID=$(ask "  Issuer ID")
P8_PATH=$(ask "  Path to the .p8 file")
P8_PATH="${P8_PATH/#\~/$HOME}"
[ -f "$P8_PATH" ] || die ".p8 not found at: $P8_PATH"

echo
echo "— GitHub PAT (repo scope, lets CI clone the match repo): https://github.com/settings/tokens/new?scopes=repo"
GH_PAT=$(ask_secret "  PAT (hidden)")

echo
APPLE_ID=$(ask "Apple ID email (for fastlane's portal login)")

echo
echo "— MATCH_PASSWORD (encrypts the match repo)"
if [ "$(ask "  Auto-generate? (y/n)" "y")" = "y" ]; then
  MATCH_PW=$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)
  echo "  ⚠️  GENERATED MATCH_PASSWORD — SAVE THIS in your password manager NOW (it cannot be recovered):"
  echo "      $MATCH_PW"
  ask "  Saved it? press Enter to continue" >/dev/null
else
  MATCH_PW=$(ask_secret "  MATCH_PASSWORD (hidden)")
fi

echo
echo "— Existing Apple Distribution certificate for $TEAM_ID? (developer.apple.com → Certificates)"
echo "    fresh = none yet (create clean)  ·  nuke = exists but UNUSED (revoke + recreate)  ·  skip = secrets only, no match"
CERT_MODE=$(ask "  [fresh/nuke/skip]" "fresh")

# ===================== PHASE 2: CONFIRM =====================
echo
echo "=== Summary ==="
cat <<SUM
  Repo:            $REPO
  Match repo:      $MATCH_REPO   (git@github.com:$MATCH_REPO.git)
  Bundle ID:       $BUNDLE_ID
  Team ID:         $TEAM_ID
  GitHub user:     $GH_USER
  ASC Key ID:      $ASC_KEY_ID
  ASC Issuer ID:   $ASC_ISSUER_ID
  .p8:             $P8_PATH
  Apple ID:        $APPLE_ID
  PAT:             (hidden, ${#GH_PAT} chars)
  MATCH_PASSWORD:  (hidden)
  Cert mode:       $CERT_MODE
SUM
[ "$(ask "Proceed? (y/n)" "n")" = "y" ] || { echo "Aborted."; exit 0; }

# ===================== PHASE 3: EXECUTE =====================
echo
echo "▸ 1/4  Match repo…"
if gh repo view "$MATCH_REPO" >/dev/null 2>&1; then echo "   already exists"; else gh repo create "$MATCH_REPO" --private && echo "   created (private)"; fi

echo "▸ 2/4  Signing secrets…"
printf '%s' "$MATCH_PW"                  | gh secret set MATCH_PASSWORD                --repo "$REPO" --body -
printf '%s:%s' "$GH_USER" "$GH_PAT" | base64 | tr -d '\n' | gh secret set MATCH_GIT_BASIC_AUTHORIZATION --repo "$REPO" --body -
gh secret set APP_STORE_CONNECT_API_KEY_ID --repo "$REPO" --body "$ASC_KEY_ID"
gh secret set APP_STORE_CONNECT_ISSUER_ID  --repo "$REPO" --body "$ASC_ISSUER_ID"
base64 < "$P8_PATH" | tr -d '\n'         | gh secret set APP_STORE_CONNECT_API_KEY     --repo "$REPO" --body -
echo "   5 secrets set"

echo "▸ 3/4  bundle install + fastlane match…"
bundle install
if [ "$CERT_MODE" != "skip" ]; then
  export FASTLANE_USER="$APPLE_ID"
  export APP_STORE_CONNECT_API_KEY_KEY_ID="$ASC_KEY_ID"
  export APP_STORE_CONNECT_API_KEY_ISSUER_ID="$ASC_ISSUER_ID"
  export APP_STORE_CONNECT_API_KEY_KEY_FILEPATH="$P8_PATH"
  export MATCH_PASSWORD="$MATCH_PW"
  if [ "$CERT_MODE" = "nuke" ]; then
    echo "   match nuke distribution (DESTRUCTIVE — match will ask you to confirm)…"
    bundle exec fastlane match nuke distribution
  fi
  echo "   match appstore…"
  bundle exec fastlane match appstore
else
  echo "   skipped match (cert mode: skip)"
fi

echo "▸ 4/4  Verify…"
gh secret list --repo "$REPO"
echo
echo "✓ TestFlight signing is set up."
echo "  Delete the local .p8 now (it's safe in the secret + match repo):  rm \"$P8_PATH\""
