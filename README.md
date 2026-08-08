# Security Skills for AI Agentic Workflows

> **Secure by default. Not "secure if we remember."**

A collection of skills that embed security into every phase of AI-assisted coding — before, during, and after code generation. Based on [Project CodeGuard](https://project-codeguard.org/) (CoSAI / OASIS Open Project) and the [Matt Pocock agentic workflow](https://github.com/abiolaks/security_skills_ai_coding).

---

## The Problem

AI coding agents write code 2–5× faster. But that speed amplifies every bad habit:

```python
# What AI agents generate by default:
query = f"SELECT * FROM users WHERE id = {user_id}"   # SQL injection
API_KEY = "sk-live-abc123def456"                        # Hardcoded secret
password_hash = md5(password)                           # Broken since 2004
```

The AI isn't malicious — it optimizes for completion, not correctness. Without guardrails, you're shipping vulnerabilities at AI speed.

### The Evidence

Cisco's controlled study (2,717 prompts, GPT-5, 9 languages):

| Metric | Without CodeGuard | With CodeGuard | Improvement |
|--------|------------------|----------------|-------------|
| Total security findings | 415 | 264 | **36.4% ↓** |
| SecurityEval (hardest benchmark) | 66 | 27 | **59.1% ↓** |
| CyberSecEval (1,916 prompts) | 242 | 172 | **28.9% ↓** |
| Clean snippets | 68.6% | 85.1% | **+16.5%** |

All results statistically significant at `p < 0.05`.

---

## The Complete Agentic Workflow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         BEFORE CODE                                      │
│  grill ──► to-spec ──► to-tickets                                       │
│  Stress-test     Define what       Break into small,                    │
│  the idea        "done" means      testable work items                  │
├─────────────────────────────────────────────────────────────────────────┤
│                         DURING CODE                                      │
│  ┌──────────┐    ┌──────────┐    ┌────────────────┐                     │
│  │ codeguard│───►│   tdd    │───►│ eval-ai-output  │                     │
│  │ security │    │ red-green│    │ 4-gate check    │                     │
│  │ context  │    │ refactor │    │ before tests    │                     │
│  └──────────┘    └──────────┘    └────────────────┘                     │
├─────────────────────────────────────────────────────────────────────────┤
│                         AFTER CODE                                       │
│  ┌──────────────────┐    ┌─────────────┐                                │
│  │ codeguard-review │ +  │ code-review │                                │
│  │ 23-rule security │    │ standards + │                                │
│  │ audit            │    │ spec        │                                │
│  └──────────────────┘    └─────────────┘                                │
└─────────────────────────────────────────────────────────────────────────┘
```

Five skills compose the implementation phase. Each has a distinct purpose — no overlap, no gaps.

---

## The Five Skills

### 1. `codeguard` — Security Guardrails During Generation

**When it runs:** Before the agent writes code (loaded by `/implement`)

**What it does:** Loads security rules into the agent's context so vulnerabilities are prevented, not caught later. Works in two layers:

**Always-on rules (every session, every language):**

| Rule | What it prevents |
|------|-----------------|
| 🔴 Never hardcode credentials | API keys, passwords, tokens in source. Recognizes AWS (`AKIA*`), Stripe (`sk_live_*`), GitHub (`ghp_*`), JWT patterns |
| 🔴 Never use weak cryptography | MD5, SHA-1, DES, 3DES, AES-ECB, AES-CBC → banned. Requires Argon2id, AES-256-GCM, TLS 1.3 |
| 🔴 Never concatenate into queries | SQL injection via parameterized queries. No `shell=True`. Allow-lists for dynamic identifiers |
| 🟡 Validate all untrusted input | Positive allow-list validation. Type, format, range, length checks. Canonicalize encodings |

**Context-scoped rules (activate based on what you're building):**

- **Auth code** → MFA, OAuth PKCE, Argon2id, rate limiting, account enumeration prevention
- **API code** → SSRF prevention, HTTPS enforcement, schema validation, GraphQL hardening
- **Frontend code** → XSS sinks, CSP headers, CSRF tokens, postMessage origin checks
- **Docker/K8s** → Non-root users, pinned digests, securityContext, no hostNetwork
- **IaC** → Encrypted resources, least-privilege IAM, no `0.0.0.0/0`
- **File handling** → Path traversal prevention, magic byte validation, server-generated filenames

**How it's invoked:**
- Automatically by `/implement` — no extra step required
- Manually: `/codeguard` before writing security-sensitive code

---

### 2. `tdd` — Test-Driven Development (Red-Green-Refactor)

**When it runs:** During implementation, after security context is loaded

**What it does:** The core loop that turns specifications into verified, working code — one tiny slice at a time.

#### The Loop

```
┌──────────────────────────────────────────────────────────┐
│                    THE TDD CYCLE                          │
│                                                          │
│   ┌────────┐      ┌────────┐      ┌──────────┐          │
│   │  RED   │ ───► │ GREEN  │ ───► │ REFACTOR │ ───┐     │
│   │ Write  │      │ Write  │      │  Clean   │    │     │
│   │ failing│      │ minimal│      │   up     │    │     │
│   │ test   │      │ code   │      │          │    │     │
│   └────────┘      └────────┘      └──────────┘    │     │
│        ↑                                           │     │
│        └───────────────────────────────────────────┘     │
│                   Next slice                              │
└──────────────────────────────────────────────────────────┘
```

**The three phases in detail:**

#### 🔴 RED — Write a failing test first

Before writing any implementation code, write a test that **fails**. This proves the test actually catches the behavior you're building.

```typescript
// RED: The test fails because createUser doesn't exist yet
test("createUser returns a user with an id and name", async () => {
  const user = await createUser({ name: "Alice", email: "alice@example.com" });
  expect(user.id).toBeDefined();
  expect(user.name).toBe("Alice");
});
```

**Rules of RED:**
- One test at a time — the smallest meaningful slice of behavior
- The test name describes **what** the user/caller cares about, not **how** it's implemented
- Expected values come from **independent sources** — known literals, worked examples, the spec — never recomputed the way the code computes them
- Write the test at a **pre-agreed seam** (public interface boundary) — confirm the seam with the user before writing
- Run the test → confirm it fails → proceed to GREEN

#### 🟢 GREEN — Write the minimum code to pass

Write **only enough code** to make the test pass. No more. Don't anticipate future tests. Don't add features the test doesn't demand. Don't optimize. Don't generalize.

```typescript
// GREEN: Simplest implementation that passes the test
async function createUser(data: { name: string; email: string }) {
  const id = crypto.randomUUID();
  return { id, name: data.name, email: data.email };
}
```

**Rules of GREEN:**
- Minimum viable implementation — resist the urge to "design ahead"
- If the test passes, stop writing code
- You can always refactor later — that's the next phase

#### 🔵 REFACTOR — Clean up without changing behavior

Now that the test passes, improve the code's structure. Extract duplication. Improve names. But **never change behavior** — the test must stay green.

```typescript
// REFACTOR: Extract ID generation, add validation, keep test green
const generateId = () => crypto.randomUUID();

async function createUser(data: { name: string; email: string }) {
  if (!data.email.includes("@")) throw new ValidationError("Invalid email");
  return { id: generateId(), name: data.name, email: data.email };
}
```

**Note:** In this workflow, full refactoring happens during `code-review`. The TDD refactor step is lightweight — just enough to keep the code clean between slices.

#### How Test Cases and Edge Cases Are Created

Tests come from **two directions**:

**1. Happy-path tests (from the spec/ticket)**

The ticket describes what the feature should do. Convert each requirement into a test:

```
Ticket: "User can enroll in a course by providing student_id and course_id"

→ test("enroll creates an enrollment for a student and course")
→ test("enroll returns the enrollment with id and timestamp")
→ test("enroll rejects if student_id is missing")
→ test("enroll rejects if course_id is missing")
```

**2. Edge-case tests (from logical reasoning)**

After the happy path works, think: "What could go wrong?" This is the gap `/tdd` intentionally leaves for `eval-ai-output` to catch. But the agent should anticipate common edges:

```
What could go wrong with enrollment?
→ Duplicate enrollment (same student + same course)
→ Student doesn't exist
→ Course doesn't exist
→ Course is full
→ Enrollment period has ended
→ Concurrent enrollment requests (race condition)
```

These become additional tests:

```typescript
test("enroll rejects duplicate enrollment", async () => {
  await enroll(student, course);
  await expect(enroll(student, course)).rejects.toThrow("Already enrolled");
});

test("enroll rejects if course is full", async () => {
  // Fill the course to capacity...
  await expect(enroll(student, course)).rejects.toThrow("Course is full");
});
```

**The agent writes edge-case tests during RED, not after.** Each edge case gets its own RED→GREEN cycle. This means edge cases are **baked into the implementation**, not retrofitted.

#### What Makes a Good Test

**✅ GOOD tests:**
- Test **observable behavior** through public interfaces
- Read like a specification: "user can checkout with valid cart"
- Survive internal refactors (implementation changes, test stays green)
- Use one logical assertion per test
- Expected values are independent, known literals

```typescript
// ✅ GOOD: Tests behavior through the public API
test("checkout with valid cart returns confirmed order", async () => {
  const cart = createCart();
  cart.add(product, { quantity: 2 });
  const result = await checkout(cart, paymentMethod);
  expect(result.status).toBe("confirmed");
  expect(result.total).toBe(19.98);  // independent literal, not recomputed
});
```

**❌ BAD tests (anti-patterns):**
- Mocking internal collaborators (test breaks on refactor)
- Testing private methods (coupled to implementation)
- Tautological assertions (expected = computed same way as code)
- Testing HOW instead of WHAT
- Bypassing the interface to verify (querying DB directly)

```typescript
// ❌ BAD: Coupled to implementation details
test("checkout calls paymentService.process", async () => {
  const mockPayment = jest.mock(paymentService);
  await checkout(cart, payment);
  expect(mockPayment.process).toHaveBeenCalledWith(cart.total);
  // Breaks if you switch to Stripe, PayPal, or change internal flow
});

// ❌ BAD: Tautological — expected = computed same way as code
test("calculateTotal sums items", () => {
  const items = [{ price: 10 }, { price: 5 }];
  const expected = items.reduce((sum, i) => sum + i.price, 0); // ← SAME LOGIC
  expect(calculateTotal(items)).toBe(expected);  // Can never fail
});
```

#### Mocking: When and How

**Mock only at system boundaries:**

| Mock these | Don't mock these |
|-----------|-----------------|
| External APIs (payment, email, SMS) | Your own classes/modules |
| Databases (sometimes — prefer test DB) | Internal collaborators |
| Time/randomness | Anything you control |
| File system (sometimes) | |

**Design interfaces for testability — use dependency injection:**

```typescript
// ✅ GOOD: Dependencies passed in — easy to mock
function processPayment(order: Order, paymentClient: PaymentClient) {
  return paymentClient.charge(order.total);
}

// ❌ BAD: Creates dependency internally — hard to mock
function processPayment(order: Order) {
  const client = new StripeClient(process.env.STRIPE_KEY);
  return client.charge(order.total);
}
```

---

### 3. `eval-ai-output` — Four-Gate Validation & Evaluation

**When it runs:** After the agent writes code, **before** tests execute (inside the `/implement` inner loop)

**What it does:** Applies four structured gates to AI-generated code. This is the **evaluation step** — before you even run the tests, you validate that the code is worth testing. Any gate that fails returns surgical feedback to the agent — it rewrites, and you re-evaluate. Only code that passes all four gates proceeds.

**Why evaluate before testing?** Running tests on broken, hallucinated, or low-quality code wastes time. Tests lock in whatever the agent produced — including bad patterns. Gates catch issues when they're cheapest to fix: before they become "tested and accepted."

#### The Four Gates

```
┌─────────────────────────────────────────────────────────────────┐
│  GATE 1: FUNCTIONAL           "Does it even run?"               │
│  ─────────────────────────────────────────────────────────────  │
│  Compile/parse errors, missing imports, syntax issues,          │
│  type mismatches. Checked first — if this fails, stop.          │
│                                                                 │
│  ❌ import { useDebouncedQuery } from '@tanstack/react-query'   │
│     → Missing import: add to line 3                             │
│  ❌ Type 'string' is not assignable to type 'number'            │
│     → Parameter expects number on line 8                        │
├─────────────────────────────────────────────────────────────────┤
│  GATE 2: LOGICAL              "Does it solve the right problem?"│
│  ─────────────────────────────────────────────────────────────  │
│  Edge cases, boundary conditions, null/empty handling,          │
│  off-by-one errors, duplicate handling, race conditions.        │
│  Catches what you didn't think to test — the gap TDD misses.    │
│                                                                 │
│  ❌ POST /enroll accepts duplicate student+course pairs         │
│     → Add uniqueness check before insert on line 47             │
│  ❌ validateEmail('') returns true                              │
│     → Add empty string guard on line 42                         │
│  ❌ Loop runs i <= arr.length — off-by-one                      │
│     → Change to i < arr.length on line 15                       │
├─────────────────────────────────────────────────────────────────┤
│  GATE 3: QUALITY              "Is it well-built?"               │
│  ─────────────────────────────────────────────────────────────  │
│  Naming, coupling, magic values, error handling, type usage,    │
│  function length. Catch quality decay before it spreads.        │
│                                                                 │
│  ❌ const d = calculate(x, y)  →  Rename to discountAmount      │
│  ❌ if (status === 3)  →  Extract STATUS_EXPIRED constant       │
│  ❌ try { await save() } catch (e) {}  →  Swallowed error       │
│  ⚠️ status: string  →  Use 'pending' | 'active' | 'expired'    │
├─────────────────────────────────────────────────────────────────┤
│  GATE 4: HALLUCINATION        "Is every reference real?"        │
│  ─────────────────────────────────────────────────────────────  │
│  Fabricated APIs, non-existent imports, wrong parameter         │
│  signatures, version drift. Verified against source via         │
│  opensrc — not memory. This gate has no other owner.            │
│                                                                 │
│  ❌ prisma.user.findByEmail()  →  Doesn't exist. Use            │
│     findUnique({ where: { email } })                            │
│  ❌ import { useDebouncedQuery } from '@tanstack/react-query'   │
│     → This hook is not exported from the package                │
│  ❌ array.slice(5) when API is slice(start, end)                │
│     → Wrong parameter count for this method                     │
└─────────────────────────────────────────────────────────────────┘
```

#### How Evaluation Works (Step by Step)

```
Agent writes code
       │
       ▼
┌──────────────────┐
│ Apply Gate 1     │──FAIL──► "Missing import X on line 3" ──► Agent rewrites
│ (Functional)     │
└──────┬───────────┘
       │ PASS
       ▼
┌──────────────────┐
│ Apply Gate 2     │──FAIL──► "No dedup check on line 47" ──► Agent rewrites
│ (Logical)        │
└──────┬───────────┘
       │ PASS
       ▼
┌──────────────────┐
│ Apply Gate 3     │──FAIL──► "Magic number on line 22" ────► Agent rewrites
│ (Quality)        │         (or PASS_WITH_NOTES for non-blocking suggestions)
└──────┬───────────┘
       │ PASS
       ▼
┌──────────────────┐
│ Apply Gate 4     │──FAIL──► "findByEmail doesn't exist" ──► Agent rewrites
│ (Hallucination)  │
└──────┬───────────┘
       │ PASS
       ▼
  ✅ VERDICT: ACCEPT
       │
       ▼
  Run tests (TDD green phase)
```

**Each failure is surgical:** The feedback tells the agent exactly what to fix, where, and what the expected behavior is. No vague "looks wrong" — coordinates, not feelings.

#### The Verdict Format

Every evaluation produces a structured verdict:

```yaml
gate_1_functional: pass
gate_2_logical: fail
  detail: "POST /enroll creates duplicate entries"
  failing_case: "same student_id + course_id submitted twice"
gate_3_quality: pass_with_notes
  suggestion: "Extract status '3' as STATUS_EXPIRED constant on line 22"
gate_4_hallucination: pass
verdict: REJECT
reason: "Duplicate enrollment vulnerability in Gate 2"
feedback_to_agent: >
  Add uniqueness check before insert on line 47.
  Query: SELECT 1 FROM enrollments WHERE student_id = ? AND course_id = ?.
  If found, return 409 Conflict with message "Already enrolled".
  Write a test for the duplicate case.
```

#### Why Evaluation Matters

| Without evaluation | With evaluation |
|---|---|
| Code with hallucinated APIs reaches tests | Fabricated APIs caught before tests |
| "Looks good" → ship → bugs in production | 4 explicit gates → pass or fail with evidence |
| Edge cases discovered by users | Edge cases caught in Gate 2 before testing |
| Quality decays across iterations | Gate 3 catches rot early |
| 4 fix cycles of "try again" | 1 precise fix cycle with exact coordinates |

**The agent loop tightens from 4 vague iterations to 1 precise correction.** That's the power of structured evaluation.

---

### 4. `codeguard-review` — Post-Hoc Security Audit

**When it runs:** After implementation is complete, alongside `code-review`

**What it does:** Takes a git diff (`main...HEAD`) and audits every changed line against all 23 Project CodeGuard security rules. Reports findings by severity.

**The 12 rule sections:**

| § | Domain | What it catches |
|---|--------|----------------|
| §1 | Hardcoded Credentials & Cryptography | API keys in source, MD5/SHA-1 usage, missing TLS |
| §2 | Input Validation & Injection | SQL injection, command injection, LDAP injection, XXE |
| §3 | Authentication | Weak password storage, missing MFA, broken OAuth flows |
| §4 | Authorization | IDOR, mass assignment, missing access checks |
| §5 | API & Web Services | SSRF, missing rate limiting, GraphQL misconfig |
| §6 | Session Management | Cookie theft, session fixation, missing timeouts |
| §7 | Client-Side Web Security | XSS, CSRF, clickjacking, unsafe DOM APIs |
| §8 | Data Storage | Unencrypted connections, excessive privileges |
| §9 | Logging & Monitoring | Credential leaks in logs, log injection |
| §10 | Supply Chain & DevOps | Unpinned deps, missing lockfiles, known CVEs |
| §11 | File Handling | Path traversal, malicious uploads, zip bombs |
| §12 | Cloud, Containers & IaC | Root containers, open security groups, unencrypted resources |

**Severity classification:**

| Severity | Criteria | Examples |
|----------|----------|----------|
| 🔴 **CRITICAL** | Direct exploit: RCE, credential leak, SQLi | Hardcoded AWS keys, raw SQL concatenation, `pickle.loads` on user data |
| 🟠 **HIGH** | Significant weakness: auth bypass, data exposure | Missing CSRF, IDOR-vulnerable queries, MD5 for passwords |
| 🟡 **MEDIUM** | Best practice violation: weak config | Missing CSP, no security headers, running as root in Docker |
| ⚪ **LOW** | Improvement opportunity | Missing structured logging, no SBOM, no healthcheck |

**Invocation:**
```bash
/codeguard-review main          # Review branch against main
/codeguard-review HEAD~5        # Review last 5 commits
```

---

### 5. `implement` — The Orchestrator

**When it runs:** When you're ready to write code based on a spec or tickets

**What it does:** Orchestrates the full inner loop — all four skills above compose automatically.

**The complete inner loop:**

```
/implement
    │
    ├─ 1. Load /codeguard context
    │     Always-on rules: no secrets, strong crypto, parameterized queries
    │     Context rules: based on what files you're editing
    │
    ├─ 2. /tdd loop (red → green → refactor)
    │     For each slice:
    │       Write failing test (RED)
    │       Write minimal code (GREEN)
    │       Light cleanup (REFACTOR)
    │     Happy-path tests first, then edge cases
    │
    ├─ 3. /eval-ai-output (4-gate evaluation)
    │     Gate 1: Functional → Gate 2: Logical → Gate 3: Quality → Gate 4: Hallucination
    │     Any fail → surgical feedback → agent rewrites → re-evaluate
    │     All pass → ACCEPT → proceed
    │
    ├─ 4. Run typechecking, single test files, full test suite
    │
    ├─ 5. /codeguard-review (23-rule security audit of diff)
    │
    ├─ 6. /code-review (standards + spec review)
    │
    └─ 7. Commit to current branch
```

**You don't need to remember any of this.** Just run `/implement`. Everything is wired in.

---

## Quick Start

### Prerequisites

- [Pi coding agent](https://github.com/earendil-works/pi-coding-agent) installed
- Git

### Install

```bash
git clone https://github.com/abiolaks/security_skills_ai_coding.git
cd security_skills_ai_coding
./scripts/setup-codeguard.sh
```

### Verify

```bash
ls ~/.pi/agent/skills/
# Should show: codeguard  codeguard-review  eval-ai-output  implement  tdd
```

### Use

```bash
/implement    # Security + TDD + evaluation + review are all automatic
```

---

## The Full Skill Matrix

| # | Skill | Phase | Purpose | Lines |
|---|-------|-------|---------|-------|
| 1 | `codeguard` | Before generation | Load security rules into agent context | 165 |
| 2 | `tdd` | During generation | Test-first red→green→refactor cycle | 66 + refs |
| 3 | `eval-ai-output` | After generation, before tests | 4-gate validation & evaluation | 104 + refs |
| 4 | `codeguard-review` | After tests | 23-rule security audit of diff | 94 + 515 |
| 5 | `implement` | Orchestration | Wires all four skills into one command | 19 |

---

## How Test Cases and Edge Cases Flow Through the Pipeline

```
Spec/Ticket                    TDD (RED phase)              eval-ai-output
───────────                    ────────────────              ──────────────
"User can enroll"      →       test("enroll creates         Gate 2 catches:
                                an enrollment")             "Missing duplicate check"
                                                             ↓
                         →      test("enroll with            Agent adds:
                                missing course_id           test("enroll rejects
                                returns error")             duplicate enrollment")
                                                             ↓
                         →      (Agent should also          Implementation now
                                test: duplicates,           handles duplicates
                                full course,                → RED→GREEN cycle
                                expired period)
```

**The pipeline ensures:** Happy-path tests from spec → edge cases from logical reasoning → gaps caught by evaluation → everything verified by security audit. Four layers of defense for every line of code.

---

## Using with Other AI Coding Agents

The security rules are from Project CodeGuard — an open standard. See [`docs/SECURITY.md`](docs/SECURITY.md) for setup instructions for:

- Claude Code (`/plugin install codeguard-security@project-codeguard`)
- Cursor (download `codeguard-cursor.zip`)
- GitHub Copilot (download `codeguard-copilot.zip`)
- Windsurf (download `codeguard-windsurf.zip`)
- OpenAI Codex (`$skill-installer install`)

**Pi users get the most integrated experience** — the five skills compose into a single `/implement` command.

---

## Repository Structure

```
security_skills_ai_coding/
├── AGENTS.md                          ← Always-on critical rules
├── README.md                          ← This document
├── docs/
│   └── SECURITY.md                    ← Setup guide for all coding agents
├── scripts/
│   └── setup-codeguard.sh             ← One-command team install
├── slides/
│   └── codeguard-agentic-workflow.html ← Talk deck (14 slides)
└── .pi/skills/
    ├── codeguard/SKILL.md             ← Security guardrails (during generation)
    ├── tdd/                           ← Test-driven development
    │   ├── SKILL.md                   ← TDD process: red-green-refactor
    │   ├── tests.md                   ← Good vs bad test examples
    │   └── mocking.md                 ← Mocking guidelines
    ├── eval-ai-output/                ← 4-gate validation & evaluation
    │   ├── SKILL.md                   ← Evaluation process
    │   ├── GATES.md                   ← Gate definitions & failure modes
    │   └── TEMPLATE.yaml              ← Verdict output template
    ├── codeguard-review/              ← Post-hoc security audit
    │   ├── SKILL.md                   ← Audit process
    │   └── rules/security-rules.md    ← Full 23-rule checklist (515 lines)
    └── implement/SKILL.md             ← Orchestrator (wired to all skills)
```

---

## The Philosophy

### Why separate axes?

A change can pass one check and fail another:

- Code that follows every standard but has SQL injection → **Standards pass, Security fail**
- Code that is secure but doesn't match the spec → **Security pass, Spec fail**
- Code that implements the spec but has hallucinated imports → **Spec pass, Quality fail**

Reporting them separately stops one axis from masking another.

### Why during AND after?

**During generation (codeguard):** Prevents vulnerabilities. Cheapest time to fix.
**After generation (codeguard-review):** Catches what slipped through. Defense in depth.
**Neither alone is enough.** The 36.4% reduction came from both.

### Why evaluate before testing?

Tests only verify what you thought to test. The 4-gate evaluation catches what you didn't think of — hallucinated APIs, unhandled edge cases, quality decay — before they become "features" that tests accidentally lock in.

### Why TDD + evaluation instead of just TDD?

TDD catches what you wrote tests for. Evaluation catches what you didn't think to test. Together: complete coverage of both expected and unexpected failure modes.

---

## Credits

- **Project CodeGuard** by CoSAI / Cisco — [project-codeguard.org](https://project-codeguard.org/)
- **Agentic workflow** pattern by Matt Pocock
- **eval-ai-output** — 4-gate validation for AI-generated code
