---
name: codeguard
description: Security guardrails active during code generation. Prevents hardcoded credentials, weak cryptography, SQL injection, and other vulnerabilities from being introduced. Invoke before writing security-sensitive code or load as always-on context during implement sessions. Complements codeguard-review which audits changes after the fact.
---

# CodeGuard — Security Guardrails for Code Generation

You are writing code that will be deployed to production. Apply these security rules **as you write**, not as an afterthought. Every line you generate must pass these checks.

## ALWAYS-ON RULES (apply to every session, every file, every language)

### 🔴 RULE 1: Never Hardcode Credentials

**NEVER** write these into source code — not even temporarily, not even in comments:
- Passwords, API keys, tokens, private keys, connection strings, OAuth secrets
- Any string matching: `AKIA*` (AWS), `sk_live_*`/`sk_test_*` (Stripe), `AIza*` (Google), `ghp_*`/`gho_*` (GitHub), `-----BEGIN ... PRIVATE KEY-----`
- Variables named `password`, `secret`, `key`, `token`, `auth` assigned string literals
- `mongodb://user:pass@host`, `postgres://user:pass@host`, or any connection string with embedded credentials

**ALWAYS use:** environment variables (`process.env.VAR`, `os.environ["VAR"]`), secrets manager, or config files outside the repo. Never read these files — reference them.

### 🔴 RULE 2: Never Use Weak Cryptography

**BANNED — never generate code using:**
- MD2, MD4, MD5, SHA-0, SHA-1 as security controls
- RC2, RC4, Blowfish, DES, 3DES
- AES in ECB or CBC mode (use GCM)
- RSA with PKCS#1 v1.5 padding
- Static RSA key exchange, Anonymous Diffie-Hellman

**REQUIRED — always use:**
- SHA-256 or stronger for hashing
- AES-256-GCM or ChaCha20-Poly1305 for symmetric encryption
- **Argon2id** for password hashing (preferred); scrypt or bcrypt (cost ≥10) as fallbacks
- TLS 1.3 only; HTTPS everywhere
- CSPRNG for all random values (never `Math.random()`, `rand()`, `random.random()` for security)

### 🔴 RULE 3: Never Concatenate User Input into Queries or Commands

**SQL — always use parameterized queries:**
```python
# ❌ NEVER
cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")
query = "SELECT * FROM users WHERE name = '" + name + "'"

# ✅ ALWAYS
cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,))
```

**Shell — never use shell=True or string-built commands:**
```python
# ❌ NEVER
os.system(f"ffmpeg -i {user_file}")
subprocess.run(f"ffmpeg -i {user_file}", shell=True)

# ✅ ALWAYS
subprocess.run(["ffmpeg", "-i", user_file])
```

**Dynamic identifiers (table/column names) — always allow-list:**
```python
ALLOWED_COLUMNS = {"id", "name", "email", "created_at"}
if sort_by not in ALLOWED_COLUMNS:
    raise ValueError(f"Invalid column: {sort_by}")
```

### 🟡 RULE 4: Validate All Untrusted Input at Trust Boundaries

- Positive (allow-list) validation — define what's valid, reject everything else
- Validate type, format, range, and length for every input field
- Canonicalize encodings before validation
- File uploads: validate by magic bytes (not extension), enforce size caps, server-generate filenames, store outside web root
- Reject null bytes, `../`, absolute paths in file operations

---

## CONTEXT-SCOPED RULES (apply based on what you're building)

### When writing AUTH code (login, signup, password reset, MFA, OAuth):

- **Passwords:** Argon2id with per-user salt, constant-time comparison. Check against breach corpora (k-anonymity API). Never encrypt — hash only.
- **Account enumeration:** Always return identical "Invalid username or password" — same response, same timing, same status code.
- **MFA:** Require for login, password changes, privilege elevation. Prefer WebAuthn/passkeys. TOTP acceptable. Never SMS/voice.
- **OAuth/OIDC:** Authorization Code + PKCE only. Never Implicit grant or ROPC. Validate state/nonce. Exact redirect URI matching. Never hardcode client secrets.
- **Recovery tokens:** CSPRNG, 32+ bytes, single-use, stored as SHA-256 hashes, short expiry (≤1 hour). Same response whether account exists or not.
- **Rate limiting:** Per-IP, per-account, per-endpoint. Progressive backoff, not permanent lockout.

### When writing PERMISSIONS / access control code:

- **Deny by default.** If no allow rule matches → 403 Forbidden.
- **IDOR prevention:** Resolve resources through user-scoped queries. Never `Model.find(user_supplied_id)` — always `current_user.models.find(id)`.
- **Mass assignment:** Use explicit allow-lists for fields. Never bind request body directly to domain objects.
- **Step-up auth:** Require re-authentication for wire transfers, privilege changes, data export.

