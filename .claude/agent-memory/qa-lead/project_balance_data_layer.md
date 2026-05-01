---
name: Balance Data Layer GDD review state
description: Current review status, pass history, and open issues for the Balance Data Layer GDD adversarial review cycle
type: project
---

The Balance Data Layer GDD has completed 7 full review passes (pass 1–7) and a pass 8 diff review focused on testability and AC correctness. All 10 pass-7 blockers were applied in-session.

**Why:** This is the Foundation-layer system that all 8 gameplay systems depend on; quality gates here are critical before any consumer GDD is authored.

**How to apply:** When continuing review work, start from pass 8 verdict. Do not re-raise issues that were VERIFIED in pass 8. Focus next pass on the 3 remaining blockers below.

## Pass 8 Blockers (not yet fixed — require pass 9)

1. **AC-011c missing `_is_debug = false` injection** — debug `assert(false)` in the validator will crash the GdUnit4 CI runner. Every other validation-failure AC (018, 051c, 011b's contrast note) injects `_is_debug = false`. Fix: add "AND `_is_debug = false` injected" to AC-011c's GIVEN clause AND to its implementation note.

2. **C.1.6 vs C.1.4 contradiction** — C.1.6 "Failure mode" says "Debug builds: `push_error()` per violation" but C.1.4 routing contract says direct `push_error()` is FORBIDDEN. An implementer following C.1.6 literally bypasses `_error_reporter`, breaking AC-009a, AC-011c, AC-018 and others that check reporter call counts. Fix: change C.1.6 to say `_error_reporter.call(msg)` per violation.

3. **AC-011c phrasing error** — "is_ready does not reach `true` for this curve's family." `is_ready` is a single bool on BalanceDatabase; there is no per-family variant. The phrase is semantically incoherent and untestable. Fix: rewrite as "if this curve is the only loaded Resource, `is_ready` remains `false` (release path — requires `_is_debug = false` injection)" or simply "the curve is excluded from `_templates`."

## Pass 8 Recommended (address before Foundation milestone)

- AC-029b: state concrete `w = 20` for the standard fixture (loop_after_wave=9, loop_span=10)
- AC-001: add `balance_load_failed` NOT-fired assertion for happy-path boot (deferred from pass 6 R6; escalation candidate to BLOCKER)
- AC-019: specify which three rules the fixture violates (deferred from pass 5)

## Pass 8 Advisory

- AC-011b GIVEN clause: also inject `_error_reporter` stub (needed to assert count == 0)
- AC-029b: state expected `loop_count == 2` explicitly
- AC-011c: optionally assert wave index appears in the error message

## Key structural facts

- GDD file: `design/gdd/balance-data-layer.md`
- Review log: `design/gdd/reviews/balance-data-layer-review-log.md`
- All 10 pass-7 fixes verified as applied in the document
- Reporter routing contract is the architectural spine for testability — all ACs that test error/warning behavior depend on `_error_reporter` / `_warning_reporter` injection seams declared in C.1.4
- AC numbering is stable across revisions (policy from pass log)
