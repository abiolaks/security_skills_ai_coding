# CodeGuard Security Setup

This project uses [Project CodeGuard](https://project-codeguard.org/) (CoSAI/Cisco) to embed security rules into AI coding workflows. Security is active **during code generation** (preventing bugs) and **after** (catching what slips through).

Choose your coding agent below.

---

## If you use Pi

One-time setup:

```bash
./scripts/setup-codeguard.sh
```

This installs two skills and wires them into your workflow:

| Skill | Purpose | When it runs |
|---|---|---|
| `codeguard` | Prevents vulnerabilities during code generation | Automatically loaded by `/implement` |
| `codeguard-review` | Audits the diff against all 23 CodeGuard rules | Run after `/implement`: `/codeguard-review main` |

Your workflow doesn't change:

```
grill → to-spec → to-tickets → /implement → /codeguard-review + /code-review
```

`/implement` now automatically loads security context before writing code and runs the security audit at the end.

---

## If you use Claude Code

```bash
# In Claude Code:
/plugin marketplace add cosai-oasis/project-codeguard
/plugin install codeguard-security@project-codeguard
/reload-plugins
```

Then use the `$codeguard` skill during sessions, or invoke `@codeguard-reviewer` for security reviews.

---

## If you use Cursor

1. Download `codeguard-cursor.zip` from the [releases page](https://github.com/cosai-oasis/project-codeguard/releases)
2. Extract and copy `.cursor/` to your project root
3. Restart Cursor

Rules are active automatically. The `@codeguard-reviewer` agent is available for security reviews.

---

## If you use GitHub Copilot

1. Download `codeguard-copilot.zip` from the [releases page](https://github.com/cosai-oasis/project-codeguard/releases)
2. Extract and copy `.github/` to your project root
3. Restart your IDE

---

## If you use Windsurf

1. Download `codeguard-windsurf.zip` from the [releases page](https://github.com/cosai-oasis/project-codeguard/releases)
2. Extract and copy `.windsurf/` to your project root
3. Restart Windsurf

---

## If you use OpenAI Codex

1. Download `codeguard-codex.zip` from the [releases page](https://github.com/cosai-oasis/project-codeguard/releases)
2. Extract and copy `.agents/` and `.codex/` to your project root
3. Restart Codex

Invoke with `$codeguard` or use `@codeguard-reviewer` for reviews.

---

## If you use OpenCode, OpenClaw, or Hermes

Download the respective archive from the [releases page](https://github.com/cosai-oasis/project-codeguard/releases) and follow the [Getting Started guide](https://project-codeguard.org/getting-started/).

---

## What the security rules cover

| Domain | What it prevents |
|---|---|
| Hardcoded credentials | API keys, passwords, tokens in source |
| Cryptography | Weak algorithms (MD5, DES, SHA-1), missing TLS |
| Input validation | SQL injection, XSS, command injection, path traversal |
| Authentication | Weak password storage, missing MFA, broken OAuth |
| Authorization | IDOR, mass assignment, missing access checks |
| API security | SSRF, missing rate limiting, broken GraphQL config |
| Session management | Cookie theft, fixation, missing timeouts |
| Client-side web | XSS, CSRF, clickjacking, unsafe DOM APIs |
| Data storage | Unencrypted connections, excessive privileges |
| Logging | Credential leaks in logs, log injection |
| Supply chain | Unpinned deps, missing lockfiles, known CVEs |
| File handling | Path traversal, malicious uploads, zip bombs |
| Cloud & containers | Root containers, open security groups, unencrypted resources |

---

## Keeping rules updated

The CodeGuard rules are maintained by CoSAI/OASIS and updated regularly. To stay current:

- **Pi users**: Re-run `./scripts/setup-codeguard.sh` periodically, or watch the [releases page](https://github.com/cosai-oasis/project-codeguard/releases)
- **Cursor/Copilot/Windsurf users**: The repo's `.github/workflows/update-codeguard-rules.yml` can auto-update rules monthly
- **Claude Code users**: `/plugin update codeguard-security@project-codeguard`

---

## Why this matters

In Cisco's controlled study (2,717 prompts, GPT-5), CodeGuard rules reduced security findings by **36.4%** overall and **59.1%** on the hardest benchmark. Clean snippets increased from 68.6% to 85.1%.

These aren't vibes — they're data-proven guardrails.
