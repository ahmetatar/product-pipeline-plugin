---
name: start-team
description: >
  Runs several of a feature's stories IN PARALLEL — a "team" of `dev-story-implementer` agents, one
  per story, each in its own git worktree. First it delegates to the `team-planner` agent, which
  finds the largest set of stories that is both mutually isolated (no shared Touch Point file, no
  shared not-yet-built contract, no dependency edge between them) and autonomy-safe (no interactive
  gate would block a headless run). You approve the proposed wave, then it fans out the
  implementers (inline `Workflow`, worktree-isolated; falls back to parallel `Agent` calls). Each
  agent codes ONE story, runs verification, gets an independent review, commits on its feat branch
  with `Closes #N`, and pushes — exactly as `dev-story-implementer` does, minus the interactive bits.
  It does NOT merge; acceptance stays per-story (the user tests each In-Test build then runs
  `/story-done`). ALWAYS use when the user wants to implement multiple independent stories of one
  feature at once. Triggers: "start team", "takımı başlat", "parallel stories", "implement F-XXX in
  parallel", "run isolated stories together". Output: a per-story outcome report (pushed / aborted /
  failed, with branch + commit + verification) and the In-Test / `/story-done` hand-off per story.
---

# Start Team — parallel story implementation

You run a **wave** of one feature's stories at the same time. Each story is implemented by a
`dev-story-implementer` agent in **team mode** (headless), in its own worktree, on its own feat
branch. You are the orchestrator: plan the wave, get the user's approval, fan out, aggregate.

This skill sits ABOVE `dev-story-implementer` — it does not replace it. The whole pipeline contract
is unchanged: each story still becomes a feat branch → PR → CI gate → In-Test → `/story-done`. You
only parallelize the code→push stage for stories that are provably safe to run together. You NEVER
merge, and you NEVER widen scope past the planner's approved wave.

---

## 1. Inputs

**The user provides:** a feature reference (`F-XXX`), optionally a subset of S-IDs to consider.

If no feature is given, ask which one. If the feature's `stories/` folder doesn't exist, STOP and
refer the user to `ba-feature-analyst`.

---

## 2. Phase 1 — Plan the wave (delegate, read-only)

Do NOT scan the stories yourself — delegate to `team-planner` so the full story set never enters your
context:

```
Agent({ description: "Plan parallel wave for F-XXX", subagent_type: "team-planner", prompt: "
  Feature: F-XXX  (folder: docs/features/F-XXX-<slug>/)
  Story subset: <list of S-IDs, or 'all'>
" })
```

Parse its report: the **Wave** table, the **Dropped** table, the **Bookkeeping lead**, and the
**Wave width** recommendation.

- `Verdict: wave-empty: yes` → STOP. Report why every story dropped (quote the Dropped table). There
  is nothing safe to run in parallel; the user implements them one at a time via `dev-story-implementer`.
- Wave width exceeds the stack cap → you will run the wave in size-capped **sub-batches** (cap-sized
  parallel groups, sequential between groups), not all at once.

---

## 3. Phase 2 — Collect the headless-blocking decisions ONCE (up front)

A headless agent can't be asked anything mid-run, so resolve the batch-wide decisions now:

- **Test-delivery (only if the project documents the choice).** If `docs/CI.md` documents
  `deliver:testflight` / `deliver:local` labels AND any wave story is flagged `UI` in the planner's
  `Deliver?` column, ask the user ONCE for the whole wave:
  > These stories will run unattended. How should they be tested in In-Test?
  > (1) local-simulator — CI verifies the build; you install each branch yourself.
  > (2) testflight — on green CI, a signed build is uploaded per story.
  Remember the answer; pass it to every agent as `deliver:`. If `docs/CI.md` documents no such
  choice, skip this — CI uses its default.
- **Design** is already guaranteed by the planner (any UI story without a design artifact was dropped
  as `not-autonomous`), so there is nothing to ask here.

---

## 4. Phase 3 — Approve the wave (mandatory gate)

