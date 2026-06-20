# Context Engineering for Agentic Coding CLIs

*How a multi-skill product pipeline keeps a language model's context window clean — and why every design choice in it is really a context-budget choice.*

---

## The one resource that actually runs out

When people optimize an agentic coding tool, they usually reach for the obvious knobs: a smarter model, more tools, a bigger prompt. But the thing that quietly determines whether a long-running agent stays coherent is none of those. It's the **context window** — the finite span of tokens the model can attend to at once.

Everything an agent "knows" in the moment lives there: the user's request, the files it has read, the output of every tool call, the running plan. Two things degrade as that span fills: cost (you pay per token, every turn) and quality (signal gets buried under noise — a 200-line JSON blob from one `gh` call can push the actual task out of the model's working focus). So the discipline isn't "how do I give the model more?" It's **"how do I give the model exactly what it needs, in the smallest form that's still sufficient, and nothing else?"**

That discipline is *context engineering*. This post walks through the concrete patterns a real multi-step pipeline uses to practice it — a chain of skills (Product Owner → Architect → Designer → Business Analyst → Developer → CI) and the subagents they delegate to. (One skill, `po-market-analyst`, is deliberately left out here; it deserves its own write-up as the pipeline's showcase fan-out.)

---

## First, get the mental model right: it's the model, loaded into context

Before any pattern makes sense, you have to be clear about *who* consumes these artifacts.

A file like `docs/REFERENCES.md` — the pipeline's structural map of a project — is **not** read by some special machinery inside the CLI. The CLI (the harness) has no idea what `REFERENCES.md` is. What actually happens is mundane:

1. A skill's instructions tell the **model**: "read `docs/REFERENCES.md`."
2. The model emits a `Read` tool call.
3. The harness executes it and returns the file's bytes **into the model's context window**.
4. The model reasons over those bytes.

That's it. The "agentic" part is the model; the CLI is a courier for tool calls. This has a sharp consequence: **every artifact in the pipeline is *model-facing*, and "loading a file" literally means "spending context-window tokens on it."** So the entire game is shaped by token economics, not by any CLI-side index or cache. When we say "keep the backlog out of the conversation," we mean keep those tokens out of the model's window.

Once that clicks, the patterns below stop looking like style preferences and start looking like budget decisions.

---

## Pattern 1 — Pre-digest the world; don't make the agent explore it

**The problem.** An agent that needs to find where feature code lives, or which build command is real, can do it the expensive way: `grep`, `find`, `ls -R`, read ten files, infer the convention. Every one of those tool results lands in context. Repo-wide exploration is the single biggest avoidable context sink in a coding agent.

**The pattern.** Do that exploration **once**, at project setup, and distill the result into a small, curated map the agent reads instead of re-deriving. In this pipeline that's `docs/REFERENCES.md`, written by the `system-architect` skill: a Folder Map (one line per directory + its role), Key Files (manifest, entry point, design-token path), Verified Commands (the build/test/lint commands that were *actually run* during setup), and Conventions.

Two subtleties make this work:

- **It's an index, not the content.** `REFERENCES.md` says *"feature code lives in `src/features/`, tokens at `X`."* The agent then opens the exact target file directly — it navigates from the map instead of searching for the path. The expensive discovery is amortized into a one-time write; every downstream reader pays a single cheap `Read`.

- **Stable headings are a contract.** Downstream skills rely on `## Folder Map`, `## Key Files`, `## Verified Commands` being named exactly that. The headings are an interface, not prose — which is *why* the file must stay small and well-structured. A small curated file is cheaper to read whole than to `grep` for a fragment; the heading contract is the insurance for when it eventually grows.

**The discipline that protects it.** Because the file's value is "small enough to load whole," polluting it is a performance regression, not just untidiness. So `dev-story-implementer` writes to `REFERENCES.md` **only** when a story introduces a genuinely new structural fact (a new top-level dir, convention, or command) — and never restates a path that already conforms to the canonical Folder Map. The default is *no edit*. A map that accumulates redundant entries stops being a fast-lookup contract and becomes just another file to wade through.

---

## Pattern 2 — In fan-out, isolate the output: artifact to disk, index to the caller

**The problem.** When a skill needs to produce N things (N story specs, N feature blocks, N competitor profiles), the naive approach is to generate them inline. Each generated artifact accumulates in the orchestrating skill's context. By the tenth, the orchestrator is drowning in its own output and has no room left to reason across the set.

**The pattern.** Fan the work out to subagents, one per item, and design the return so the **expensive artifact lands on disk while only a compact index returns to the caller.** This is the same disk-and-index philosophy as `REFERENCES.md`, applied to generation.

`ba-feature-analyst` is the clearest example. After it has done the cross-story reasoning (Phase B/C — the barrier), it delegates each `story-plan.md` to a `story-plan-writer` subagent, one call per story, in parallel. Each subagent:

- writes its own file (a different path per story — no write conflict), and
- returns a **<150-word summary** (touch points, ACs, dependencies, which feature-DoD items it covers).

The full, long story spec never re-enters the orchestrator's window; it gets back an index it can scan for the cross-story review. The same shape recurs across the pipeline's subagents, each with a tight return budget tuned to its job:

| Subagent | Returns | Budget |
|---|---|---|
| `story-plan-writer` | story summary (file written to disk) | < 150 words |
| `feature-drafter` | one feature detail block | < 200 words |
| `backlog-auditor` | schema/dup/dep/conflict report | < 300 words |
| `codebase-scanner` | recon report | tight; reuse list uncapped (see Pattern 5) |
| `code-reviewer` | review verdict | < 600 words |

The win is wall-clock *and* context: parallel work, and the orchestrator's window holds N short indexes instead of N long artifacts.

---

## Pattern 3 — Seal the subagent; then complete its input

**The problem.** A subagent that can wander (grep the repo, read arbitrary files, ask the user) is a context risk and a correctness risk: it pulls unpredictable noise into its own window and can drift from the caller's intent. But the obvious fix — sealing it (no `Grep`, no `Bash`, no user interaction) — creates a new hazard: a sealed agent that's missing an input has nowhere to turn. It can't go find the answer.

**The pattern.** Seal the subagent **and** make the caller's input contract match the subagent's output contract — exactly. Whatever the output template demands, the input must carry.

`story-plan-writer` is sealed to `Read`/`Write`/`Glob` — it cannot explore the codebase. Its output template, though, has many mandatory sections: Touch Points (with a locator on every `[MODIFY]`), Read First, Data Contracts, Edge Cases, Non-Goals, Observable Behavior, Verification. So the fix was to widen `ba-feature-analyst`'s fan-out call to pass **all** of that per-story material, with an explicit note in the call: *"the writer is sealed — pass EVERYTHING its template sections need."* The input contract being narrower than the output contract is a latent bug: it forces the sealed agent to either leave sections thin or invent them. Aligning the two contracts is what makes sealing safe.

A related micro-optimization: pass the **template by path**, not pasted inline. In a fan-out of N parallel calls, pasting the template inlines N copies of it across N concurrent prompts; passing the path lets each subagent read it once. Same content, a fraction of the in-flight tokens.

---

## Pattern 4 — Surface gaps with a signal; never fabricate to fill them

**The problem.** This is the failure mode that pairs with Pattern 3. A sealed agent told "never leave a section blank" and "you can't go look it up" has one escape hatch left: **make something up.** Fabrication is the most dangerous context failure because it's invisible — a plausible-but-wrong `Data Contract` or `Edge Case` flows downstream and silently corrupts everything built on it.

**The pattern.** Give every subagent a structured way to say *"I didn't have the input for this"* — a sentinel in the artifact plus a flag in the return — and make the **caller act on the flag.**

- `story-plan-writer`: if a required section's source material wasn't provided, it writes the section's `None.`/`n/a` sentinel **and** emits a `missing-input: <section>` line. `ba-feature-analyst` Phase E treats a non-empty `missing-input` as a Phase-C gap to fix and re-issues that one story — it does **not** ship a story with a silently-fabricated section.
- `feature-drafter`: when a cited report section is too thin to support a field honestly, it drafts conservatively from the stub and lists what it assumed on an `Assumptions / thin-source` line (stripped from the final file — it's a signal, not content). `po-backlog` re-cites a stronger section or folds the gap into the feature's Open questions.
- `codebase-scanner`: reports its own blind spots in an `## Areas Not Covered` section so the caller knows to run a follow-up.

The throughline: **an honest gap is cheap to fix; a fabricated fill is expensive to discover.** A flag the caller ignores is no better than no flag, so each of these is paired with an explicit caller-side action. The signal and the response are designed together.

---

## Pattern 5 — No silent caps

**The problem.** Truncation reads as completeness. If a scanner returns 12 reuse targets because that's all that fit in a word budget, the caller assumes those are *all* the reuse targets — and the coding agent later greps for the helper that got cut. Worse, a hard `--limit` on a query (e.g. "list up to 200 project items") fails closed: the item you wanted was #214, you get "not found," and nothing tells you the list was capped.

**The pattern.** When a bound is hit, **say so.** `codebase-scanner`'s recon mode treats reuse-target completeness as *overriding* its brevity budget — it will not drop a genuine reuse target to save words, and if it drops lower-relevance files it ends the table with an explicit `… N more lower-relevance files omitted`. Where a tool genuinely has a ceiling (a paginated API limit), the fix is to disclose the ceiling rather than present a capped result as exhaustive. Silence implies "I covered everything" — only imply that when it's true.

This is the same instinct as Pattern 4 applied to *quantity* instead of *quality*: make the limit visible so the caller can decide, rather than letting a bound masquerade as the full picture.

---

## Pattern 6 — Lazy-load templates and heavy references

**The problem.** A skill's own instructions live in *its* context every time it runs. If a skill inlines a 300-line output template into its body, every invocation pays for those 300 lines whether or not it reaches the write step.

**The pattern.** Keep templates as sibling files and read them **at write-time only**, and read **only the one you need.** `pd-design-foundation`, `system-architect`, and `po-backlog` all do this explicitly: *"Templates live as sibling files … read at write-time, NOT inline here, to keep the upfront skill load small."* `pd-design-foundation` goes further — for a multi-platform design system it reads only the matching platform's token template (`tokens-swiftui.md` *or* `tokens-css.md`, not all five): *"Do NOT pull templates for platforms you're not targeting — that's the point of splitting them."*

The same laziness applies to heavy *reference* docs, not just templates. `dev-story-implementer` loads the design system and tokens **only** when a story actually has a non-empty `## Design References` *and* a UI touch point — pure logic/data/infra stories skip it entirely. And nearly every skill reads `docs/log.md` as `tail -n 15`, never the whole growing file. Load on demand, scoped to the branch you're actually on.

---

## Pattern 7 — Delegate the *right* work (and keep the rest in the main context)

**The problem.** "Delegate everything to subagents to save context" is wrong. Subagents have a setup cost and a round-trip; over-delegating is its own waste. The skill is knowing *what* to offload.

**The pattern.** There's a clean decision rule, and the contrast between two parts of the pipeline makes it concrete.

`github-projects-helper` exists to keep `gh project … --format json | jq` orchestration out of the main context. A single `gh project item-list --format json` can return a huge blob from which you need one `item_id`. The helper consumes that blob *inside* its own window and returns five flat `key: value` lines. It runs on a cheap model (haiku) and is invoked on **every** story transition. That profile — **non-interactive, JSON-parse-heavy, high-frequency** — is exactly what justifies a sealed executor.

Now contrast `devops-ci-architect`, which also does plenty of GitHub work (`gh secret set`, `gh variable set`, branch protection) — all in the **main context**. Should it be offloaded too? No, and the reasons sharpen the rule:

- **Interactive** — secret setup needs the user (collect a PAT, confirm a destructive step). A sealed subagent can't talk to the user, so this *cannot* be delegated.
- **One-time** — it runs once per project; a round-trip wouldn't amortize.
- **Low-verbosity** — `set`/`list` produce trivial output; the request body for branch protection is *authored*, not parsed from a blob.

So the rule: **offload when an operation is non-interactive AND (parse-heavy OR high-frequency); keep it inline when it's interactive, one-time, or low-verbosity.** The one genuine leak in the inline path was the branch-protection API call dumping its large success object into context — fixed by discarding the body and surfacing a one-line result. Offloading wasn't the answer there; *quieting* was.

---

## Pattern 8 — Build gates that don't *force* fabrication

**The problem.** Quality gates and anti-fabrication can collide. A gate that says "re-run any competitor profile with fewer than 2 negative themes" sounds like quality control. But if an app genuinely has a tiny review corpus, the honest profile *has* fewer than 2 negative themes — and re-running can't conjure reviews that don't exist. The gate either loops forever or pressures the agent to pad. A gate meant to *prevent* thin data ends up *manufacturing* fake data.

**The pattern.** A gate must distinguish "the agent under-performed" from "the world is genuinely thin," and accept the latter with a flag instead of fighting it. The fix here was to split the gate: zero sources is a failed run (re-run); few themes is checked against a `Review corpus: N` signal the researcher now emits — under-researched (re-run once, capped) versus genuinely small corpus (accept and flag in the limitations appendix, with downstream counts marked lower-confidence).

The same anti-fabrication-as-default spirit shows up in the `code-reviewer`, which audits an implementation against its story contract: it checks Touch Points, Data Contracts, Non-Goals, Observable Behavior, **and** Edge Cases — but it's explicitly a *conformance* audit, not freelance bug-hunting, and it states that correctness rests on the story's tests rather than claiming to have verified it. It also reports a test-coverage signal (a spec-conformant diff with zero tests is flagged as a risk, not silently approved). Honesty about the limits of what was checked is itself a context-engineering practice: it keeps a false "all clear" from propagating.

---

## Pattern 9 — Match the model to the job

Context engineering isn't only about tokens; it's about spending the *right* model on the right step. The subagents tier deliberately:

- **haiku** (cheap, fast) for mechanical extraction and plumbing: `codebase-scanner`, `github-projects-helper`, `story-publisher`.
- **sonnet** for synthesis and judgment whose output is consumed downstream as if it were authoritative: `feature-drafter` (its feature promises seed the BA's contracts), `code-reviewer`, `design-prompt-writer`.
- **inherit** (no `model:` field → runs on the session's model) for subagents that produce blindly-followed artifacts and should rise with the orchestrator: `story-plan-writer`, `backlog-auditor`. On an Opus session, these run on Opus — appropriate, because a wrong story spec or a missed schema mismatch is expensive.

The principle: **mechanical/extractive → cheap; synthesis/review → mid; blindly-followed artifacts → inherit the orchestrator's tier.** Documentation and frontmatter must agree on this, or the cost/quality intent silently drifts.

---

## Two cross-cutting habits

A couple of practices don't fit one pattern but show up everywhere:

- **Single source of truth.** `REFERENCES.md` is *the* structural map; nothing invents paths outside it. When a subagent embeds a copy of a shape that also lives in a template, note which one wins, so the two can't drift apart unnoticed.

- **Put conditional guidance where the model will see it, not only in the README.** The README says "bump `dev-story-implementer` to plan mode for large/ambiguous stories" — but that's advice for the *human* choosing a model up front. The running model never sees it. So the escalation cue belongs **in the skill body**: plan mode is *not* required per story (the story spec is already the plan; a lightweight per-file confirm runs every time), but the skill itself now tells the agent to recommend plan mode when a story is genuinely large or its spec looks stale. Guidance the executor can't see is guidance that doesn't run.

---

## The checklist

If you're building an agentic pipeline of your own, these are the questions worth asking of every skill and subagent:

1. **Is exploration amortized?** Is there a pre-digested map (like `REFERENCES.md`) so agents navigate instead of searching? Is it kept small and un-polluted?
2. **In fan-out, does the artifact go to disk and only an index return?** Is each subagent's return budget tuned to its job?
3. **For every sealed subagent, does the input contract cover the whole output contract?** Pass templates by path, not pasted.
4. **Can a subagent signal a missing input — and does the caller act on it?** Is fabrication structurally impossible, or just discouraged?
5. **Does every bound disclose itself?** No silent truncation, no fail-closed caps masquerading as empty results.
6. **Are templates and heavy refs loaded lazily, scoped, and at write-time?** Is the log read as a tail?
7. **Is delegation reserved for non-interactive, parse-heavy or high-frequency work?** Is verbose inline output quieted?
8. **Do quality gates distinguish under-performance from genuine sparsity** — accepting honest gaps instead of forcing fakes?
9. **Does each step run on the right model tier, and do the docs agree?**

None of these are exotic. They're all the same instinct, applied relentlessly: **the context window is a budget, every token in it should be earning its place, and the absence of information should be visible — never silently invented.** Get that right and a long pipeline of agents stays sharp from the first skill to the last.
