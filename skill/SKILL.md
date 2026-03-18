---
name: wizard
description: Disciplined development guidance for complex features, bug fixes, and refactoring. Applies strict Red-Green-Refactor TDD, systematic planning, design heuristics, GitHub issue tracking, adversarial test coverage, and automated PR quality gates. Use when implementing features, fixing bugs, or making multi-file changes that require careful planning and quality assurance.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent, TodoWrite, WebFetch, AskUserQuestion
---

# Wizard Mode

## Visual Indicator

Prefix your first response with `## [WIZARD MODE]` to signal that architect-level standards are active. Use `## [WIZARD MODE] Phase N: Name` at each phase transition. Keep all checkpoint summaries to two or three sentences - state what was found and what happens next.

## Core Behaviours

**Think Systemically, Not Locally**
- Don't ask "How do I fix this bug?" Ask "Why does this bug exist? What systemic issue allowed it? Where else does this pattern appear?"
- When you see a bug, map the entire subsystem: What other methods touch this data? What are all the concurrent access paths? What invariants must hold across ALL of them?

**Understand Before You Act**
- Before writing any code, verify you can answer: what data does this touch, what else touches that data, what are the concurrent access paths, and what invariants must hold.
- If you cannot answer these from your exploration, explore more before proceeding.
- If you're coding immediately, you haven't explored enough.

**Turn Adversarial Questions Into Tests**
For every behaviour you implement, write test cases that answer:
- "What happens if this runs twice concurrently?"
- "What if this field is null? Zero? Negative?"
- "What assumptions am I making that could be wrong?"
- "If I were trying to break this, how would I do it?"
These are not questions to reflect on at commit time. They are test cases to write during the RED phase.

---

## Phase 1: Understanding & Planning

**Goal**: Deeply understand before acting

**Actions**:
1. Read `CLAUDE.md` thoroughly
2. Determine the project's documentation model:
   - **If CLAUDE.md references external docs** (e.g. a `docs/` directory, linked guides, or referenced markdown files): read every referenced document. Follow every pointer - do not skip any. These documents are the **source of truth** for architecture, data models, API contracts, coding standards, and testing conventions.
   - **If CLAUDE.md is self-contained** (all conventions and context live in the file itself): treat CLAUDE.md as the sole authority.
   - **If no CLAUDE.md exists**: scan the repo root and any `docs/` directory for README, CONTRIBUTING, architecture docs, and test guides. Use whatever exists as your baseline understanding.
3. Create a todo list with all phases using TodoWrite
4. Assess task complexity:
   - **Simple**: Single file, obvious fix, < 50 lines changed
   - **Medium**: 2-3 files, clear scope, defined boundaries
   - **Complex**: 4+ files, architectural impact, multiple concerns

**For Medium/Complex Tasks**:
- Check for existing GitHub issues: `gh issue list --search "keyword"`
- If no issue exists, create one with acceptance criteria
- If the project has external docs, reference the relevant doc sections in the issue
- The GitHub issue tracks workflow status. If the project has a docs directory, the docs remain the source of truth for how things work - the issue tracks what needs doing, not how the system behaves.

**Checkpoint**: Brief summary of understanding and plan.

---

## Phase 2: Codebase Exploration

**Goal**: Understand existing patterns before making changes

**Actions**:
1. Search for similar implementations in the codebase
2. Verify all method names, relationships, and structures exist (NEVER assume)
3. Use grep/search to confirm:
   - Functions and methods exist as named
   - API contracts match expectations
   - Database schemas or data structures exist as expected
4. Identify patterns that must be followed

**CRITICAL**: Never assume code exists. Always verify with search tools before referencing any function, method, class, or constant. Hallucinated references are a top source of bugs.

**Checkpoint**: Files to modify and patterns discovered.

---

## Phase 3: Implementation (Test-Driven)

**Goal**: Build the feature in tight Red-Green-Refactor cycles

The TDD loop IS the implementation. Each cycle targets a single behaviour. Do not write all tests first and then implement - alternate between them.

### New Feature Development

For each behaviour, repeat this cycle:

#### RED - Write a Failing Test
Write one test for the next behaviour. Run it - it MUST fail. A test that passes before you write the implementation is testing nothing.

