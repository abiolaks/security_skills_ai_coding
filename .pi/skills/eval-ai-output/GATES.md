# Gate Definitions

Each gate is a self-contained check with clear pass/fail criteria. Never produce vague feedback — every failure includes the exact location, the observed behaviour, and the expected behaviour.

## Gate 1: Functional

### What it checks
- Does the code compile / parse without errors?
- Are all imports present and resolvable?
- Is the syntax valid for the target language version?
- Do type annotations resolve (TypeScript, mypy, etc.)?

### How to check
- **Compiled languages:** Does it compile? If not, the error message is the detail.
- **Interpreted languages:** Scan for syntax errors, missing imports, undefined references.
- **TypeScript:** Run `tsc --noEmit` or visually verify types resolve.

### Failure modes
| Failure | Example | Feedback |
|---------|---------|----------|
| Missing import | `useQuery` used but not imported from `@tanstack/react-query` | "Import `useQuery` from `@tanstack/react-query` at line 3" |
| Syntax error | Unmatched brace, missing semicolon | Exact line and character |
| Undefined reference | Variable `result` used before declaration | "`result` is referenced on line 12 but declared on line 15" |
| Type mismatch | `string` assigned to `number` parameter | "Parameter expects `number` but receives `string` on line 8" |

### When to skip to Gate 2
Gate 1 passes cleanly. If it fails, stop — the code doesn't run, and the remaining gates are irrelevant.

---

## Gate 2: Logical

### What it checks
- Does the solution solve the stated problem, not a different problem?
- Are edge cases handled (null, undefined, empty arrays, zero, negative numbers)?
- Are boundary conditions correct (off-by-one, inclusive/exclusive ranges)?
- Does it handle duplicates, concurrent operations, race conditions if relevant?
- Does it respect invariants and preconditions?

### How to check
- Walk through the happy path mentally — does the output match expectations?
- Identify every edge case implied by the problem domain, not just the ones tested.
- Check for assumptions that aren't validated (e.g., "assumes array is non-empty" but doesn't guard).
- For CRUD/data operations: duplicates, missing records, concurrent writes.

### Failure modes
| Failure | Example | Feedback |
|---------|---------|----------|
| Missing null check | `user.name` when `user` can be null | "`user` can be null on line 23. Add a null guard before accessing `.name`" |
| Off-by-one | Loop runs `i <= arr.length` | "Array index out of bounds on line 15. Condition should be `i < arr.length`" |
| Missing duplicate handling | POST accepts duplicate enrollment | "Gate 2 fail: no uniqueness check. POST same student+course twice creates duplicate. Check for existing enrollment before insert." |
| Wrong problem solved | Function sorts when it should filter | "Function sorts the list but the requirement is to filter. Replace `sort()` with `filter()` on line 8." |
| Incomplete validation | Accepts empty string as valid email | "`validateEmail('')` returns true. Add empty string check before regex on line 42." |

### A special note on "the gap"
`/tdd` catches edge cases you wrote tests for. This gate catches edge cases you *didn't think to test*. That's the gap. When you find one, write the test *and* fix the code — don't just fix the code alone.

---

## Gate 3: Quality

### What it checks
- **Naming:** Are variables, functions, and types named for what they do, not how?
- **Coupling:** Is the module unnecessarily coupled to implementation details of its dependencies?
- **Magic values:** Are hardcoded numbers/strings extracted as named constants?
- **Error handling:** Are errors caught at the right level? Not swallowed silently?
- **Type usage:** Are types precise (`Date` not `string`, `enum` not `number`)? No `any` without justification?
- **Function length:** Are functions doing one thing? Can a reader hold the whole function in their head?

