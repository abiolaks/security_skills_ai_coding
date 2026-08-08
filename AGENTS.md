# Project Security Instructions

## Critical Security Rules (Always Active)

When writing ANY code in this project, follow these rules:

### 1. Never hardcode credentials
No passwords, API keys, tokens, private keys, or connection strings in source code. Use environment variables or a secrets manager. Watch for patterns: `AKIA*` (AWS), `sk_live_*` (Stripe), `ghp_*` (GitHub), `-----BEGIN ... PRIVATE KEY-----`, connection strings with embedded credentials.

### 2. Never use weak cryptography
Banned: MD5, SHA-0, SHA-1 (as security control), DES, 3DES, RC2, RC4, Blowfish, AES-ECB, AES-CBC. Use: Argon2id for passwords, AES-256-GCM for encryption, TLS 1.3, CSPRNG for all random values.

### 3. Never concatenate user input into queries or commands
Always use parameterized queries for SQL. Never `shell=True` in subprocess. Allow-list dynamic identifiers (table/column names). Validate all input at trust boundaries with positive allow-lists.

### 4. Load full security context for sensitive work
When building auth, APIs, payment flows, admin panels, or anything handling user data, invoke `/codeguard` first for the full ruleset (covers authentication, authorization, session management, XSS/CSRF, SSRF, file handling, container security, and more).

## Workflow

```
grill → to-spec → to-tickets → implement → codeguard-review + code-review
```

- **implement**: The 4 rules above are always active. For security-sensitive features, run `/codeguard` first.
- **codeguard-review**: After implement, audits the diff against all 23 CodeGuard security rules.
