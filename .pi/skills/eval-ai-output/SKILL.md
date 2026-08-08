---
name: eval-ai-output
description: >-
  Evaluate AI-generated code through four structured gates (Functional, Logical, Quality, Hallucination).
  Produces a verdict and surgical feedback for the agent. Use when reviewing AI-generated code output,
  when the agent produces code that needs validation before acceptance, or when user wants to formalize
  their code review of AI output. Works inside the /implement → /tdd inner loop — apply after agent
  produces code and before tests run. Catches what /tdd (specification) and /code-review (end-of-cycle)
  miss: logical edge cases not yet tested, quality issues early, and hallucinated APIs/functions/imports.
---

# Eval AI Output

Four gated checks applied to AI-generated code. Each gate returns a `pass` or `fail` with specific detail — never "looks wrong." Feed the verdict back to the agent as surgical feedback.

## Quick start

After the agent produces code, before running tests:

```
1. Apply Gate 1 (Functional)
2. Apply Gate 2 (Logical)
3. Apply Gate 3 (Quality)
4. Apply Gate 4 (Hallucination)
5. Produce verdict + feedback
```

Any gate that fails → reject with specific feedback → re-delegate to agent. All four pass → accept and proceed to tests.

See [GATES.md](GATES.md) for the full gate definitions, failure modes, and examples.

## The four gates

### Gate 1: Functional
**Does it run?** Compile/parse errors, missing imports, syntax issues. Check before anything else — if this fails, nothing else matters.

### Gate 2: Logical
**Does it solve the right problem?** Edge cases, boundary conditions, null/empty handling, off-by-one errors, duplicate handling. The gap between "passes the tests you wrote" and "actually correct."

### Gate 3: Quality
**Is it well-built?** Naming, coupling, magic values, error handling patterns, type usage. Catch quality decay early before it spreads across files.

### Gate 4: Hallucination
**Is every reference real?** Fabricated APIs, non-existent imports, version drift, wrong parameter signatures. Verify against source using `opensrc` — grep the actual exports, read parameter signatures, confirm the method exists. This gate has no owner in the existing flow — `/tdd` won't catch a function that doesn't exist, `/code-review` might miss it because it looks plausible. `opensrc` turns this gate from a judgment call into a verifiable fact.

## Verdict output format

Produce structured feedback the agent can act on:

```yaml
gate_1_functional: pass | fail
  detail: "specific observation"
  failing_line: "line N or location" (if fail)

gate_2_logical: pass | fail
  detail: "specific observation"
  failing_case: "the exact edge case that breaks" (if fail)

gate_3_quality: pass | fail | pass_with_notes
  detail: "specific observation"
  suggestion: "concrete refactor" (if fail or notes)

gate_4_hallucination: pass | fail
  detail: "specific observation"
  fabricated_reference: "the exact API/import that doesn't exist" (if fail)

verdict: ACCEPT | REJECT
reason: "one-line summary of why" (if REJECT)
feedback_to_agent: >
  Precise, actionable instruction.
  Include what to fix, where, and the expected behaviour.
  No vague language — the agent needs coordinates, not feelings.
```

## When in the flow

```
/implement (kicks off /tdd internally)
      ↓
  Agent plans → writes code
      ↓
  ┌──────────────────┐
  │ THIS SKILL       │  ← Apply the 4 gates here
  │ eval-ai-output   │
  └──────────────────┘
      ↓
  Gate fails? → surgical feedback → re-delegate → agent rewrites
      ↓
  All pass? → proceed to tests (/tdd green phase)
      ↓
  Tests pass? → /code-review (Standards + Spec) → commit
```

**This skill replaces the implicit "scan and feel" review with an explicit, repeatable pipeline.** It narrows the agent loop: instead of "fix it" → 4 iterations, you get "Gate 2 fail: no dedup on line 47, add a Set check" → 1 iteration.

## Relationship to existing skills

| Skill | What it covers | What it misses |
|-------|---------------|----------------|
| `/tdd` | Does code pass tests? (Gate 1 + partial Gate 2) | Edge cases not yet tested, quality, hallucinations |
| This skill | All 4 gates | Does not run tests — that's `/tdd` |
| `/code-review` | Standards + Spec review at cycle end | Runs too late — hallucinated APIs have cascaded |

They compose: **this skill** (inner loop) → **`/tdd`** (validation) → **`/code-review`** (cycle close).