### How to check
- Read the code as if you've never seen it before. What's confusing?
- Look for numbers repeated without names (`if (status === 3)` — what's 3?).
- Check that errors propagate meaningfully, not as generic `Error('something went wrong')`.
- Verify types are the narrowest that work (`'pending' | 'active' | 'expired'`, not `string`).

### Failure modes
| Failure | Example | Feedback |
|---------|---------|----------|
| Bad naming | `const d = calculate(x, y)` | "`d` doesn't communicate intent. Rename to `discountAmount`." |
| Magic number | `if (attempts > 5)` | "`5` is a magic number. Extract as `MAX_RETRY_ATTEMPTS` at the top of the file." |
| Swallowed error | `try { await save() } catch (e) {}` | "Error is silently swallowed on line 34. At minimum, log the error. Consider whether the caller should handle this." |
| Loose type | `status: string` | "`status` should be a union type: `'pending' \| 'active' \| 'expired'`. Using `string` allows invalid values." |
| Deep coupling | Function imports internal helper from another module | "Function on line 12 depends on `formatInternalId` from a sibling module's private helper. Extract to shared util or pass as dependency." |

### Pass with notes
Not every quality issue blocks acceptance. If something is suboptimal but not broken, use `pass_with_notes` and include the suggestion — it goes to the agent as optional improvement, not a blocking fix.

---

## Gate 4: Hallucination

### What it checks
- Does every imported module actually exist?
- Does every function/method call match the library's actual API (name, parameters, return type)?
- Are the parameter signatures correct (order, types, optional params)?
- Is the API from the correct version of the library?
- Are there any plausible-but-fabricated constructs?

### How to check (with opensrc)

**The critical rule:** verify against source, not memory. Libraries change. `opensrc` is the verification engine.

#### The verification workflow

```bash
# 1. Fetch the package source (if not already cached)
opensrc fetch npm:package-name    # npm
opensrc fetch pypi:package-name   # PyPI
opensrc fetch owner/repo          # GitHub

# 2. Get the local path
opensrc path npm:package-name

# 3. Verify the specific API
# Check if an export exists:
grep -r "export.*functionName" $(opensrc path npm:package-name)

# Check if a method exists on a class/object:
grep -r "methodName" $(opensrc path npm:package-name)/src/

# Check the actual parameter signature:
read $(opensrc path npm:package-name)/src/module.ts
```

#### What to verify, by category

| Category | What the agent often gets wrong | How to verify |
|----------|-------------------------------|---------------|
| **ORM queries** | `prisma.user.findByEmail()` (doesn't exist) | `grep -r "findByEmail" $(opensrc path npm:prisma)` — if no results, it's fabricated. Correct: `findUnique({ where: { email } })` |
| **React hooks** | `useDebouncedQuery` (not a real TanStack hook) | `grep -r "export.*use[A-Z]" $(opensrc path npm:@tanstack/react-query)/src/` |
| **UI components** | Wrong prop names (`<Button variant="primary" />` doesn't exist) | Read the component's type definition |
| **Date libraries** | `dayjs().toISOString()` (dayjs uses `.toISOString()` but the format might differ) | `grep -r "toISOString" $(opensrc path npm:dayjs)/src/` |
| **Framework APIs** | `next/navigation` vs `next/router` — using the wrong one for the Next.js version | Check the actual exports in the installed version |
| **Node.js built-ins** | Using `fs/promises` API with callback-style code | Read the actual module source or docs |

#### When opensrc isn't available (interviews, code review without terminal)

If you can't run `opensrc`, fall back to:
1. **Mental verification:** Do you know this API exists? If not, flag it.
2. **Pattern matching:** Does this look like the library's naming convention? Prisma uses `findUnique`, not `findByEmail`. TanStack uses `useQuery`, not `useFetchData`.
3. **Flag uncertain:** "I'm not certain this API exists — it doesn't match the library's naming patterns. Verify before accepting."

Never accept an API call you can't verify. Gate 4's default posture is **skepticism** — assume hallucination until proven real.

### Failure modes
| Failure | Example | Feedback |
|---------|---------|----------|
| Fabricated method | `prisma.user.findByEmail()` | "`findByEmail` doesn't exist on Prisma client. Use `findUnique({ where: { email } })` on line 18." |
| Fabricated import | `import { useDebouncedQuery } from '@tanstack/react-query'` | "`useDebouncedQuery` is not exported from `@tanstack/react-query`. No such hook exists." |
| Wrong parameters | `array.slice(5)` when API is `array.slice(start, end)` | "`.slice()` takes two arguments: `slice(start, end)`. Missing second argument on line 27." |
| Version drift | `node-fetch v3` API used with `require()` (CommonJS) | "`node-fetch v3` is ESM-only. `require()` will fail. Use `import` or downgrade to v2." |
| Plausible wrong logic | Function `encrypt()` uses `crypto.createHash('sha256')` — that's hashing, not encrypting | "Line 42 uses SHA-256 hashing but the function is named `encrypt`. Hashing is one-way — you can't decrypt it. Use `crypto.createCipheriv()` for actual encryption." |

### This is the gate with no owner
`/tdd` won't catch `prisma.user.findByEmail()` — it only runs the code, and a fabricated method throws at runtime. `/code-review` might miss it because it looks plausible. This gate exists specifically to catch what the other skills can't.

### When in doubt, verify with opensrc

Before flagging something as hallucination, verify the actual API using `opensrc`. Don't guess based on memory — libraries change, and your memory of an API from v2 might not match v4. The verification workflow above takes ~30 seconds and turns Gate 4 from a judgment call into a verifiable fact.