Include adversarial cases as test cases, not afterthoughts:
- Null, zero, negative, empty, and boundary inputs
- Concurrent access scenarios
- Side effects across multiple fields

#### GREEN - Implement Minimal Code
Write the minimum code to make the test pass. No gold-plating. No "while I'm here" additions. Documentation updates are not gold-plating - see Phase 5.

#### REFACTOR - Clean Up Before Moving On
Before starting the next behaviour, clean up the code you just wrote:
- Extract methods if any function is growing beyond 5-8 lines
- Extract a new class if a class is accumulating unrelated responsibilities
- Simplify conditionals
- Improve naming so the code reads as prose
- Check that each function operates at one level of abstraction
- Ensure dependencies point inward toward business logic, not outward toward infrastructure
- Design interfaces from the caller's perspective - don't force callers to depend on methods they don't use

Do not move to the next RED until the current code is clean.

#### Mutation Testing Mindset
- Don't just assert success - assert specific values, counts, state changes
- Test boundary conditions: if code checks `> 0`, test with 0, 1, and -1
- Verify side effects: if a method updates multiple fields, assert ALL of them
- If someone changed `>` to `>=` in your code, would a test catch it? If not, add one.

### Bug Fixes

#### 3.1 Diagnose
Understand the bug and its systemic cause. Map all code paths that touch the affected data. Identify where the invariant breaks and whether the same pattern exists elsewhere. Ask: what was it about the object relationships, coupling, or responsibilities that made this bug easy to introduce?

#### 3.2 RED - Write a Test That Reproduces the Bug
Write a test that fails because of the bug. This proves you understand the defect and prevents regression. Run it - it MUST fail.

#### 3.3 GREEN - Fix the Bug
Apply the fix. The test from 3.2 must now pass.

#### 3.4 REFACTOR - Address the Design Pressure
If the bug was enabled by poor structure (tangled responsibilities, missing abstractions, implicit coupling), refactor to make this class of bug structurally unlikely. Apply the same design heuristics as in the new feature REFACTOR step.

#### 3.5 Widen the Net
If the diagnosis in 3.1 found the same pattern elsewhere, write tests for those cases too and fix them in the same change.

### Design Heuristics

Apply these as concrete constraints during every REFACTOR step:
- **Methods**: Keep under 5-8 lines where possible. One level of abstraction per function.
- **Classes**: Keep under 100 lines. Each class has one reason to change. If adding a method that doesn't relate to the class's existing responsibility, extract a new class.
- **Parameters**: No more than 4 parameters per method. If you need more, introduce a parameter object.
- **Dependencies**: Depend on abstractions at module boundaries, not concrete implementations. Dependencies point inward toward business logic.
- **Interfaces**: Design from the caller's perspective. Don't force callers to depend on methods they don't use.

### Implementation Rules

- Follow codebase conventions strictly
- Use existing constants, enums, and configuration - never hard-code values
- Use existing abstractions - don't reinvent what the codebase already provides
- Never skip input validation
- Use proper error handling with exceptions and logging
- Follow the project's established patterns for logging, error handling, and state management
- Update todo list as you progress

**For Shared State / Database Transactions**:
Document before implementing:
1. All actors/methods that can modify this data
2. All concurrent scenarios
3. Invariants that must ALWAYS hold
4. Locking/coordination strategy

**TOCTOU Prevention (Time-of-Check to Time-of-Use)**:
```
// WRONG: State can change between check and use
read state -> [gap where another process can modify] -> act on stale state

// CORRECT: Atomic check-and-act
lock -> read state -> act -> unlock
```

This applies to any shared mutable state: databases, files, caches, APIs.

**Transaction Side-Effect Awareness**:
When code throws inside a transaction, ALL changes in that transaction are rolled back. If error-handling state (marking something as failed, creating audit records) must persist despite the exception, it must happen outside the transaction.

**Checkpoint**: All behaviours implemented via Red-Green-Refactor. Tests passing. Code clean.

---

## Phase 4: Full Test Suite Verification

**Goal**: Ensure no regressions

Run the full test suite before committing. Every time. No exceptions.

If the full suite takes too long to run, flag it as a problem to address separately, but never scope down test runs to save time on a single commit.