### When writing API endpoints (REST/GraphQL):

- **HTTPS only.** HSTS. Never mix HTTP/HTTPS.
- **Input validation:** Reject unknown fields. Set payload size limits. Enforce Content-Type.
- **SSRF prevention:** Never accept raw URLs from users for outbound requests. Block private IP ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 127.0.0.0/8, 169.254.0.0/16). Block `file://`, `gopher://`, `ftp://`.
- **GraphQL:** Limit query depth/complexity. Disable introspection in production. Field-level authorization.
- **Rate limiting:** Per-IP/user/client. Circuit breakers. Timeouts.

### When writing SESSION / cookie code:

- **Session IDs:** CSPRNG, ≥128 bits entropy, opaque. All data server-side. Never in localStorage/sessionStorage.
- **Cookie flags:** `Secure; HttpOnly; SameSite=Strict; Path=/`
- **Rotation:** Regenerate session ID on login, password change, privilege elevation. Invalidate old ID.
- **Timeouts:** Idle 15–30 min, absolute 4–8 hours. Enforced server-side.
- **Fingerprinting:** Track IP + User-Agent changes. High-risk → re-auth. Medium → step-up. Low → log.

### When writing HTML/JS frontend code:

- **XSS sinks to avoid:** `innerHTML`, `outerHTML`, `document.write()`, `eval()`, `new Function()`, string-based `setTimeout`/`setInterval`. Use `textContent` or DOMPurify instead.
- **CSP baseline:** `default-src 'self'; frame-ancestors 'self'; form-action 'self'; object-src 'none'; base-uri 'none'`
- **CSRF tokens on all state-changing requests.** Never use GET for mutations.
- **External links:** `rel="noopener noreferrer"` on `target=_blank`.
- **postMessage:** Always verify `event.origin`. Always specify exact target origin.
- **CORS:** Never `Access-Control-Allow-Origin: *`. Allow-list specific origins.

### When writing DATABASE code:

- **TLS 1.2+** for all DB connections. Verify certificates.
- **Least privilege:** Dedicated accounts per app. No root/sa/SYS. Grant only required permissions (SELECT/INSERT/UPDATE/DELETE).
- **Row-level security** where available (PostgreSQL RLS, etc.).
- **Never store credentials in source code** (see RULE 1).

### When writing DOCKER / K8s / Terraform / IaC:

- **Docker:** Pin base image digests (not `:latest`). Run as non-root (`USER 1000`). Use `.dockerignore`. Never put secrets in ENV. Use multi-stage builds.
- **K8s:** `runAsNonRoot: true`. `allowPrivilegeEscalation: false`. Set resource limits. No hostNetwork/hostPID. Never mount hostPath without extreme scrutiny.
- **Terraform/CloudFormation:** No hardcoded secrets. No `0.0.0.0/0` on sensitive ports. No `"Resource": "*", "Action": "*"` in IAM. Encrypt everything (RDS, EBS, S3, etc.).

### When writing LOGGING / error handling:

- **Never log:** credentials, tokens, recovery codes, raw session IDs, PII, full request bodies containing sensitive data
- **Always log:** auth events, admin actions, config changes, input validation failures, security errors
- **Structured logs (JSON)** with correlation IDs, UTC timestamps
- **Sanitize** log inputs — strip CR/LF/delimiters to prevent log injection

### When writing FILE UPLOAD / file handling:

- **Path traversal:** Canonicalize paths. Verify result stays within allowed directory. Reject `../`, absolute paths, null bytes.
- **Archive bombs:** Validate decompressed size before extraction. Check for path traversal in archive entries.
- **Server-generate filenames.** Never use user-supplied filenames directly.

---

## WORKFLOW INTEGRATION

When writing code that touches any of the domains above, **pause and check** the relevant rules before generating. Then:

1. **Write the code** following the rules
2. **Self-check:** Before finishing, mentally audit your output against the ALWAYS-ON rules (Rules 1–4)
3. **Document intent:** If a rule appears violated but isn't (e.g., MD5 used for checksumming, not security), add a comment explaining why

When in doubt between a convenient-but-insecure pattern and a secure pattern, **always choose the secure pattern**. Speed is not an excuse for SQL injection.

---

## RELATIONSHIP TO codeguard-review

This skill (`codeguard`) prevents vulnerabilities **during code generation**.
`codeguard-review` catches what slips through **after the fact**.

Use both: load `codeguard` context during `implement`, then run `codeguard-review` after. Defense in depth.
