---
name: Balance Data Layer GDD review state
description: Current review status, pass history, and open issues for the Balance Data Layer GDD adversarial review cycle
type: project
---

The Balance Data Layer GDD has completed 11 full review passes.

**Why:** This is the Foundation-layer system that all 8 gameplay systems depend on; quality gates here are critical before any consumer GDD is authored.

**How to apply:** When continuing review work, start from pass 11 verdict. Do not re-raise issues marked RESOLVED below.

## Pass 11 Verdict

### BLOCKER (must fix before stories close)

**B-1 — AC-011b and AC-011c `_is_debug = false` injection missing** (carried from pass 9, NOT applied in pass 10)
- AC-011b (line 813) and AC-011c (line 816) do not inject `_is_debug = false`.
- Without it, if any fixture mis-configuration triggers a different validation error branch, the debug `assert(false)` terminates the GdUnit4 runner silently.
- Fix: add `AND _is_debug = false injected` to the GIVEN clause of both AC-011b and AC-011c.

**B-2 — AC-043 `_load_resource` seam undeclared; unit test is unimplementable** (carried from pass 9 R-6)
- `ResourceLoader` is an engine singleton; GdUnit4 cannot mock it.
- "mock ResourceLoader fixture" in the implementation note refers to a non-existent seam.
- Fix Option A: declare `_load_resource: Callable` injection seam in C.1.4, then test uses the seam.
- Fix Option B: downgrade AC-043 to manual smoke check / ADVISORY gate; remove unit test claim.

**B-3 — AC-029 and AC-029b bare `&"key" == value` form (missing `result[]` wrapper)** (carried from pass 9 R-1)
- AC-029 THEN: `&"hp_mult" == wave_entries[0].hp_mult` — not a valid assertion expression.
- AC-029b THEN: same pattern for multiple fields.
- Fix: replace all bare `&"key" == value` with `result[&"key"] == value` per AC-041 canonical form.

**B-4 — AC-026 uses undefined variable `effective_hp_mult`** (carried from pass 9 R-2)
- AC-026 THEN: `effective_hp_mult == wave_entries[9].hp_mult` — `effective_hp_mult` is not defined in test scope.
- The formula returns a Dictionary; the correct form is `result[&"hp_mult"]`.
- Fix: replace `effective_hp_mult` with `result[&"hp_mult"]` and `loop_count == 0` with `result[&"loop_count"] == 0`.

### RECOMMENDED (address before Foundation milestone)

- **R-1 — AC-054 message substring under-specified**: THEN says "naming the path and actual class" but gives no pinned substring. Test author must guess. Fix: pin a concrete substring format (e.g., "message containing the path string and the class name as returned by get_class()").
- **R-2 — AC-054 fixture construction unspecified**: Does the unit test use a real wrong-class .tres file or a `_load_resource` seam? Leaving this ambiguous leads to non-isolated tests.
- **R-3 — H.2 isolation preamble missing**: No file-level `before_each` reset mandate in `test_validator_rules.gd`. AC-011b/011c and AC-051a/b/d all assert on stub call counts. Without a preamble, new tests added to the file may omit resets, producing false passes. Fix: add preamble analogous to H.3's isolation language.

## Resolved issues (do not re-raise)

- Pass 10 Fix 1: AC-054 `_warning_reporter` injection seam added (line 983) — RESOLVED (injection seam present; message content still under-specified per R-1 above)
- Pass 10 Fix 2: RELOADING→READY prose routing fix (line 331) — RESOLVED
- Pass 10 Fix 3: AC-011b message substring pin `"is_boss: true with spawn_count"` (line 813) — RESOLVED
- Pass 8/9: C.1.6 "Failure mode" now correctly says `_error_reporter.call()` — RESOLVED
- Pass 8/9: AC-011c phrasing "is_ready reaches true" — RESOLVED

## Key structural facts

- GDD file: `design/gdd/balance-data-layer.md`
- Review log: `design/gdd/reviews/balance-data-layer-review-log.md`
- Reporter routing contract is the architectural spine for testability — all ACs that test error/warning behavior depend on `_error_reporter` / `_warning_reporter` injection seams declared in C.1.4
- AC numbering is stable across revisions (policy from pass log)
- The `result[&"key"]` subscript pattern (not `result.key` or `result["key"]`) is required for all dict return assertions in wave loop ACs — AC-041 is the canonical correct example
- H.3 has an isolation preamble; H.2 does not (yet) — this is R-3 above
- AC-043 has been an unresolvable unit test since pass 9; resolution requires either a seam declaration or a category downgrade