**If tests fail**:
1. Analyse the failure - don't guess
2. Fix the root cause, not the symptom
3. Re-run affected tests
4. Repeat until 0 failures

**NEVER commit with failing tests.**

**Checkpoint**: Test results (pass count, any failures).

---

## Phase 5: Documentation & GitHub

**Goal**: Keep docs and issues in sync with code

### 5.1 Documentation Review
When a change affects documented behaviour (new endpoints, model changes, config changes, enum additions, migration additions), update the relevant documentation:
- **If the project has a docs directory or referenced doc files**: update the affected documents. Review existing documentation in its entirety rather than just appending a new section - other parts of the docs may reference the area you changed and need updating to stay accurate.
- **If CLAUDE.md is the sole documentation**: update the relevant sections in CLAUDE.md.
- **If no documentation exists**: consider whether the change warrants starting one.

This is not optional. Skipping documentation when behaviour changes creates drift that compounds.

### 5.2 GitHub Issue Updates
If working from a GitHub issue:
- Check off completed acceptance criteria
- Add progress comments at milestones
- Update labels to reflect current state

### 5.3 Clean Up
- Archive outdated documentation
- Remove dead code - don't comment it out

**Checkpoint**: Documentation current. GitHub issues reflect actual state.

---

## Phase 6: Pre-Commit Review

**Goal**: Final quality gate before commit

**Self-Review Checklist**:
- [ ] All acceptance criteria addressed
- [ ] No hard-coded values that should be constants
- [ ] No assumptions made without verification
- [ ] All edge cases handled
- [ ] Error handling is complete
- [ ] No security vulnerabilities (injection, XSS, etc.)
- [ ] Tests cover new functionality
- [ ] Full test suite passes
- [ ] Documentation updated where behaviour changed
- [ ] Code follows existing patterns
- [ ] Design heuristics applied (method length, class size, dependency direction)

**Verify Adversarial Test Coverage**:
Confirm that tests exist for each of these scenarios. If any are missing, go back and write them before committing.
- Concurrent execution of the same operation
- Null, empty, zero, negative, and boundary inputs
- Race conditions on shared state
- Failure partway through a multi-step operation

**Checkpoint**: Ready to commit. All checks pass.

---

## Phase 7: PR & Quality Gate Cycle

**Goal**: Open PR, resolve all automated findings, achieve clean status

This phase is **non-negotiable**. Every feature branch must go through the quality gate cycle before being considered ready for merge.

### For repos with CodeRabbit or other automated code review:

**Per-Commit Monitoring Loop:**
```
PUSH commit -> WAIT for review status -> READ findings -> FIX valid issues or REPLY to false positives -> PUSH fix -> REPEAT
```

**Rules**:
- After EVERY push, wait for the review status check to complete
- EVERY finding MUST have a response - fix commit or false-positive explanation
- NEVER skip findings, even low-severity ones
- NEVER declare PR ready while review status is pending
- If a fix commit introduces new findings, those ALSO require responses
- Continue until the reviewer returns a clean status

### For repos without automated review:

**Self-Review the Diff**:
```bash
git diff main...HEAD
```
- Review every changed line as if you were a critical reviewer
- Look for: missing error handling, race conditions, security issues, test gaps
- Fix anything you find before requesting review

**Checkpoint**: All automated findings resolved. PR ready for merge.

---

## Summary Output

After completing all phases, provide:

1. **What was built**: Brief description of changes
2. **Files modified**: List of changed files
3. **Tests added/modified**: Test coverage summary
4. **Documentation updated**: List of doc changes
5. **GitHub issue status**: Updated acceptance criteria
6. **PR status**: Quality checks resolved, ready for merge
7. **Next steps**: Any follow-up work identified

---

## Remember

- **Thoroughness saves time. Cutting corners breaks things.**
- **Every bug is a symptom. Find the disease - in the code and in the design.**
- **Never assume code exists. Verify with grep before referencing anything.**
- **When all acceptance criteria are met and all tests pass, stop.** Do not refactor code you were not asked to change. Do not add tests for pre-existing issues. Do not improve files outside the scope of the task. Note follow-up work in the summary and move on.