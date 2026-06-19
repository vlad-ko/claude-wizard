# Wizard v2: the multi-agent workflow

**From one disciplined developer to an orchestrated team — without giving up the discipline.**

Wizard v1 turned Claude Code from a fast coder into a careful one: it read before writing, tested before implementing, and attacked its own code before committing. That's still the foundation. **v2 adds a second gear.** When the work is big enough, the careful thread stops being the *builder* and becomes the **orchestrator** of a team of specialist agents — an architect who designs, builders who implement in parallel, adversarial critics who try to break it, and a review gate that won't let anything merge with an unanswered finding. One thread becomes a pipeline.

If v1 was "think before you code," v2 is "**design, then delegate, then verify — in parallel, without idling.**"

## What it is

`/wizard` is a Claude Code [skill](https://docs.anthropic.com/en/docs/claude-code/skills) — a markdown playbook that changes how Claude operates for the duration of a task. v2 runs in two modes:

- **Direct mode** — a single thread runs the whole 8-phase lifecycle itself (this is v1's behavior, kept intact).
- **Delegated mode** — the thread you're talking to becomes an **orchestrator**: it designs the change, dispatches specialist subagents to build and verify it, and owns the pull-request review cycle. The boundary between worker and orchestrator is the `git commit` — workers commit locally and hand back; the orchestrator pushes, opens the PR, and drives every reviewer finding to resolution.

The complexity of the work decides which mode you get. A one-line fix never pays the multi-agent tax; a multi-domain feature with shared state and lifecycle transitions gets the full ensemble.

## The ingredients

`/wizard` isn't just a prompt — it's a workflow built on specific ingredients that work together.

**Carried over from v1 (still the foundation):**

1. **`CLAUDE.md`** — your project's rules file. Coding standards, naming conventions, architecture decisions, anything Claude should always know. `/wizard` reads this first, every time. It's also the *only* thing a dispatched subagent inherits besides its brief — so it's load-bearing.

2. **Issues as the source of truth** — every feature or bug gets an issue (or epic) *before* coding starts, with acceptance criteria. `/wizard` tracks progress by checking off boxes *at merge-time*, and references the issue in every commit.

3. **Codebase-first exploration** — before writing a line, `/wizard` reads the existing code, greps for methods and relationships, and verifies assumptions. No hallucinated APIs.

4. **TDD, no exceptions** — failing tests first, then minimal implementation, then verify. With a mutation-testing mindset: assertions that break if the code changes, not just `assert(worked)`.

5. **Branch-per-concern** — clean branch, focused PR, one concern at a time. No stacked branches, no tangled dependencies.

**New in v2 (the orchestration layer):**

6. **The orchestrator/worker split** — for delegated work, responsibility splits at the `git commit`. The worker builds and commits locally; the orchestrator verifies the diff, pushes, opens the PR, and monitors. This two-phase boundary is what lets the orchestrator catch a bad diff *before* it's exposed, compose the PR with cross-cut context, recover cleanly from a crashed worker, and be the single owner that declares merge-ready exactly once.

7. **The agent ensemble** — gate-routed and mediated. A complexity gate fires *first* and classifies the work; trivial work takes a single subagent, complex work gets the full chain: persona **critic lenses** + a **doc librarian** harden the requirements, an **architect** designs the change and writes the failing-test spec (but no production code), **backend** and **frontend** specialists turn the spec green in parallel, and a **QA engineer** plus the lenses verify the result. The agents that *build* are never the ones that *sign off* — generator ≠ evaluator.

8. **The parallel pipeline** — wait windows (a reviewer pass, the CI suite, a quiescence window) are *work-time*. While one PR waits, the orchestrator advances others: sweeping worktrees, auditing findings, and spawning the next candidate up to a per-author depth band. Idle is forbidden while independent work exists.

9. **The AI-review gate** — after opening the PR, `/wizard` monitors your automated review bot (CodeRabbit or similar), reads every finding across all three surfaces (inline, review body, issue-level summary), fixes valid ones, replies to false positives, and resolves threads — until the status is clean and a quiescence window has elapsed. No unresolved findings, ever. Then it declares merge-ready and hands the merge to you.

Each phase has a checkpoint. Claude won't rush ahead.

## The difference

**Without `/wizard`:**
> You: "Add a transfer-status tracking feature"
>
> Claude: *writes 400 lines, misses a race condition, hard-codes a string that should be a constant, skips tests*

**With `/wizard` (delegated mode, a complex feature):**
> You: *file an issue with acceptance criteria*
>
> You: `/wizard implement the transfer-status feature in the issue`
>
> Claude (orchestrator): *runs the complexity gate → dispatches persona lenses + a doc librarian to harden the ACs → dispatches the architect to design it and write the failing-test spec → fans the build out to backend ∥ frontend ∥ QA in parallel → re-runs the lenses adversarially against the built diff → pushes, opens the PR, drives every review-bot finding to resolution, waits out quiescence → declares merge-ready and pings you to merge*

The output is the same — working code. But it ships without the 2am "why is this broken in production" follow-up, and several PRs ship at once instead of one at a time.

## Upgrading from v1

v2 is a superset. If you used v1, the 8-phase methodology and its TDD/adversarial-review core are all still here — that's "direct mode." v2 adds the orchestration layer on top, and it only engages when the work is complex enough to warrant it. You don't have to change how you invoke `/wizard`.

**What's new in your install:** an `agents/` directory of specialist role definitions, a `reference/` directory of deep-dive docs (the threading model, the parallel pipeline, the PR review cycle), and an `ARCHITECTURE.md` with the system diagrams. The installer drops the agents into your `.claude/agents/` so the orchestrator can dispatch them.

**Still want v1?** It's preserved at the **`v1` git tag**:

```bash
git clone https://github.com/vlad-ko/claude-wizard
cd claude-wizard && git checkout v1
```

Or install the v1 skill files directly from that tag's raw URLs.

## Install

**One command** from your project root:

```bash
curl -sL https://raw.githubusercontent.com/vlad-ko/claude-wizard/main/install.sh | bash
```

This installs the `/wizard` skill into `.claude/skills/wizard/` and the agent roster into `.claude/agents/`.

Or manually:

```bash
# Skill
mkdir -p .claude/skills/wizard
for f in SKILL.md CHECKLISTS.md PATTERNS.md; do
  curl -sL "https://raw.githubusercontent.com/vlad-ko/claude-wizard/main/skill/$f" -o ".claude/skills/wizard/$f"
done

# Reference docs (loaded on demand by the skill)
mkdir -p .claude/skills/wizard/reference
for f in threading-model.md parallel-pipeline.md pr-review-cycle.md; do
  curl -sL "https://raw.githubusercontent.com/vlad-ko/claude-wizard/main/reference/$f" -o ".claude/skills/wizard/reference/$f"
done

# Agent roster
mkdir -p .claude/agents
for f in architect backend-expert frontend-expert qa-engineer doc-librarian issue-maintainer domain-user-lens; do
  curl -sL "https://raw.githubusercontent.com/vlad-ko/claude-wizard/main/agents/$f.md" -o ".claude/agents/$f.md"
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
## [WIZARD MODE] Phase 3: Test-Driven Development
...
```

You can also invoke it mid-conversation:

```
/wizard this is getting complex — let's be more systematic about this
```

## Customizing the agents

The agent roster is generic by design. Two files need *your* attention before the ensemble fits your product:

- **`agents/domain-user-lens.md` is a TEMPLATE, not a ready agent.** It embodies one *user persona's* adversarial point of view — and your product's personas aren't anyone else's. Copy it once per distinct persona in your product (e.g. `admin-lens.md`, `end-user-lens.md`, `power-user-lens.md`), and fill in each persona's real surfaces, domain rules, and failure modes. The template ships with three neutral example personas to show the shape.

- **`agents/backend-expert.md` and `agents/frontend-expert.md`** point at "your project's `CLAUDE.md`" for the framework-specific rules. They're written to *reference* your standards rather than embed a particular stack — so the more complete your `CLAUDE.md`, the sharper they get.

Everything references "your test runner / your CI / your review bot" rather than a specific stack. The methodology is the product; the stack is yours.

## What's included

| Path | Purpose |
|------|---------|
| `skill/SKILL.md` | The orchestrator skill — the 8-phase lifecycle + ensemble dispatch |
| `skill/CHECKLISTS.md` | Quick-reference checklists per phase |
| `skill/PATTERNS.md` | Portable patterns and anti-patterns with examples |
| `reference/threading-model.md` | The orchestrator/worker split + failure recipes |
| `reference/parallel-pipeline.md` | The don't-idle wakeup algorithm + depth band |
| `reference/pr-review-cycle.md` | The per-commit review loop + merge-ready gate |
| `agents/*.md` | The specialist roster (architect, builders, QA, librarian, issue-maintainer, lens template) |
| `ARCHITECTURE.md` | The system narrative + three Mermaid diagrams |

## How it works

`/wizard` wires the ingredients above into an enforced sequence — read the rules, define "done," explore the code, write failing tests, implement minimally, verify, self-review adversarially, then open a PR and drive every finding to resolution. In delegated mode it adds a gate-routed, orchestrator-mediated agent ensemble on top, with a parallel pipeline that keeps wait windows productive.

There's no magic. It encodes the habits of senior engineers into a repeatable process. Claude doesn't lack the *ability* to do these things — it lacks the *process* to do them consistently. `/wizard` is that process.

## Contributing

This project is small, opinionated, and hungry for fresh ideas. PRs welcome and encouraged.

**Ways to contribute:**

- **Framework overlays** — add a `frameworks/<stack>/` directory with stack-specific phase additions people can merge into their SKILL.md.
- **Persona lenses** — contribute a well-written `domain-user-lens` instance for a common product shape (a SaaS admin, an e-commerce shopper, an API consumer).
- **New patterns** — found a bug pattern `/wizard` should catch? Add it to PATTERNS.md.
- **Phase improvements** — battle-tested a refinement? Open a PR with a before/after example.
- **Bug reports** — if `/wizard` missed something it should have caught, that's a bug in the prompt. File an issue with the scenario.

**How to contribute:** fork → change → open a PR with *what changed* and *why*. Bonus points if you use `/wizard` to make the PR.

## Origin

This workflow was distilled from months of production use orchestrating Claude Code on a real codebase — hundreds of PRs, real race conditions caught by the adversarial-review phase, and review-bot findings that would have reached production without the quality gate. The stack-specific machinery has been stripped out; the architecture and the *why* are what's captured here. The methodology works with any language, framework, or stack.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI (the ensemble uses its subagent dispatch primitives).
- A git repository (the skill uses your host's CLI for issue/PR integration).
- An automated code-review bot for the review gate ([CodeRabbit](https://coderabbit.ai/) or similar). The cycle works without one, but the gate is where `/wizard` really shines.

## License

MIT. Fork it, adapt it, make it yours.
