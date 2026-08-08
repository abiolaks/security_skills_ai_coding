---
name: codeguard-review
description: Security review of code changes against 23 Project CodeGuard (CoSAI/Cisco) security rules. Covers cryptography, input validation, authentication, authorization, API security, session management, CSRF/XSS, data storage, logging, supply chain, file handling, cloud/IaC, and more. Use after implement and alongside code-review to catch security issues before they ship. Use when user asks for a security review, wants to check for vulnerabilities, or says "review this for security."
---

Security review of the diff between `HEAD` and a fixed point the user supplies. Applies the full **Project CodeGuard** ruleset — 23 OWASP/CWE-backed security rules — against every changed line to catch vulnerabilities before they reach production.

This skill is designed to run **alongside** `code-review` (which checks Standards + Spec). Security deserves its own dedicated axis so it doesn't get diluted by style nits or spec arguments.

## Process

### 1. Pin the fixed point

Whatever the user said is the fixed point — a commit SHA, branch name, tag, `main`, `HEAD~5`, etc. If they didn't specify one, ask for it.

Capture the diff: `git diff <fixed-point>...HEAD` (three-dot). Also note the commits: `git log <fixed-point>..HEAD --oneline`.

Confirm the fixed point resolves and the diff is non-empty. Fail fast if not.

### 2. Determine relevant rule categories from the diff

Scan the changed files to identify which security domains are in play:

| If the diff touches... | Activate these rule sections |
|---|---|
| Password hashing, key generation, encryption, TLS config | §1 Cryptography & Secrets |
| SQL queries, shell commands, LDAP, XML parsers, form inputs | §2 Input Validation & Injection |
| Login/logout, MFA, OAuth, password reset, token handling | §3 Authentication |
| Permissions, roles, middleware, access checks, admin routes | §4 Authorization |
| REST/GraphQL/SOAP endpoints, API routes, webhooks | §5 API & Web Services |
| Cookies, session stores, JWT issuance, localStorage | §6 Session Management |
| HTML templates, JS DOM manipulation, CSP headers, CORS | §7 Client-Side Web Security |
| DB connection strings, ORM queries, schema changes, backups | §8 Data Storage |
| Logger calls, error handlers, monitoring, alerting config | §9 Logging & Monitoring |
| package.json, requirements.txt, Dockerfile, CI/CD config | §10 Supply Chain & DevOps |
| File upload handlers, path resolution, multipart parsing | §11 File Handling |
| Dockerfile, K8s manifests, Terraform, CloudFormation, Helm | §12 Cloud, Containers & IaC |
| Any `.env`-like files, credential setup, config with secrets | §1 (always) Hardcoded Credentials |

### 3. Spawn the security review sub-agent

Send a `general-purpose` subagent with:

- The diff command and commit list.
- The **activated rule sections** from the rules file (read from `rules/security-rules.md` in this skill directory). Only include sections that match the diff — don't waste context on irrelevant rules.
- Always include §1 (Hardcoded Credentials) and §2 (Input Validation) as they are universally applicable.

The sub-agent prompt:

> "You are a security reviewer. Review the diff against the security rules below. For each finding: name the rule section violated, quote the offending hunk, explain the risk, and suggest a fix. Distinguish between CRITICAL (credential leak, RCE, SQLi), HIGH (auth bypass, data exposure), MEDIUM (weak crypto, missing headers), and LOW (best-practice guidance). Skip anything already caught by tooling (Semgrep, CodeQL, ESLint security plugins). Group findings by rule section. Under 500 words total."

### 4. Present the findings

Present the sub-agent's report under `## Security Review`, grouped by severity:

```
## Security Review — <fixed-point>...HEAD

### CRITICAL
- ...

### HIGH
- ...

### MEDIUM
- ...

### LOW
- ...
```

End with a one-line summary: **total findings by severity**, and whether the change is safe to ship from a security standpoint.

If zero findings: "✅ No security issues found in this diff. All changed code passes the CodeGuard ruleset."

## Integration with the Matt Pocock workflow

The full pipeline:

```
grill → to-spec → to-tickets → implement → code-review + codeguard-review
                                                         ↑
                                              Run both in parallel or
                                              code-review first, then
                                              codeguard-review
```

`codeguard-review` is the security-specific complement to `code-review`. Run it after `implement` — either in parallel with `code-review` or sequentially. The separation is intentional: security findings shouldn't compete with style nits.

## Why a separate security review

- **Different stakes.** A security finding ("this is SQL-injectable") is categorically different from a code-review finding ("this function name could be clearer"). Mixing them in one report dilutes both.
- **Different expertise.** The security ruleset is domain-specific, OWASP/CWE-backed, and maintained by Cisco security researchers. It doesn't belong inside a general standards file.
- **Measurable impact.** Project CodeGuard's own study (2,717 prompts, 5,434 generations) showed a 36.4% reduction in static analysis findings and 59.1% on the hardest benchmark. This isn't vibes-based — it's data-proven.