Present the plan and **wait for explicit `yes`**. A wrong isolation call becomes a merge conflict for
the user, so this approval is non-negotiable:

> **Team run — F-XXX.** These **N** stories will run in parallel, each in its own worktree + feat branch:
> - S-02 welcome-view — `feat/F-001-S-02-welcome-view` — 3 touch points
> - S-03 profile-store — `feat/F-001-S-03-profile-store` — 2 touch points
> Bookkeeping lead (flips feature-analysis → In-Progress): **S-02**.
> Test-delivery: **local-simulator** (batch-wide).
> **Dropped this run:** S-01 (Draft), S-05 (conflicts with S-02 on AppState.swift), S-07 (depends on S-01).
> Each agent codes → verifies → independent review → commits `Closes #N` → pushes. I do NOT merge —
> you test each In-Test build and run `/story-done` per story.
> Proceed? (yes / change / cancel)

`change` → adjust the subset and re-plan (Phase 1). `cancel` → STOP.

Before launching, run a clean-tree check on the main working dir (`git status --short`): uncommitted
changes can pollute the worktrees' base. If dirty, STOP and ask to commit/stash first.

---

## 5. Phase 4 — Fan out the implementers

**Primary path — inline `Workflow`** (invoking this skill is the sanctioned opt-in; no `ultracode`
needed — same pattern as `po-market-analyst`). One worktree-isolated agent per wave story; each runs
`dev-story-implementer` in team mode. Inline the wave list as a `const` (do NOT use the `args` input
— it does not reliably reach the script):

```js
// inline the approved wave — NOT via args
const deliver = 'local'              // from Phase 2 ('local' | 'testflight' | 'default')
const lead    = 'S-02'               // bookkeeping lead from the plan
const cap     = 3                    // stack wave-width cap from the plan
const wave = [
  { sid: 'S-02', slug: 'welcome-view', branch: 'feat/F-001-S-02-welcome-view', path: 'docs/features/F-001-onboarding/stories/S-02-welcome-view/story-plan.md' },
  // ...one per approved wave story
]

const prompt = (s) =>
  `You are dev-story-implementer running in TEAM MODE (headless, parallel wave).\n` +
  `Read and follow skills/dev-story-implementer/SKILL.md — apply its "Team / unattended mode" override layer.\n` +
  `Story: ${s.sid}  (story-plan: ${s.path})\n` +
  `Mode: team (unattended) — never ask a question; on any STOP/ask condition, abort and return the structured outcome.\n` +
  `Bookkeeping lead: ${s.sid === lead ? 'YES — you flip feature-analysis Draft→In-Progress' : 'NO — skip the feature-analysis flip'}\n` +
  `REFERENCES.md: do NOT write it — return any structural delta as referencesDelta.\n` +
  `Deliver: ${deliver}  (use as the Gate 9 answer; do NOT launch a simulator and do NOT present an In-Test checklist)\n` +
  `Implement exactly this one story; stay inside its Touch Points + Non-Goals.`

// run in stack-capped sub-batches so one machine isn't thrashed
const outcomes = []
for (let i = 0; i < wave.length; i += cap) {
  const batch = wave.slice(i, i + cap)
  const res = await parallel(batch.map(s => () =>
    agent(prompt(s), { agentType: 'dev-story-implementer', label: s.sid, isolation: 'worktree', schema: OUTCOME_SCHEMA })
      .then(o => o ? { ...o, sid: s.sid, branch: s.branch } : { sid: s.sid, branch: s.branch, result: 'failed', reason: 'agent returned null' })
  ))
  outcomes.push(...res)
}
return outcomes
```

`OUTCOME_SCHEMA` mirrors the team-mode return value: `{ sid, result: 'pushed'|'aborted'|'failed',
branch, commit, issue, verification: [{cmd, lastLine}], review: 'approve'|'advisories', referencesDelta,
reason }`. The schema just makes validation deterministic — `dev-story-implementer` already produces
this shape in team mode.

> If `agentType: 'dev-story-implementer'` is not resolvable as a subagent in the environment, drop
> the `agentType` option — the prompt already tells a general agent to read and follow the SKILL.md.

