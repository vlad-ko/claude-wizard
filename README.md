# Wizard v3: discipline with teeth

**Turn Claude Code into a senior architect that orchestrates a team — and audits itself.**

Wizard v1 turned Claude Code from a fast coder into a careful one: read before writing, test before implementing, attack your own code before committing. v2 made the careful thread the **orchestrator** of a team of specialist agents driving a whole cohort of PRs to merge-ready in parallel. **v3 is what three more months of running that team on a production codebase taught us:** a rule that is merely *guidance* gets violated the moment momentum picks up. So in v3 every rule that mattered became an **ordered step that must produce an artifact** — a filed plan, a mutation that was actually run, a block in the PR body, a ledger entry — and the orchestration loop got **auditors of its own**: a cheap check-in agent that writes a durable ledger, a second lead whose only job is to audit the first, and a capacity gate that measures instead of guesses.

If v1 was "think before you code" and v2 was "design, then delegate, then verify — in parallel," v3 is "**a rule with no artifact has no teeth.**"

## Your role: conductor, not task-giver

You are **not** here to write task breakdowns or code. The agents do that. **Your job is to keep the flow moving from idea → issue → PR → production** — and nothing below that altitude.

- **Set direction.** You bring the *idea* — not the task list. Turning it into a structured issue with acceptance criteria is the `issue-maintainer` agent's first step.
- **Make the product and judgment calls.** When an agent hits an ambiguous requirement or a "which behavior is correct?" fork, that's yours. The ensemble builds the thing right and defers *deciding what's right* to you.
- **Unblock.** When the orchestrator notifies you it's gated on a decision, a credential, or a merge, you clear it — then it resumes the whole cohort. v3 never silent-waits on you; a block fires a notification.
- **Merge.** The orchestrator drives every PR to merge-ready and declares it exactly once, at a named SHA; you press the button. The merge is the one piece of the cycle that stays human.

## What it is

