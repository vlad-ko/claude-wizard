# claude-wizard

**Turn Claude Code from a fast coder into a senior software architect.**

Claude Code is brilliant at writing code quickly. But speed without structure leads to bugs, race conditions, and regressions that eat the time you saved — and then some. `/wizard` changes the operating mode: Claude reads before writing, tests before implementing, and attacks its own code before committing.

## The ingredients

`/wizard` isn't just a prompt — it's a workflow built on specific ingredients that work together:

1. **`CLAUDE.md`** — Your project's rules file. This is where you define coding standards, naming conventions, architecture decisions, and anything Claude should always know. `/wizard` reads this first, every time.

2. **GitHub Issues** — Every feature or bug gets a GitHub issue (or epic) *before* coding starts. `/wizard` creates these for you with acceptance criteria, tracks progress by checking off boxes as it works, and references the issue in every commit. The issue is the source of truth.

3. **Codebase-first exploration** — Before writing a single line, `/wizard` reads the existing code, greps for methods and relationships, and verifies assumptions. No hallucinated function calls. No invented APIs.

4. **TDD, no exceptions** — Failing tests first, then minimal implementation, then verify. Every time. The tests use a mutation-testing mindset — they assert specific values that would break if the code changed, not just `assertTrue(worked)`.

5. **Feature branch to main** — Clean branch, focused PR, one concern at a time. No stacked branches, no tangled dependencies.

6. **Bug Bot cycle** — After opening the PR, `/wizard` monitors your automated code review bot (Bug Bot, CodeRabbit, etc.), reads every finding, fixes valid issues, replies to false positives, and repeats until the status is clean. No unresolved findings, ever.

7. **CI (your setup)** — Your test suite, your pipeline, your rules. `/wizard` runs affected tests locally before pushing, but the full CI suite depends on your project. I use GitHub Actions — GitHub for everything.

Each phase has a checkpoint. Claude won't rush ahead.

## The difference

**Without `/wizard`:**
> You: "Add a transfer status tracking feature"
>
> Claude: *immediately writes 400 lines of code, misses a race condition, hard-codes a string that should be a constant, skips tests*

**With `/wizard`:**
> You: *creates GitHub issue #164 with acceptance criteria*
>
> You: `/wizard implement #164 — transfer status tracking`
>
> Claude: *reads the codebase, writes failing tests, implements with locking to prevent concurrent conflicts, runs the test suite, self-reviews for edge cases, opens a PR, resolves all bot findings, checks off acceptance criteria*

The output is the same — working code. But the `/wizard` code ships without the 2am "why is this broken in production" follow-up.

## Contributing

This project is small, opinionated, and hungry for fresh ideas. PRs are welcome and encouraged :heart:

**Ways to contribute:**

- **Framework overlays** — Add a `frameworks/rails/`, `frameworks/nextjs/`, or `frameworks/rust/` directory with framework-specific Phase 2/4 additions that people can merge into their SKILL.md
- **New patterns** — Found a bug pattern that `/wizard` should catch? Add it to PATTERNS.md
- **Phase improvements** — Battle-tested a refinement to one of the 8 phases? Open a PR with a before/after example
- **Bug reports** — If `/wizard` missed something it should have caught, that's a bug in the prompt. File an issue with the scenario.
- **Translations** — Port the skill to other languages so non-English teams can use it

**How to contribute:**

1. Fork the repo
2. Make your changes
3. Open a PR with a clear description of *what changed* and *why*
4. Bonus points if you use `/wizard` to make the PR :wink:

No contribution is too small. A single-line fix to a checklist item that saved you from a bug is just as valuable as a new framework overlay.

## Install

**One command** from your project root:

```bash
curl -sL https://raw.githubusercontent.com/vlad-ko/claude-wizard/main/install.sh | bash
```

Or manually:

```bash
mkdir -p .claude/skills/wizard
curl -sL https://raw.githubusercontent.com/vlad-ko/claude-wizard/main/skill/SKILL.md -o .claude/skills/wizard/SKILL.md
curl -sL https://raw.githubusercontent.com/vlad-ko/claude-wizard/main/skill/CHECKLISTS.md -o .claude/skills/wizard/CHECKLISTS.md
curl -sL https://raw.githubusercontent.com/vlad-ko/claude-wizard/main/skill/PATTERNS.md -o .claude/skills/wizard/PATTERNS.md
```

## Usage

In Claude Code, type:

```
/wizard implement the user authentication flow as described in GH issue #164
```

Claude will respond with `## [WIZARD MODE]` and begin the phased approach. You'll see phase transitions as it works:

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

## What's included

| File | Purpose |
|------|---------|
| `SKILL.md` | The core skill — 8-phase development methodology |
| `CHECKLISTS.md` | Quick-reference checklists for each phase |
| `PATTERNS.md` | Common patterns and anti-patterns with examples |

## Customization

The skill is designed to be extended. Add your project-specific patterns:

**Framework conventions** — Add your framework's testing commands, directory structure, and coding standards to Phase 2 and Phase 4.

**Logging patterns** — Replace the generic logging guidance with your project's specific logging approach.

**CI/CD integration** — Customize Phase 8 with your specific CI bot names and quality gate requirements.

**Team conventions** — Add commit message formats, PR templates, and review processes.

Edit `.claude/skills/wizard/SKILL.md` directly — it's your copy.

## How it works

Claude Code [skills](https://docs.anthropic.com/en/docs/claude-code/skills) are markdown files that activate when invoked with `/skillname`. They inject additional context and instructions into Claude's prompt, changing its behavior for the duration of the task.

`/wizard` works by wiring the ingredients above into an enforced sequence:

1. **Read `CLAUDE.md`** and project docs — understand the rules before touching anything
2. **Find or create a GitHub issue** — define what "done" looks like with acceptance criteria
3. **Explore the codebase** — grep, search, verify. Never assume a method or relationship exists
4. **Write failing tests** — TDD with mutation-resistant assertions
5. **Implement the minimum** — make tests pass, follow existing patterns, no gold-plating
6. **Run the test suite** — fix regressions before moving on
7. **Adversarial self-review** — attack your own code for race conditions, null edges, security holes
8. **Open a PR, run the Bug Bot cycle** — monitor findings, fix or reply, repeat until clean

There's no magic. It's a well-structured prompt that encodes the habits of senior engineers into a repeatable process. The key insight is that Claude doesn't lack the *ability* to do these things — it lacks the *process* to do them consistently. `/wizard` is that process.

## Origin

This skill was developed over months of production use on a fintech platform ([wealthbot.io](https://wealthbot.io)) — a Laravel application managing investment portfolios, ACAT transfers, and regulatory compliance. The patterns were refined through hundreds of PRs, real race conditions caught by the adversarial review phase, and Bug Bot findings that would have reached production without the quality gate cycle.

The framework-specific details have been stripped to make it universal. The methodology works with any language, framework, or stack.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- A git repository (the skill uses `gh` CLI for GitHub integration)
- An automated code review bot for Phase 8 — [Bug Bot](https://docs.cursor.com/features/bug-bot) (Cursor), [CodeRabbit](https://coderabbit.ai/), or similar. Phase 8 works without one, but the quality gate cycle is where `/wizard` really shines.

## License

MIT
