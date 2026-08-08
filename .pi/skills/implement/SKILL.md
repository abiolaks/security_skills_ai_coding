---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
---

Implement the work described by the user in the spec or tickets.

**Before writing code:** Read and apply the security rules in `/codeguard`. The project AGENTS.md also has critical always-on rules — follow both. If the feature touches auth, APIs, payments, user data, or file handling, invoke `/codeguard` explicitly first.

Use /tdd where possible, at pre-agreed seams.

After the agent writes code and before tests run, apply `/eval-ai-output` — four gated checks (Functional, Logical, Quality, Hallucination). Any gate that fails → surgical feedback → re-delegate to agent. All pass → proceed to tests. This catches hallucinated APIs, missing edge cases, and quality decay before they hit the test suite. See `eval-ai-output` skill for full gate definitions.

Run typechecking regularly, single test files regularly, and the full test suite once at the end.

Once done, use /codeguard-review to audit for security vulnerabilities, then /code-review to review standards and spec adherence.

Commit your work to the current branch.
