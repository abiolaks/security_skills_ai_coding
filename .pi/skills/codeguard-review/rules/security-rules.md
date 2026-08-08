# Project CodeGuard Security Rules — Review Checklist

> Sourced from [cosai-oasis/project-codeguard](https://github.com/cosai-oasis/project-codeguard) (CoSAI / OASIS Open Project).
> These rules are derived from OWASP, CWE, and industry best practices.
> In controlled experiments (2,717 prompts, GPT-5), these rules reduced static analysis findings by 36.4%.

---

## §1 — Hardcoded Credentials & Cryptography (ALWAYS APPLY)

### 1.1 No Hardcoded Credentials — CRITICAL

**NEVER** store these in source code:
- Passwords, API keys, tokens, private keys, connection strings with credentials
- OAuth client secrets, webhook secrets, signing keys

**Recognition patterns — flag immediately:**
- AWS keys (`AKIA`, `AGPA`, `AIDA`, `AROA`, `ASIA` prefixes)
- Stripe keys (`sk_live_`, `sk_test_`)
- Google API keys (`AIza` + 35 chars)
- GitHub tokens (`ghp_`, `gho_`, `ghu_`, `ghs_`, `ghr_`)
- JWT tokens (starts with `eyJ`)
- Private key blocks (`-----BEGIN ... PRIVATE KEY-----`)
- Connection strings with embedded credentials (`mongodb://user:pass@host`)
- Variables named: `password`, `secret`, `key`, `token`, `auth` containing string literals

**Fix:** Use environment variables, secrets manager (KMS/HSM/vault), or config files outside the repo. Never check credentials into source control.

### 1.2 Cryptographic Algorithms — CRITICAL/HIGH

**Banned (never use):**
- Hash: MD2, MD4, MD5, SHA-0
- Symmetric: RC2, RC4, Blowfish, DES, 3DES
- Key Exchange: Static RSA, Anonymous Diffie-Hellman
- Classical: Vigenère

**Deprecated (avoid in new code):**
- Hash: SHA-1
- Symmetric: AES-CBC, AES-ECB
- Signature: RSA with PKCS#1 v1.5 padding
- Key Exchange: DHE with weak/common primes

**Required (use these):**
- Hash: SHA-256 or stronger (SHA-384, SHA-512)
- Symmetric: AES-256-GCM (AEAD), ChaCha20-Poly1305
- Key Exchange: ECDHE with X25519 or secp256r1; prefer hybrid PQC (X25519MLKEM768)
- Passwords: Argon2id (preferred) > scrypt > bcrypt (cost ≥10) > PBKDF2-HMAC-SHA-256 (≥600k iterations)
- TLS: (D)TLS 1.3 only; HTTPS everywhere; HSTS enabled

**Password hashing checklist:**
- Use slow, memory-hard algorithms (Argon2id preferred)
- Unique per-user salt, constant-time comparison
- Never encrypt passwords — always hash
- Check new passwords against breach corpora (k-anonymity APIs)

---

## §2 — Input Validation & Injection Defense

### 2.1 SQL Injection Prevention — CRITICAL

**Rule:** 100% parameterized queries. Never concatenate user input into SQL.

**Flag patterns:**
- String interpolation in SQL: `f"SELECT * FROM users WHERE id = {user_id}"`
- String concatenation: `"SELECT * FROM users WHERE name = '" + name + "'"`
- Dynamic table/column names without allow-list validation
- Raw `cursor.execute()` with format strings

**Fix:** Prepared statements (JDBC, .NET SqlCommand, PHP PDO, Python sqlx, Ruby ActiveRecord bind params). For dynamic identifiers (table/column names), use strict allow-lists.

### 2.2 OS Command Injection — CRITICAL

**Rule:** Prefer built-in APIs over shelling out. If unavoidable, use structured execution (ProcessBuilder, subprocess.run with list args, not `shell=True`).

**Flag patterns:**
- `shell=True` in Python subprocess
- `exec()`, `system()`, backtick execution in any language
- String-built shell commands with user input
- `Runtime.getRuntime().exec(string)` (use array form)

### 2.3 LDAP Injection — HIGH

**Flag:** LDAP filter strings built with user input without DN/filter escaping.
**Fix:** Use library DN/filter encoders; validate inputs with allow-lists.

### 2.4 XSS Prevention — See §7 (Client-Side Web Security)

### 2.5 Prototype Pollution (JavaScript) — MEDIUM

**Flag:** Unsafe deep merge, object spread from user input, `Object.assign` with untrusted sources.
**Fix:** `Object.create(null)`, block `__proto__`/`constructor`/`prototype` keys, use `new Map()` instead of object literals for user-keyed data.

### 2.6 XML External Entity (XXE) — HIGH

**Flag:** XML parsers with default config, no `disallow_doctype`, no entity expansion limits.
**Fix:** Disable DTD/DOCTYPE, disable external entities, set entity expansion limits, use defusedxml (Python) or equivalent.

### 2.7 General Validation Playbook — MEDIUM

- Positive (allow-list) validation preferred over negative (block-list)
- Canonicalize encodings before validation
- Validate type, format, range, length for every field
- File uploads: validate by content type (magic bytes), size caps, safe extensions; store outside web root; server-generate filenames

---

## §3 — Authentication

### 3.1 Password Handling — CRITICAL

See §1.2 for hashing algorithms. Additionally:
- Accept passphrases + full Unicode, minimum 8 characters, max 64+
- Reject breached/common passwords (check against k-anonymity APIs)
- Never encrypt passwords (hash only)
- Constant-time comparison for hash verification

### 3.2 Account Enumeration Prevention — HIGH

**Flag:** Different error messages for "user not found" vs "wrong password", timing differences.
**Fix:** Always return generic "Invalid username or password"; uniform timing on all paths.

### 3.3 MFA — HIGH

- Require MFA for: login, password/email changes, disabling MFA, privilege elevation, high-value transactions
- Prefer WebAuthn/passkeys (FIDO2) or hardware U2F
- TOTP acceptable; avoid SMS/voice and security questions
- Provide single-use backup codes; require strong identity verification for resets

### 3.4 OAuth 2.0 / OIDC — HIGH

**Flag patterns:**
- Implicit grant flow (use Authorization Code + PKCE)
- Missing PKCE for public/native apps
- No state parameter validation
- Loose redirect URI matching (must be exact)
- Resource Owner Password Credentials (ROPC) flow

### 3.5 Token Security — HIGH

- JWTs: pin algorithms (`"alg": "RS256"` not `"none"`), validate iss/aud/exp/iat/nbf, short lifetimes, rotation
- Prefer opaque server-managed tokens when revocation is needed
- Store secrets in KMS/HSM; never hardcode signing keys
- Implement token denylist for logout/revoke

### 3.6 Recovery/Reset — HIGH

- CSPRNG tokens, 32+ bytes, single-use, stored as hashes, short expiry (≤1 hour)
- Same response for existing and non-existing accounts
- Require re-authentication after reset; rotate sessions; do not auto-login

---

## §4 — Authorization & Access Control

### 4.1 Core Principles — CRITICAL

**Deny by default.** The default for any access request is 'deny'. Only explicitly granted permissions allow access. Return HTTP 403 (or 404 to avoid leaking existence).

### 4.2 IDOR Prevention — CRITICAL

**Flag:** User-supplied IDs used directly in queries without ownership verification.
```python
# ❌ VULNERABLE
project = Project.find(params[:id])

# ✅ FIXED
project = current_user.projects.find(params[:id])
```
**Fix:** Resolve resources through user-scoped queries. Use non-enumerable identifiers (UUIDs) as defense-in-depth.

### 4.3 Mass Assignment — HIGH

**Flag:** Request body bound directly to domain/DB objects.
```python
# ❌ VULNERABLE
user.update(request.body)  # attacker can set user.admin = true

# ✅ FIXED
user.update(request.body, allowed_fields=['name', 'email'])
```
**Fix:** Use DTOs with explicit allow-lists for patch/update operations.

### 4.4 Step-Up Authorization — HIGH

For sensitive actions (wire transfers, privilege elevation, data export):
- Require second factor (re-auth, MFA, hardware token)
- Use unique, time-limited authorization credentials per transaction
- Enforce server-side; prevent client-side downgrades

### 4.5 Authorization Testing — MEDIUM

- Maintain authorization matrix (YAML/JSON): endpoint × role → expected outcome
- Automate integration tests that iterate the matrix
- Test: swapped IDs, downgraded roles, missing scopes, expired tokens

---

## §5 — API & Web Services Security

### 5.1 Transport — CRITICAL/HIGH

- HTTPS only; HSTS enabled
- Consider mTLS for internal/high-value services
- Validate certs (CN/SAN, revocation); no mixed content

### 5.2 Input Validation — HIGH

- Validate via contracts: OpenAPI/JSON Schema, GraphQL SDL, XSD
- Reject unknown fields and oversize payloads; set size limits
- Enforce explicit Content-Type/Accept; reject unsupported combinations

### 5.3 GraphQL-Specific — HIGH

- Limit query depth and complexity; enforce pagination; execution timeouts
- Disable introspection and GraphQL IDEs in production
- Implement field/object-level authorization (prevent IDOR/BOLA)

### 5.4 SSRF Prevention — CRITICAL

**Flag:** Accepting raw URLs from users for outbound HTTP calls.
**Fix:**
- Fixed partners: strict allow-lists; disable redirects; network egress allow-lists
- Arbitrary URLs: block private/link-local/localhost ranges (127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16); resolve and verify IPs are public; block `file://`, `gopher://`, `ftp://`
- Never accept raw user URLs without validation

### 5.5 Rate Limiting — MEDIUM

- Per-IP, per-user, per-client limits; circuit breakers; timeouts
- Management endpoints isolated (not exposed to internet); require MFA + network restrictions

---

## §6 — Session Management & Cookies

### 6.1 Session ID Requirements — HIGH

- CSPRNG-generated, ≥64 bits entropy (prefer 128+)
- Opaque, unguessable, no meaning embedded
- Generic cookie names (e.g., `id`), not framework defaults
- All session data stored server-side; no PII or privileges in token

### 6.2 Cookie Security — HIGH

**Required flags on session cookies:**
```
Set-Cookie: id=<opaque>; Secure; HttpOnly; SameSite=Strict; Path=/
```

### 6.3 Session Lifecycle — HIGH

- Regenerate session ID on: login, password change, privilege elevation
- Invalidate prior ID on rotation
- Idle timeout: 2–5 min (high-value), 15–30 min (standard)
- Absolute timeout: 4–8 hours
- Enforce timeouts server-side (not just in cookie expiry)

### 6.4 Logout — HIGH

- Full server-side invalidation; clear cookie client-side; visible logout button
- `Cache-Control: no-store` on responses with session identifiers

### 6.5 Theft Detection — MEDIUM

- Server-side fingerprint: IP, User-Agent, Accept-Language, sec-ch-ua
- Compare incoming requests; allow benign drift
- Risk-based response: high (re-auth + rotate), medium (step-up + rotate), low (log)

### 6.6 Anti-Patterns — HIGH

**Never:**
- Store session tokens in `localStorage`/`sessionStorage` (XSS risk)
- Mix HTTP/HTTPS in the same session
- Accept user-provided session IDs (always server-generated)

---

## §7 — Client-Side Web Security

### 7.1 XSS Prevention — CRITICAL

**Dangerous sinks — flag immediately:**
- `innerHTML`, `outerHTML`, `document.write()` with untrusted data
- `eval()`, `new Function()`, string-based `setTimeout`/`setInterval`
- Untrusted data in `location.href`, event handler attributes
- Building HTML via string concatenation

**Fix:** Prefer `textContent`; sanitize with DOMPurify (allow-list tags/attrs); adopt Trusted Types + strict CSP.

### 7.2 Content Security Policy (CSP) — HIGH

Baseline to aim for:
```
Content-Security-Policy: default-src 'self'; style-src 'self' 'unsafe-inline';
  frame-ancestors 'self'; form-action 'self'; object-src 'none'; base-uri 'none'
```
Prefer nonce-based or hash-based CSP over domain allow-lists.

### 7.3 CSRF Defense — HIGH

- Framework-native CSRF tokens on all state-changing requests (POST/PUT/DELETE/PATCH)
- `SameSite=Lax` or `Strict` on session cookies
- Validate Origin/Referer headers
- Never use GET for state changes

### 7.4 Clickjacking — MEDIUM

- `Content-Security-Policy: frame-ancestors 'none'` (or specific allow-list)
- Fallback: `X-Frame-Options: DENY`

### 7.5 Security Headers — MEDIUM

Check for presence:
- `Strict-Transport-Security: max-age=31536000; includeSubDomains`
- `X-Content-Type-Options: nosniff`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Permissions-Policy`: restrict sensitive capabilities

### 7.6 Third-Party JS — MEDIUM

- Subresource Integrity (SRI) on external scripts: `<script integrity="sha384-...">`
- Sandboxed iframes with `sandbox` attribute + postMessage origin checks
- Minimize and isolate third-party access

### 7.7 postMessage, CORS, WebSockets — HIGH

- postMessage: always specify exact target origin; verify `event.origin` on receive
- CORS: avoid `Access-Control-Allow-Origin: *`; allow-list origins; validate preflights
- WebSockets: `wss://` only; origin checks; auth; message size limits
- External links: `rel="noopener noreferrer"` on `target=_blank`

---

## §8 — Data Storage Security

### 8.1 Database Isolation — HIGH

- Isolate DB servers from other systems; firewall rules restrict access
- Never allow direct client-to-database connections
- Place DB in separate network segment/DMZ from app server

### 8.2 Transport Encryption — HIGH

- TLS 1.2+ for all database connections; verify certificates
- Encrypt all database traffic, not just authentication

### 8.3 Authentication — HIGH

- Always require authentication (including local connections)
- Dedicated accounts per application/service; strong unique passwords
- Regularly review and remove unused accounts

### 8.4 Credential Storage — CRITICAL

See §1.1. Database credentials must be in secrets manager/env vars, never in source code.

### 8.5 Least Privilege — HIGH

- No root/sa/SYS accounts for application access
- No administrative rights to application accounts
- Grant only required permissions (SELECT, UPDATE, DELETE as needed)
- Separate databases/accounts for Dev, UAT, Production
- Implement row-level security (RLS) where available

### 8.6 Hardening — MEDIUM

- Run DB services under low-privileged OS accounts
- Remove default accounts and sample databases
- Encrypted backups with proper permissions
- Disable dangerous stored procedures (e.g., `xp_cmdshell` in SQL Server)
- Regular security patches

---

## §9 — Logging & Monitoring

### 9.1 What to Log — MEDIUM

Must log: authn/authz events, admin actions, config changes, sensitive data access, input validation failures, security errors.
Include: correlation/request IDs, user/session IDs (non-PII), source IP, user agent, UTC timestamps (RFC3339).

### 9.2 How to Log — HIGH

- Structured logs (JSON) with stable field names
- Sanitize inputs to prevent log injection (strip CR/LF/delimiters)
- **CRITICAL: Never log credentials, tokens, recovery codes, raw session IDs, or PII**
- Redact/tokenize sensitive fields before logging

### 9.3 Log Integrity — MEDIUM

- Append-only or WORM storage; tamper detection
- Centralized aggregation; access controls; retention policies
- Isolate log storage (separate partition); store outside web-accessible locations
- Secure protocols for log transmission

### 9.4 Detection & Alerting — MEDIUM

- Alerts for: auth anomalies (credential stuffing, impossible travel), privilege changes, excessive failures, SSRF indicators, data exfiltration patterns
- Tested runbooks; on-call coverage

---

## §10 — Supply Chain & DevOps Security

### 10.1 Dependencies — HIGH

- Lockfiles required (`package-lock.json`, `yarn.lock`, `Cargo.lock`, `Pipfile.lock`, `Gemfile.lock`)
- Version pinning; prefer digest pinning for Docker images
- Regular SCA scanning (`npm audit`, `pip audit`, `cargo audit`); fail CI on critical CVEs
- Generate SBOMs; attest provenance (SLSA, Sigstore)

### 10.2 CI/CD Pipeline — HIGH

- SCA, SAST, IaC scans in CI gates; fail on criticals
- Sign artifacts; verify signatures at deploy
- Hermetic builds: no network during compile unless required; cache with authenticity checks
- Separate Dev/UAT/Prod credentials; never share secrets across environments

### 10.3 Dependency Hygiene — MEDIUM

- Minimize dependency footprint; prefer stdlib for trivial tasks
- Remove unused packages
- Protect against typosquatting: pin maintainers, monitor releases, use provenance checks
- Enable 2FA on package registry accounts

### 10.4 Vulnerability Management — HIGH

- For patched vulns: test and deploy updates within SLA
- For unpatched vulns: implement compensating controls; document risk decisions
- Auto-open tickets for critical CVEs; monitor threat intel feeds

---

## §11 — File Handling & Uploads

### 11.1 File Upload Validation — HIGH

- Validate by content type (magic bytes), not just file extension
- Enforce maximum file size limits
- Allow-list safe extensions only
- Store uploaded files outside the web root
- Server-generate filenames (never use user-supplied filenames directly)
- Scan uploaded files for malware

### 11.2 Path Traversal Prevention — CRITICAL

**Flag:** User input used in file paths without normalization.
```python
# ❌ VULNERABLE
path = f"/uploads/{user_input}"
with open(path) as f: ...

# ✅ FIXED
safe_name = os.path.basename(user_input)
path = os.path.join("/uploads", safe_name)
# Validate path stays within /uploads
```
**Fix:** Canonicalize paths; verify result stays within allowed directory; reject `../`, absolute paths, null bytes.

### 11.3 Zip/Archive Safety — MEDIUM

- Validate decompressed size before extraction (zip bombs)
- Check for path traversal in archive entries
- Limit number of files and total extraction size

---

## §12 — Cloud, Containers & Infrastructure-as-Code

### 12.1 Docker Security — HIGH

**Flag patterns:**
- `FROM latest` (pin specific digest)
- Running as root (`USER root` or no USER directive)
- Secrets in `ENV` or `ARG` (use secrets mounts or build args with caution)
- `COPY . .` without `.dockerignore`
- Exposed ports without documented need
- `--privileged` flag
- No healthcheck defined

**Fix:** Pin base image digests, run as non-root user, use multi-stage builds, `.dockerignore`, HEALTHCHECK.

### 12.2 Kubernetes Security — HIGH

**Flag patterns:**
- `runAsNonRoot: false` or missing
- `allowPrivilegeEscalation: true`
- No resource limits/requests
- No `securityContext` defined
- `hostNetwork: true`, `hostPID: true`, `hostIPC: true`
- Mounting host paths (`hostPath` volumes)
- No network policies
- Secrets in pod specs without encryption

### 12.3 IaC Security — HIGH

**Flag patterns (Terraform/CloudFormation/Pulumi):**
- Hardcoded secrets in resource definitions
- S3 buckets with `acl = "public-read"` or `public_access = true`
- Security groups with `0.0.0.0/0` on sensitive ports (22, 3389, 5432, 3306, 27017)
- RDS `publicly_accessible = true`
- IAM policies with `"Effect": "Allow", "Resource": "*", "Action": "*"`
- Unencrypted resources: no `encrypted = true` on RDS, EBS, S3, etc.
- Storage account `enable_https_traffic_only` not set to true

---

## Quick Reference: Severity Classification

| Severity | Criteria | Examples |
|---|---|---|
| **CRITICAL** | Direct exploit: RCE, credential leak, SQLi, SSRF, auth bypass | Hardcoded AWS keys, raw SQL concatenation, pickle.loads on user data, shell=True with user input |
| **HIGH** | Significant weakness: broken access control, missing encryption, XSS | Missing CSRF protection, IDOR-vulnerable queries, MD5 for passwords, localStorage for tokens |
| **MEDIUM** | Best practice violation: weak config, missing hardening | Missing security headers, no CSP, running as root in Docker, plaintext logging of session data |
| **LOW** | Improvement opportunity: logging gaps, monitoring coverage | Missing structured logging, no SBOM, no healthcheck in Dockerfile |