`/wizard` is a Claude Code [skill](https://docs.anthropic.com/en/docs/claude-code/skills) — a markdown playbook that changes how Claude operates for the duration of a task — plus a roster of specialist [subagents](https://docs.anthropic.com/en/docs/claude-code/sub-agents) it dispatches. It runs in two modes:

- **Direct mode** — a single thread runs the whole 8-phase lifecycle itself (v1's behavior, intact).
- **Delegated mode** — the thread you talk to becomes an **orchestrator**: it decomposes and files the plan, dispatches specialists to build and verify each phase in its own worktree, and owns the pull-request review cycle. Workers commit locally and hand back; the orchestrator pushes, opens the PR, and drives every reviewer finding to resolution.

A complexity gate decides which mode you get. A one-line fix never pays the multi-agent tax.

## The ingredients

> **Want the whole picture first?** [`ARCHITECTURE.md`](ARCHITECTURE.md) lays out the system narrative and the diagrams — the full cycle, the orchestrator/worker split, the event-driven pipeline with its auditors, and the principle ladder.

**The foundation (v1):**

1. **`CLAUDE.md`** — your project's rules file. `/wizard` reads it first, every time, and it is the *only* thing a dispatched subagent inherits besides its brief. v3 adds a discipline for it: every always-resident file is held to a **summary + pointer budget**, because every byte in it is re-read on every API call of every agent.
2. **Issues as the source of truth** — every change gets an issue with acceptance criteria before code, and the boxes are checked off *at merge time*.
3. **Codebase-first exploration** — grep before you reference. No hallucinated APIs.
4. **TDD, no exceptions** — failing tests first, minimal implementation, verify.
5. **Branch-per-concern** — one focused PR at a time, never stacked.

**The orchestration layer (v2):**

6. **The orchestrator/worker split** at `git commit` — the worker builds and commits; the orchestrator verifies the diff, pushes, opens the PR, and monitors.
7. **The agent ensemble** — gate-routed and mediated: persona lenses and a doc librarian harden the requirements, an architect designs and writes the failing-test spec, backend and frontend specialists build in parallel off that contract, and an independent QA pass plus the lenses verify. Generator ≠ evaluator.
8. **The parallel pipeline** — a cohort of up to ten PRs driven to merge-ready concurrently, refilled as PRs merge.
9. **The AI-review gate** — an independent reviewer that did not build the change; every finding routed back to the owning specialist or rebutted, until clean and quiescent.

**The teeth (new in v3):**

10. **Decompose before dispatch.** On any multi-concern finding the orchestrator's first act is a **phased plan filed on the issue** — never a builder brief. The phase ledger *is* the acceptance-criteria ledger. *Real precedent: two "single fixes" reached 20 and 11 modified files with the small-PR rule in force the whole time.*
11. **Tests assert behavior, not success — verified by mutation.** Three sub-rules (assert the state change; fixtures must not make the defect undetectable; verify the teeth by changing ONE line, watching RED, editing it back) and one hard ban: never delete a file to force a test outcome. *Real precedent: a pre-launch sweep found six green tests standing guard over the bugs they should have caught.*
12. **Four portable principles**, each with its own reference doc and a pre-commit checklist line: [absence is not a value](skill/reference/absence-is-not-a-value.md) (refuse; never render a missing read as `0`), [remove the mechanism, don't add a guard](skill/reference/remove-the-mechanism.md) (could a new caller next year still do the wrong thing?), [the adjacency check](skill/reference/adjacency-check.md) (a fix is checked against the known-defect inventory, not only its own bug — with a required block in the PR body), and the [three design audits](skill/SKILL.md#phase-2-codebase-exploration) in Phase 2.
13. **Event-driven orchestration.** No recurring tick. The orchestrator wakes on every push, every subagent return, every user turn, and before answering any question about PR state — and the idle test is a **durable ledger**, not the absence of an event. Findings before builds, always.
14. **The loop's own auditors.** `pr-checkin` (cheap, mechanical, writes the ledger) escalates to `pr-manager` (judgment, routed briefs, STUCK detection). `resource-manager` budgets test-running agents against **measured** cores and fails closed. `accountability-lead` audits the orchestrator and reports **to you**. `backlog-manager` keeps the tracker converging. `report-maker` keeps a living dashboard.
15. **Codify the lesson while it is hot.** Five named triggers, a routing table for where a lesson goes, and one rule: no new rule without its incident.

## The difference

You give it one line:

> *"Pick up epic #1234, and fold in the gaps we found in testing."*

You get one line back when it's done:

> *Cohort of 8 PRs merge-ready in parallel. #1234 is ready at `a1b2c3d`; one product question for you on #1240.*

Everything between those two lines is the orchestrator's job, not yours: decompose and file the phases, run the ensemble per phase in its own worktree, push and open each PR, route every reviewer finding back to the owning specialist, sweep the lane on every event, and — while a second lead audits that it is *clearing* findings rather than *reporting* them — declare each PR merge-ready once and hand you the merge.

Same output either way — working code that ships without the 2am "why is this broken in production" follow-up. The difference is that the checklist is the orchestrator's, the audit of the orchestrator is an agent's, and you stay at the conductor's altitude.

## Upgrading from v2

v3 is a superset. Direct mode, the ensemble, and the pipeline are all still here; v3 adds the filed-artifact steps, the principle docs, six agents, and replaces the pipeline's clock with events. **You don't change how you invoke `/wizard`.** Re-run the installer — it overwrites the skill and reference directories and adds the new agents; your persona-lens instances are untouched. Full list: [`CHANGELOG.md`](CHANGELOG.md).

**Still want v2 or v1?** Both are preserved at git tags:

```bash
git clone https://github.com/vlad-ko/claude-wizard
cd claude-wizard && git checkout v2   # or v1
```

## Install

**One command** from your project root:

```bash
curl -sL https://raw.githubusercontent.com/vlad-ko/claude-wizard/main/install.sh | bash
```

This installs the `/wizard` skill into `.claude/skills/wizard/` (with its `reference/` docs) and the agent roster into `.claude/agents/`.

Or manually:

```bash
BASE=https://raw.githubusercontent.com/vlad-ko/claude-wizard/main

# Skill
mkdir -p .claude/skills/wizard/reference .claude/agents
for f in SKILL.md CHECKLISTS.md PATTERNS.md; do
  curl -fsSL "$BASE/skill/$f" -o ".claude/skills/wizard/$f"
done

# Reference docs (loaded on demand by the skill)
for f in threading-model parallel-pipeline pr-review-cycle complexity-gate ensemble-dispatch \
         phased-decomposition tests-assert-behavior absence-is-not-a-value remove-the-mechanism \
         adjacency-check context-economics capacity-and-worktrees \
         accountability-and-review-channels codify-the-lesson domain-user-lens.template; do
  curl -fsSL "$BASE/skill/reference/$f.md" -o ".claude/skills/wizard/reference/$f.md"
done

# Agent roster
for f in architect backend-expert frontend-expert qa-engineer doc-librarian issue-maintainer \
         backlog-manager pr-checkin pr-manager resource-manager accountability-lead report-maker; do
  curl -fsSL "$BASE/agents/$f.md" -o ".claude/agents/$f.md"
done
```

## Usage

In Claude Code, type:

```
/wizard implement the user authentication flow described in the issue
```

Claude responds with `## [WIZARD MODE]` and begins the phased approach, signaling each transition:

```
## [WIZARD MODE] Phase 1: Understanding & Planning
...
## [WIZARD MODE] Phase 2.5: Phased Decomposition
...
## [WIZARD MODE] Phase 3: Test-Driven Development
...
```

You can also invoke it mid-conversation:

```
/wizard this is getting complex — let's be more systematic about this
```

## Customizing the agents

The roster is generic by design. Two things need *your* attention before the ensemble fits your product:

- **`skill/reference/domain-user-lens.template.md` is a TEMPLATE, not a ready agent** (installed to `skills/wizard/reference/`, deliberately outside `.claude/agents/` so placeholder content can never be dispatched). Copy it once per distinct persona in your product (`admin-lens.md`, `end-user-lens.md`, …), set each copy's frontmatter `name:` to match the filename, and fill in that persona's real surfaces, rules, and failure modes.

- **`agents/backend-expert.md` and `agents/frontend-expert.md`** point at "your project's `CLAUDE.md`" for the framework-specific rules. The more complete — and the *shorter* — your `CLAUDE.md`, the sharper they get. See [`skill/reference/context-economics.md`](skill/reference/context-economics.md) for the summary + pointer discipline.

Everything else references "your test runner / your CI / your review bot" rather than a specific stack. The methodology is the product; the stack is yours.

## What's included

| Path | Purpose |
|------|---------|
| `skill/SKILL.md` | The orchestrator skill — the 8-phase lifecycle, held to a summary + pointer budget |
| `skill/CHECKLISTS.md` | Quick-reference checklists per phase, including the wake and clean-slate checklists |
| `skill/PATTERNS.md` | Portable patterns and anti-patterns: concurrency, absence, mechanism removal, mutation, orchestration |
| `skill/reference/threading-model.md` | The orchestrator/worker split, the liveness probe, the failure recipes |
| `skill/reference/parallel-pipeline.md` | Event-driven wakes, the ledger idle test, findings before builds, build-ahead |
| `skill/reference/pr-review-cycle.md` | Four finding surfaces, one canonical detector, the SHA-bound merge-ready gate |
| `skill/reference/complexity-gate.md` | The three bands, the triage manifest, hybrid routing |
| `skill/reference/ensemble-dispatch.md` | The gate-routed mediated sequence, file ownership, the verification loop |
| `skill/reference/phased-decomposition.md` | Phase shapes, slicing, dispositions, the builder-brief contract |
| `skill/reference/tests-assert-behavior.md` | The three sub-rules, the one-line mutation, test at the seam |
| `skill/reference/absence-is-not-a-value.md` | Refuse, never substitute; the banned-shape catalog; three outcomes |
| `skill/reference/remove-the-mechanism.md` | The operative test and the four-rung ladder |
| `skill/reference/adjacency-check.md` | The pattern inventory, outward + inward, the PR block |
| `skill/reference/context-economics.md` | The cost model, the summary + pointer budget, orchestrator hygiene |
| `skill/reference/capacity-and-worktrees.md` | The core-derived budget, worktree gotchas, the clean slate |
| `skill/reference/accountability-and-review-channels.md` | The second lead and the second review channel |
| `skill/reference/codify-the-lesson.md` | Triggers, routing, and the bar for a new rule |
| `skill/reference/domain-user-lens.template.md` | The persona-lens template (instantiate per persona) |
| `agents/*.md` | The twelve-agent roster |
| `ARCHITECTURE.md` | The system narrative and diagrams |
| `CHANGELOG.md` | What changed in each version |

## How it works

`/wizard` wires the ingredients above into an enforced sequence — read the rules, define "done," explore the code and run the design audits, file the phased plan, write failing tests and prove their teeth, implement minimally, verify, self-review against the defect inventory, then open a PR and drive every finding to resolution. In delegated mode it adds the gate-routed ensemble and an event-driven pipeline that keeps wait windows productive and audits itself.

There's no magic. It encodes the habits of senior engineers into a repeatable process — and, in v3, the habit of noticing when the process itself has stopped being followed. Claude doesn't lack the *ability* to do these things — it lacks the *process* to do them consistently. `/wizard` is that process.

## Contributing

This project is small, opinionated, and hungry for fresh ideas. PRs welcome.

- **Framework overlays** — a `frameworks/<stack>/` directory with stack-specific phase additions people can merge into their SKILL.md.
- **Persona lenses** — a well-written `domain-user-lens` instance for a common product shape (a SaaS admin, a shopper, an API consumer).
- **New patterns** — a bug pattern `/wizard` should catch? Add it to PATTERNS.md, with its incident.
- **Phase improvements** — battle-tested a refinement? Open a PR with a before/after example.
- **Bug reports** — if `/wizard` missed something it should have caught, that's a bug in the prompt. File an issue with the scenario.

**How to contribute:** fork → change → open a PR with *what changed* and *why*. Bonus points if you use `/wizard` to make the PR.

## Origin

This workflow was distilled from months of production use orchestrating Claude Code on a real codebase — hundreds of PRs, real race conditions caught by the adversarial-review phase, review-bot findings that would have reached production without the gate, and, for v3, a series of process failures that each earned a rule. The stack-specific machinery has been stripped out; the architecture, the rules, and the incidents behind them are what's captured here. It works with any language, framework, or stack.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI (the ensemble uses its subagent, task, wakeup, notification, and Artifact primitives).
- A git repository with a host CLI (`gh` on GitHub, or equivalent) for issue/PR integration.
- An automated code-review bot for the review gate ([CodeRabbit](https://coderabbit.ai/) or similar). The cycle works without one, but the gate is where `/wizard` really shines.

## License

MIT. Fork it, adapt it, make it yours.
