# Stack manifest — <Human Name>  (target id: `<target-id>`)

Copy to `templates/stacks/<target-id>/manifest.md` and fill EVERY section. The skill reads this and
executes exactly what it declares — no stack code in `SKILL.md`. Write `none` where a section doesn't
apply; never omit one. See `HOWTO.md` first.

## Applies when
- Project Profile `CI/CD target: <target-id>`
- Detection fallback: `<manifest file(s) that identify this stack>`.

## Runner
- `<ubuntu-latest | macos-latest | windows-latest>`

## Workflow roles
Plus the universal `auto-pr.yml` + `set-project-status.sh` (skill writes them from `shared/`). Pick
ONE release-role row (auto-deploy vs manual distribution); delete the other.

| Role | Repo path | Trigger | Purpose |
|---|---|---|---|
| ci | `.github/workflows/ci.yml` | PR + push to `main` + push to `feat/**` | `<lint/build/test>` — the merge gate |
| in-test | `.github/workflows/in-test.yml` | `workflow_run` of CI = success, on a `feat/**` branch | `<deploy on green, if any>` then board → In-Test |
| release | `.github/workflows/release.yml` | push to `main` (ignores `docs/**`) | `<auto-deploy on merge>` — IF your stack auto-releases |
| `<dist-name>` (replaces release) | `.github/workflows/<dist-name>.yml` | `workflow_dispatch` only | `<manual distribution>` — IF you have NO auto-release (e.g. iOS testflight.yml) |

Template files: `workflows/{ci,in-test,<release.yml or your dist workflow>}.yml`.

## Support files
- `<extra files to write (repo path) + template, or none>`
- `.gitignore` additions: `<list, or none>`

## Placeholders
| Placeholder | Filled from |
|---|---|
| `<PLACEHOLDER_1>` | `<auto-extract / Verified Commands → X / ask in Phase B>` |

## Auto-extract
```bash
# shell that reads repo metadata into vars; mark <unknown> when ambiguous
```

## Secrets (Phase E — after the universal `PROJECTS_TOKEN` + `PROJECT_NUMBER`)
| Name | Source / how user obtains | How skill sets it | Agent-generated? |
|---|---|---|---|
| `<SECRET_NAME>` | `<URL / dashboard steps>` | `gh secret set <NAME> --body "<value>"` | `<yes/no>` |

(No stack secrets beyond the board ones? Write `none`.)

## Local setup (Phase F)
- `<one-time commands before first CI>`. Mark any DESTRUCTIVE step as a STOP-able gate. `none` if no bootstrap.

## docs/CI.md content (Phase G)
```markdown
## CI Workflows
Pipeline: dev marks In-Progress at story start → push feat/** → PR opens (`auto-pr.yml`) → build+test (`ci.yml`) → on green: <deploy +> board In-Test (`in-test.yml`) → `/story-done` (verify green + squash-merge + board Done) → <release on merge / manual ship>.

- `.github/workflows/auto-pr.yml` — opens the PR if missing.
- `.github/workflows/ci.yml` — <when> · <what>. Required check for merge.
- `.github/workflows/in-test.yml` — on CI green (feat branch) · <deploy +> board → In-Test.
- `.github/workflows/<release.yml or dist workflow>` — <trigger> · <what>.
- `.github/scripts/set-project-status.sh` — board helper (needs `PROJECTS_TOKEN` + `PROJECT_NUMBER`).

**Secrets reference:** `docs/SECRETS.md`
```

## Hand-off notes
- `<what does NOT auto-release, manual steps left, etc.>`