**Fallback — parallel `Agent` calls.** If the `Workflow` tool is unavailable, fan out the identical
work as parallel `Agent` calls (one tool message, multiple calls), in waves of `cap`. The `Agent`
tool supports `isolation: "worktree"` natively — pass it so each agent gets its own worktree, exactly
as the `Workflow` path does; you do NOT hand-manage `git worktree`. The only things you lose vs the
`Workflow` path are schema-validated outcomes (parse each agent's returned summary instead) and the
single-construct sub-batching (you send each `cap`-sized wave as its own tool message, sequentially).

Each agent owns its own GitHub board move to In-Progress (Gate 8, with its own gh creds) and its own
first push — exactly as in a normal solo run. You do not touch the board.

---

## 6. Phase 5 — Aggregate & hand off

After all sub-batches return, consolidate (do NOT re-run anything that succeeded):

1. **Per-story outcome table** — for each story: `result`, branch, commit, the verification command +
   captured final line, review verdict, and (if aborted/failed) the reason verbatim. Aborted stories
   are the planner's near-misses or genuine spec defects — surface them so the user fixes the spec or
   runs them solo; never silently swallow.
2. **Apply the aggregated `REFERENCES.md` deltas** — collect every non-null `referencesDelta`. If any
   exist, append them to `docs/REFERENCES.md` in ONE edit (dedup against what's already there; write
   only genuine structural deltas, per `dev-story-implementer` Phase E rules). If none, say so. This
   is the only file you write — it is centralized here precisely so N parallel branches never collide
   on it.
3. **In-Test hand-off (per story, the user's pass — do NOT block/loop on it).** For each `pushed`
   story: its first push opened the PR and moved the board to In-Test (CI). List, per story, the
   issue link and how to test it (local-simulator: install/launch that branch yourself — team mode
   did NOT launch a simulator, since N parallel sims is unworkable; testflight: test the per-story
   signed build). Then: "Looks right? Run `/story-done` for that story. Found a bug? Tell me which
   story — I'll fix it on that branch."

> **You never merge and never move the board past In-Progress.** Each agent's first push owns the
> PR + In-Test move (GitHub Actions); acceptance is per-story via `/story-done`. The team produces N
> stories *ready for In-Test*; the human stays the acceptance gate.

---

## 7. Working principles (non-negotiable)

- **One feature per run; the wave is a whitelist.** Never add a story the planner didn't approve, and
  never bundle two stories into one agent — each agent does exactly one.
- **Isolation is the planner's guarantee; the approval gate is the user's.** Don't launch a wave the
  user hasn't explicitly approved, and don't override a drop the planner made.
- **Headless means no questions.** Every batch-wide decision is resolved in Phase 2/3, before launch.
  An agent that hits an unexpected interactive condition aborts+reports — it must never hang.
- **Centralize the shared-write files.** `feature-analysis.md` flip → lead story only; `REFERENCES.md`
  → you, once, post-wave. This is what keeps parallel branches conflict-free.
- **You orchestrate; you don't release.** No merges, no board moves past In-Progress, no PR opening.
  GitHub Actions + `/story-done` own that, exactly as in a solo run.
- **Partial success is normal.** Some stories push, some abort. Report both; the wave does not fail
  wholesale because one story did.

---

## 8. Checklist (before hand-off)

- [ ] `team-planner` consulted; wave is non-empty and conflict-free
- [ ] Batch-wide test-delivery resolved (if the project documents it); design pre-guaranteed by planner
- [ ] Wave approved by the user (explicit yes); main working tree was clean
- [ ] Fan-out launched in stack-capped sub-batches (Workflow worktree-isolated, or Agent fallback)
- [ ] Per-story outcomes aggregated (pushed / aborted / failed, with branch + commit + verification)
- [ ] Aggregated `REFERENCES.md` deltas applied once (or none)
- [ ] In-Test + `/story-done` handed off per story; nothing merged, no board move past In-Progress
