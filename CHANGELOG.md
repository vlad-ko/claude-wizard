# Changelog

All notable changes to claude-wizard are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions are git tags (`v1`, `v2`, `v3`).

## [v3] — 2026-09-11 — Discipline with teeth

v2 turned one disciplined developer into an orchestrated team. v3 is about what happened when that
team ran for three more months on a production codebase: rules that were *guidance* got violated
anyway, so they became **ordered steps that must produce an artifact**, and the orchestration loop
got **auditors of its own**. Every rule in this release carries the incident that earned it.

### Added

- **Phase 2.5 — Phased decomposition** (`skill/reference/phased-decomposition.md`): on any
  multi-concern finding, a phased plan is FILED on the issue before any builder is briefed. The phase
  ledger is the acceptance-criteria ledger; phase shapes (decision, additive, single-concern,
  integration, contract); the release-gate disposition (fix now / flag-gate / defer); the
  per-phase builder-brief contract.
- **Phase 2 design audits**: the Three-Outcome Audit (`pass` / `fail` / `inconclusive`), the
  New-Dimension Audit (propagate a new mode/flag/scope to every pre-existing enforcement point), and
  the Expression-Site Inventory (a derived fact expressed at N > 1 sites collapses to one).
- **Four portable principles**, each a reference doc plus a Phase-7 checklist line:
  - `absence-is-not-a-value.md` — a read that cannot produce a trustworthy answer refuses; the
    banned-shape catalog; a genuine `0` stays distinguishable from no-sample.
  - `remove-the-mechanism.md` — the operative test ("could a new caller next year still do it?")
    and the four-rung ladder; honest-rung reporting in the PR; feature flags as guards over an
    open obligation.
  - `tests-assert-behavior.md` — assert the state change; fixtures must not make the defect
    undetectable; verify teeth by a ONE-LINE mutation edited back; never delete a file to force
    RED; a blocking test that encodes the defect is rewritten and named in the PR.
  - `adjacency-check.md` — a fix is checked against the known-defect pattern inventory, outward
    and inward, with a required `### Adjacency check` block in the PR body.
- **Event-driven orchestration** (`parallel-pipeline.md` rewritten): wake on events — every push,
  subagent return, user turn, and before answering any question about PR state — never on a clock.
  The idle test is the ledger, not the event queue. Findings before builds. The open-PR cohort
  moves in unison; all-merge-ready is a step, not an exit.
- **Six new agents**: `pr-checkin` (cheap, event-triggered lane check; writes the durable per-PR
  ledger), `pr-manager` (judgment pass on escalation; routed briefs; STUCK detection),
  `resource-manager` (core-derived test-running budget, fail-closed; proposes, never performs),
  `accountability-lead` (a second lead that audits the first and reports to the user),
  `backlog-manager` (the backlog converges; blocker burn-down as the one metric), and
  `report-maker` (a living epic dashboard Artifact updated in place).
- **Capacity gate** (`capacity-and-worktrees.md`): two independent limits — the open-PR band gates
  new candidates only; the test-running budget gates every suite-running dispatch. Worktree
  gotchas (one git index per worktree, repo-global stash, dependency symlinks running main's code,
  stale-origin diffs). The clean-slate rule: every task ends on a clean primary checkout.
- **Context economics** (`context-economics.md`): the cost model, the summary + pointer budget for
  always-resident files, the one-question test, orchestrator context hygiene, cheaper model tiers
  for mechanical agents, succinct communication on every channel.
- **Hybrid routing** (`complexity-gate.md`): a triage manifest; builders route deterministically
  off it; read-only lenses self-select; documentation touches always engage the librarian.
- **Accountability and a second review channel** (`accountability-and-review-channels.md`).
- **Codify the lesson while it is hot** (`codify-the-lesson.md`): five triggers, a routing table,
  no new rule without its incident.
- **Claim discipline** in `issue-maintainer`: a severity cites both the constructing entry point
  and the consuming reader; an acceptance criterion names the existing seam it modifies, never a
  new guard it adds.
- `CHANGELOG.md` (this file).

### Changed

- `skill/SKILL.md` rewritten to the summary + pointer budget: every rule states what, why, and
  where the method lives; method text moved to `skill/reference/`.
- `threading-model.md`: per-PR task metadata, the liveness probe (`SendMessage` to a warm worker
  vs spawn-fresh into the existing worktree), the retired "provably trivial" carve-out (the
  orchestrator authors no repo code in delegated mode), the five failure recipes with brief lines.
- `pr-review-cycle.md`: four finding surfaces (a check-run based reviewer added); one canonical
  finding detector shared by the pre-merge audit and the CI gate; reply-and-resolve as one step;
  the clearing mechanism per surface; merge-ready declared once at a named SHA.
- `ensemble-dispatch.md` (was inline in SKILL.md): the ordered sequence, the initial-build fan-out
  as the default, non-overlapping file ownership, the verification loop, cost guardrails.
- Existing agents refreshed: `architect` (owns the phased plan on a design fork),
  `backend-expert`, `doc-librarian` (curation charter, budget enforcement for always-resident
  files), `issue-maintainer` (claim discipline, ledger forms), `qa-engineer` (the test sub-rules
  and the mutation procedure).
- `CHECKLISTS.md`: design-audit, decomposition, wake, and clean-slate checklists; the four
  principle lines in pre-commit.
- `PATTERNS.md`: refusal instead of default, mechanism removal, the one-line mutation, and the
  adjacency block as patterns.
- `install.sh`: installs the fifteen reference docs and twelve agents; file lists are variables.
- `README.md` and `ARCHITECTURE.md` updated for v3; the repo description now reflects the
  orchestration layer.

### Removed

- The recurring wakeup tick and the "cadence ceiling" from the parallel pipeline — a tick fired
  past the cache TTL pays a full cache write on the whole resident context, and a "cheap"
  replacement tick is not cheap. Replaced by event-driven wakes.
- The patch-coverage gate line from the merge-ready criteria — replaced by "walk your own diff"
  when the PR path has no coverage tooling.

### Upgrading

v3 is a superset of v2. Re-run the installer; it overwrites the skill and reference directories and
adds the six new agents. Your persona-lens instances in `.claude/agents/` are untouched. v2 is
preserved at the `v2` tag.

## [v2] — 2026-06-19 — The multi-agent workflow

### Added

- **Delegated mode**: the orchestrator/worker split with the boundary at `git commit` — workers
  commit locally and return; the orchestrator pushes, opens the PR, and owns the review cycle.
- **The agent ensemble**: `architect`, `backend-expert`, `frontend-expert`, `qa-engineer`,
  `doc-librarian`, `issue-maintainer`, and the `domain-user-lens` persona template. Gate-routed
  (three bands on structural signals), orchestrator-mediated, generator ≠ evaluator.
- **The parallel pipeline**: a cohort of up to ten PRs driven to merge-ready concurrently, each in
  its own worktree; the wakeup-handler algorithm; the per-author depth band; idle is forbidden.
- **The AI-review gate**: three finding surfaces, premise vs remedy, the merge-ready gate, the
  reviewer-quiescence window.
- Phase 1.5 — reproduce-first for runtime errors.
- `ARCHITECTURE.md` with the full-cycle narrative and three Mermaid diagrams.
- `install.sh` fails on HTTP errors instead of writing error bodies.

### Changed

- The human's role: conductor, not task-giver.
- Installed layout aligned with the docs; the persona template moved outside `.claude/agents/`
  so placeholder content can never be dispatched.

## [v1] — 2026-03-10 — Initial release

- The 8-phase skill: understand, explore, TDD (RED → GREEN with a mutation-testing mindset),
  implement, verify, document, adversarial self-review, PR and review cycle.
- `CHECKLISTS.md` and `PATTERNS.md`.
- One-command installer.

[v3]: https://github.com/vlad-ko/claude-wizard/compare/v2...v3
[v2]: https://github.com/vlad-ko/claude-wizard/compare/v1...v2
[v1]: https://github.com/vlad-ko/claude-wizard/releases/tag/v1
