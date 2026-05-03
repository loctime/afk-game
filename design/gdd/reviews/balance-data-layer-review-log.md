# Review Log — balance-data-layer.md

## Review — 2026-05-02 (pass 11) — Verdict: NEEDS REVISION (4 blockers applied in-session; awaiting fresh-session pass 12)
Scope signal: S (all fixes are targeted text edits + one seam addition to C.1.4; no schema or architecture changes)
Specialists: godot-gdscript-specialist, qa-lead, systems-designer, game-designer, creative-director (senior synthesis)
Blocking items: 4 (all applied in-session) | Recommended: 5 (all applied in-session) | Advisory: 3 (deferred)
Prior verdict resolved: Yes — pass-10's 3 in-session fixes all confirmed held under fresh-session re-read.

Summary: Pass-11 fresh-session re-review. Architecture stable; all pass-10 fixes confirmed held. Four new blockers surfaced by implementation-contract specialists. Root cause: two routing-contract prose gaps (lines 226 and 447 described `push_error` where `_error_reporter.call()` is required) and two AC notation bugs (AC-026/029/029b used `effective_hp_mult` / `&"key" == value` instead of `result[&"key"]` subscript form; AC-043 claimed "mock ResourceLoader fixture" which is an engine singleton with no mock point). All four fixed in-session. Five recommended items also applied: status header updated, `PackedStringArray` rationale comment added, `duplicate(true)` deprecation hardened, AC-011b/011c `_is_debug` notes added, H.2 isolation preamble added. Three advisory items deferred.

### Blockers applied (4)
1. **Line 447 "MUST use `push_error`" → "MUST invoke `_error_reporter.call()`"** (godot-gdscript-specialist, confirmed creative-director BLOCKER) — normative prose under "Mandatory implementation guards" prescribed direct `push_error()` which violates C.1.4 routing contract and makes guards untestable. Also fixed line 515 "Why" paragraph for consistency.
2. **Line 226 miss contract incomplete** (godot-gdscript-specialist, confirmed creative-director BLOCKER) — debug-build miss contract prose only mentioned `assert(result != null)`, omitting the mandatory `_error_reporter.call()` that must precede it. AC-031 required both; prose only specified one; implementer would write non-routing code.
3. **AC-043 "mock ResourceLoader fixture" → `_load_resource: Callable` seam** (qa-lead, confirmed creative-director BLOCKER) — `ResourceLoader` is an engine singleton with no injection point; unit test was literally unimplementable. Added `_load_resource: Callable` to C.1.4 seam table with routing-contract comment; AC-043 rewritten against the new seam. Pass-10's R7 deferral was wrong — escalated correctly.
4. **AC-026/AC-029/AC-029b notation `&"key" == value` / `effective_hp_mult ==`** (qa-lead, confirmed creative-director BLOCKER) — `StringName == float` comparison always returns `false`; `effective_hp_mult` is undefined in test scope when formula returns a Dictionary. Silent vacuous-pass risk. All three ACs rewritten to use `result[&"key"]` subscript form matching AC-041.

### Recommended applied (5)
1. PackedStringArray rationale comment: Array[String].join() does not exist in GDScript 4.x.
2. `duplicate(true)` language: "still functions" → "deprecated as of 4.5, must not appear in 4.6 code."
3. AC-011b + AC-011c: added note that `_is_debug` injection is NOT required (warning-only paths, no assert branch reachable).
4. H.2 isolation preamble: added test-isolation requirement matching H.3's pattern.
5. Status header: updated to pass 11 / 2026-05-02.

### Recommended deferred (7)
R1: AC-029/029b/026 subscript — resolved (applied as B-4). R2: AC-011b game-concept.md §5.3 citation. R5: G.2 loop_after_wave=0 row clarification. R7: AC-043 seam — resolved (applied as B-3). R8: D.2 boss formula pointer. R10: AC-011c _is_debug note — resolved (applied in recommended). Remaining deferred: R2, R5, R8.

### Advisory deferred (3)
A1: C.1.4 PackedStringArray rationale — resolved (applied). Remaining: A2 (D.1 SCOPE REQUIREMENT `e` comment), A3 (Player Fantasy numeric vs structural authoring distinction).

---

## Review — 2026-05-02 (pass 10) — Verdict: NEEDS REVISION (2 blockers + R3 recommended applied in-session, awaiting fresh-session pass 11)
Scope signal: S (all fixes are targeted text edits; no schema or architecture changes)
Specialists: godot-gdscript-specialist, systems-designer, qa-lead, game-designer, creative-director (senior synthesis)
Blocking items: 2 (both applied in-session) | Recommended: 1 also applied (R3) | Advisory: 2
Prior verdict resolved: Yes — pass-9's 3 blockers confirmed held after fresh-session inspection.

Summary: Pass-10 fresh-session re-review. Architecture stable; all pass-9 blockers confirmed held. Two new blockers surfaced (same root cause: routing contract propagation incomplete after prior in-session fixes). (1) State machine Transitions prose RELOADING→READY(with errors) still said "push errors to the Output panel" — the pass-9 fix updated the state machine TABLE cells but not the Transitions prose at line 331; directly contradicts C.1.4 routing contract. Fixed: "route errors through `_error_reporter`". (2) AC-054 (unrecognized-class skip) had no `_warning_reporter` injection seam — all 7 other warning-path ACs specify injection; AC-054 was in the CI BLOCKING GATES list but untestable as written. Fixed: added injection + test note. R3 (AC-011b message content — no required substring, asymmetric with AC-011c) applied as recommended: added `"is_boss: true with spawn_count"` substring pin. Seven recommended and two advisory items deferred.

### Blockers applied (2)
1. **RELOADING→READY transition "push errors to the Output panel" → "route errors through `_error_reporter`"** (godot-gdscript-specialist + systems-designer + qa-lead, confirmed creative-director) — routing contract violation; state machine table was fixed in pass 9 but prose was not; would cause implementer to bypass injection seam for hot-reload error path.
2. **AC-054 missing `_warning_reporter` injection** (godot-gdscript-specialist + qa-lead, confirmed creative-director) — only warning-path AC without an injection seam; listed in CI BLOCKING GATES but untestable as written; added injection language matching AC-051a/b/d pattern.

### Recommended applied (1)
R3: AC-011b `_warning_reporter` message content had no required substring — asymmetric with AC-011c which pins `"boss with zero spawn count"`. Added `"is_boss: true with spawn_count"` substring pin.

### Recommended deferred (7)
R1: AC-029/029b/026 dict subscript form `result[&"hp_mult"]` missing. R2: AC-011b warning message lacks `(see game-concept.md §5.3)` citation. R5: G.2 loop_after_wave=0 row "Loop starts immediately" misleading (wave 0 is unscaled). R6: H.2 lacks test isolation preamble. R7: AC-043 "mock ResourceLoader fixture" ambiguous. R8: D.2 missing boss stat scaling row. R10: AC-011c lacks explicit note that no `_is_debug = false` needed.

### Advisory deferred (2)
A1: C.1.4 `PackedStringArray(_validation_errors).join("\n")` rationale gap. A2: D.1 SCOPE REQUIREMENT comment `e` default ambiguity.

---

## Review — 2026-05-09 (pass 9) — Verdict: NEEDS REVISION (3 blockers applied in-session, awaiting fresh-session pass 10)
Scope signal: S (all fixes are targeted text edits; no schema or architecture changes)
Specialists: godot-gdscript-specialist, qa-lead, systems-designer, game-designer, creative-director (senior synthesis)
Blocking items: 3 (all applied in-session) | Recommended: 10 | Advisory: 2
Prior verdict resolved: Yes — pass-8's 8 blockers confirmed held after fresh-session inspection. Plus one pre-review fix applied: C.1.4 Miss contract `push_error(...)` → `_error_reporter.call(...)`.

Summary: Pass-9 targeted fresh-session review. Architecture stable; all pass-8 blockers confirmed held. Three new blockers surfaced and all resolved in-session — all instances of the same root cause: routing contract propagation incomplete after the pass-9 entry fix. (1) D.1 representative output scale table "Loops" column systematically off by −1 (`loop_count − 1` throughout), with HP mult values computed against the wrong exponent; directly contradicted AC-022. Corrected all 6 rows. (2) State machine table "Getter behavior" column used colloquial "pushes error" for UNLOADED/LOADING/VALIDATING/FAILED states — replaced with `routes through _error_reporter` per routing contract. (3) E.4 prose "release returns null + push_error" — replaced with `routes through _error_reporter`. Ten recommended and two advisory items deferred.

### Blockers applied (3)
1. **D.1 representative table Loops off-by-one** (systems-designer, confirmed creative-director) — "Loops" column used `loop_count − 1`; HP mult values used wrong exponent; contradicted AC-022. Corrected: Loops 4→5, 9→10, 19→20, 49→50, 99→100; HP mult ≈3.5→4.0, ≈7.1→8.1, ≈32→32.7, ≈930→2,200, ≈8.6×10⁵→2.35×10⁶.
2. **State machine table "pushes error" → `routes through _error_reporter`** (godot-gdscript-specialist, creative-director BLOCKER) — four getter-behavior cells (UNLOADED, LOADING, VALIDATING, FAILED) used ambiguous "pushes error"; routing contract mandates `_error_reporter`; would cause implementer to bypass injection seam.
3. **E.4 prose "push_error" → `routes through _error_reporter`** (godot-gdscript-specialist, creative-director BLOCKER) — normative prose describing production code path used forbidden direct call; AC-044 was correct but E.4 would mislead implementer.

### Recommended deferred (10)
R1: AC-029/029b/026 dict subscript form `result[&"hp_mult"]` missing (match AC-041 form). R2: AC-011b spawn_count > 1 warning lacks `(see game-concept.md §5.3)` citation — asymmetric with spawn_count == 0 warning. R3: AC-011b message content assertion has no required substring (AC-011c pins "boss with zero spawn count"). R4: AC-054 THEN clause has no `_warning_reporter` injection — "warning is logged" untestable without seam. R5: G.2 loop_after_wave = 0 row — "Loop starts immediately" misleading; wave 0 is unscaled. R6: H.2 lacks file-level test isolation preamble (H.3 has one). R7: AC-043 "mock ResourceLoader fixture" ambiguous — clarify as filesystem fixture (real .tres with mismatched resource_path). R8: D.2 missing boss-specific stat scaling row pointing to Wave & Phase Manager. R9: RELOADING → READY transition "push errors to the Output panel" should say `_error_reporter.call()`. R10: AC-011c `_error_reporter` stub missing "reset in before_each" + note clarifying no `_is_debug = false` needed (WARNING-only path).

### Advisory deferred (2)
A1: C.1.4 `PackedStringArray(_validation_errors).join("\n")` — incorrect rationale removed in pass 8 but no replacement explanation added; code is correct but unexplained. A2: D.1 SCOPE REQUIREMENT comment — INF guard unreachable on no-loop branch in practice; comment labels e's default as "pre-loop path safe default" which is ambiguous.

---

## Review — 2026-05-01 (pass 8) — Verdict: NEEDS REVISION (8 blockers applied in-session, awaiting fresh-session pass 9)
Scope signal: S (all fixes are targeted text edits; no schema or architecture changes)
Specialists: godot-gdscript-specialist, qa-lead, game-designer, systems-designer, creative-director (senior synthesis)
Blocking items: 8 (all applied in-session) | Recommended: 5 (deferred) | Nice-to-have: 3
Prior verdict resolved: No — pass-7's 10 fixes held; 8 new blockers surfaced from contract-drift and phantom-API patterns.

Summary: Fresh-session pass-8 targeted diff review. Architecture confirmed stable. Three repeating failure-mode patterns diagnosed across 8 passes: (1) contract drift between sections, (2) ACs referencing seams not declared in C.1.4, (3) foundation-layer overreach into unwritten downstream systems. Key fixes: (1) C.1.6 "Failure mode" still said `push_error()` per violation — contradicted C.1.4 routing contract; changed to `_error_reporter.call()`. (2) AC-011c (added pass 7) missing `_is_debug = false` injection — obsoleted by pass-8 Fix #6 downgrade. (3) AC-011c "is_ready for this curve's family" referenced non-existent per-family API — rewritten to use `_templates` membership. (4) D.1 INF guard referenced `e` computed only inside looping branch — SCOPE REQUIREMENT block added specifying function-scope `var e` and `var loop_count` with safe defaults before branching. (5) OQ-1 "C++ path" claim factually incorrect — `ResourceLoader.CacheMode.IGNORE` is valid GDScript 4.x; rationale rewritten to "flat-namespace is idiomatic GDScript style." (6) is_boss spawn_count==0 FAIL downgraded to WARNING — foundation layer must not encode constraints of unwritten downstream GDDs; WARNING message now cites game-concept.md §5.3; AC-011c rewritten to test warning behavior; coverage table updated. (7) AC-001 missing complement — AC-001b added: balance_load_failed must NOT fire on clean load. (8) `_validation_errors: Array[String]` not declared in C.1.4 seam block — added with reset-on-validation note.

### Blockers applied (8)
1. **C.1.6 Failure mode `push_error()` → `_error_reporter.call()`** (godot-gdscript-specialist) — routing contract violation; would bypass injection seams for 8 ACs.
2. **AC-011c _is_debug injection** (godot-gdscript-specialist) — obsoleted by Fix #6 (downgrade eliminated assert(false) path); Fix #3 resolves the phantom-API half.
3. **AC-011c "is_ready for this curve's family" phantom API** (qa-lead) — rewritten to "`_templates` membership + is_ready may still reach true."
4. **D.1 INF guard `var e` scope** (systems-designer) — SCOPE REQUIREMENT block added before branching; specifies `var e: int = wave_entries.size() - 1` and `var loop_count: int = 0` at function scope.
5. **OQ-1 "C++ path" false claim** (systems-designer + godot-gdscript-specialist, dual convergence) — rationale corrected; nested enum access is valid GDScript 4.x.
6. **is_boss spawn_count==0 FAIL → WARNING** (game-designer, creative-director upheld) — foundation overreach; downgraded; AC-011c rewritten; C.1.6 Rule 7 and coverage table updated.
7. **AC-001b complement** (qa-lead + creative-director) — balance_load_failed NOT-fire on clean load; added to H.1.
8. **`_validation_errors` not in C.1.4 seams** (systems-designer + creative-director) — added with declaration and reset-on-validation note.

### Recommended (5 deferred to pass 9 or advisory)
Pass-7 fix #3 rationale incorrect (Array[String].join() does exist); AC-029 subscript omission; test_validator_rules.gd isolation preamble; G.2 loop_after_wave=0 row ambiguity; is_boss spawn_count>1 WARNING should cite game-concept.md §5.3.

---

## Review — 2026-04-20 (pass 7) — Verdict: NEEDS REVISION (10 blockers applied in-session, awaiting fresh-session pass 8)
Scope signal: S (all fixes are targeted text edits; ~60–90 min; no architectural change)
Specialists: game-designer, systems-designer, qa-lead, godot-gdscript-specialist, creative-director (senior synthesis)
Blocking items: 10 (all applied) | Recommended: 7 (all applied as advisory) | Nice-to-have: 0
Prior verdict resolved: Yes — pass-6's 6 blockers confirmed held after fresh-session inspection.

Summary: Fresh-session pass-7 re-review of pass-6 revisions. Architecture confirmed stable; all pass-6 blockers held. 10 new blockers surfaced and all resolved in-session. Key fixes: (1) Dict literal syntax revert — pass-6's "canonical form" `{ key = value }` is not safe GDScript 4.x dict literal syntax; reverted to `{ &"key": value }` StringName-keyed colon form throughout D.1 guard returns, E.1 fallback, and AC-041; also adds immediacy-of-return contract to AC-041. (2) D.1 `push_error()` bypass — four direct `push_error()` calls in the guard block contradicted C.1.4's reporter routing contract; replaced with `_error_reporter.call()`; AC-029 and AC-029b rewritten to specify `_error_reporter` injection; AC-029/AC-029b added to C.1.4 contract's AC list. (3) `Array[String].join()` fix — typed `Array[String]` has no `.join()` method in GDScript 4.x; changed to `PackedStringArray(_validation_errors).join("\n")`. (4) LOCAL VARIABLE REQUIREMENT note scoped to scales only — removed erroneous `wave_entries` local-copy instruction; reading Resource fields is safe; only scale reassignment needs a local guard. (5) `is_boss: true AND spawn_count == 0` — escalated from deferred recommended to blocker; Rule 7 now fails (not warns) on this state; new AC-011c added; H.2 table + H.8 blocking gates paragraph updated. (6) AC-029/AC-029b reporter update (covered above). (7) AC-009a injection spec — added `_error_reporter` injection requirement to make the message-content assertion testable. (8) H.8 blocking gates paragraph — AC-011b added by name (was present in table but not summary paragraph); AC-011c also added. (9) Test isolation clause — H.3 now has an explicit per-test reset requirement for `_warned_no_loop_curves` and reporter stubs; AC-011b fixture constrained to exactly one violating entry; AC-053 adds same-curve-id constraint. (10) `_warned_no_loop_curves` static typing — `Dictionary` → `Dictionary[StringName, bool]`. Advisory: guard ordering in D.1 (empty check before w<0), output range ≥ 0.0, duplicate() claim softened, G.2 spawn_count non-scaling note, AC-051d _warning_reporter routing, AC-053 instance-identity constraint.

### Blockers applied (10)
1. **Dict literal syntax (D.1, E.1, AC-041)** (godot-gdscript + qa-lead, creative-director adjudicated) — `{ key = value }` not safe in GDScript 4.x; reverted to `{ &"key": value }` StringName-keyed form throughout.
2. **D.1 `push_error()` bypass × 4** (systems-designer + qa-lead + godot-gdscript, 3-specialist convergence) — four direct `push_error()` calls replaced with `_error_reporter.call()`.
3. **`PackedStringArray().join()`** (systems-designer + godot-gdscript) — `Array[String].join()` absent in GDScript 4.x; fixed.
4. **LOCAL VARIABLE note scoped to scales** (systems-designer + godot-gdscript) — removed `wave_entries` instruction; only scale mutation needs local copy.
5. **`is_boss + spawn_count == 0` validator FAIL + AC-011c** (game-designer + systems-designer) — escalated from deferred recommended; Rule 7 extended; AC-011c added; H.2 + H.8 updated.
6. **AC-029 / AC-029b reporter injection** (qa-lead) — "push_error is called" language removed; `_error_reporter` injection specified.
7. **AC-009a injection spec** (qa-lead) — `_error_reporter` injection + message-content assertion added.
8. **H.8 blocking gates paragraph — AC-011b + AC-011c by number** (qa-lead) — summary paragraph now matches table.
9. **Test isolation clause H.3 + AC-011b fixture + AC-053 constraint** (game-designer + qa-lead, folded) — per-test reset required; AC-011b fixture = exactly one violating entry; AC-053 = same instance + same curve id.
10. **`Dictionary[StringName, bool]`** (godot-gdscript) — static typing enforced.

### Advisory applied (7)
Guard ordering in D.1 (empty check before w<0); output range `≥ 0.0`; duplicate() claim softened; G.2 spawn_count non-scaling note; AC-051d `_warning_reporter` routing; AC-053 same-curve-id constraint; AC-041 immediate-return contract sentence.

---

## Review — 2026-04-20 (pass 6) — Verdict: NEEDS REVISION (6 blockers applied in-session, awaiting fresh-session pass 7)
Scope signal: S (all fixes are targeted text edits; ~45–60 min; no schema or architecture changes)
Specialists: game-designer, systems-designer, qa-lead, godot-gdscript-specialist, creative-director (senior synthesis)
Blocking items: 6 (all applied) | Recommended: 10 (deferred) | Nice-to-have: 3 (deferred)

Summary: Fresh-session pass-6 re-review of pass-5 revisions. Architecture confirmed stable; all pass-5 blockers held. 6 new blockers surfaced and all resolved in-session. Key fixes: (1) D.1 guard pseudocode: added explicit LOCAL VARIABLE REQUIREMENT note before the `loop_hp_scale`/`loop_dmg_scale` guards — implementers must not write back to the WaveScalingCurve Resource template (C.1.5 immutability contract). (2) Dict literal key syntax: E.1 and AC-041 used colon syntax `{ hp_mult: 1.0, ... }` (GDScript String keys) while D.1 used assignment syntax `{ hp_mult = 1.0, ... }` (correct form); canonicalized to assignment form throughout — a consumer doing `result[&"loop_count"]` against the colon form would silently get null, defeating the pass-5 3-field-return fix. (3) `_warned_no_loop_curves: Dictionary` uncommented from comment block in C.1.4 — the field was the only C.1.4 declaration inside a `#` comment while `_is_debug`, `_error_reporter`, `_warning_reporter` were live declarations; AC-053 depends on this field being implemented. (4) Reporter routing contract added to C.1.4: explicit statement that ALL warning output routes through `_warning_reporter` and ALL error output routes through `_error_reporter`; direct `push_warning()`/`push_error()` calls in production code paths are forbidden — without this, any implementer calling `push_warning()` directly bypasses the seam that AC-026/051a/b/053 depend on; AC-041 updated to specify `_error_reporter` injection. (5) AC-011b added covering `is_boss: true AND spawn_count > 1` warning path (Rule 7) — this warning branch was added as pass-5 blocker fix #5 but no AC was created for it; the fix was incomplete without test coverage; AC-011b, H.2 blocking gates, and H.8 table all updated. (6) Two documentation-integrity fixes: (a) C.1.4 pseudocode `"\n".join(_validation_errors)` was Python syntax — corrected to GDScript `_validation_errors.join("\n")`; (b) H.8 coverage gate relabeled "Advisory — OQ-9" because the standard GdUnit4 CLI cannot produce line coverage reports without additional tooling; a false mandatory gate was removed; OQ-9 added to Open Questions.

Prior verdict resolved: Yes — pass-5's 7 blockers confirmed held after fresh-session inspection.

### Blockers applied (6)
1. **D.1 LOCAL VARIABLE REQUIREMENT** (systems-designer + godot-gdscript-specialist) — `loop_hp_scale = 1.0` guard reassigns a local copy; writing back to the WaveScalingCurve field would corrupt the never-duplicated template. Note added before guard block.
2. **Dict literal key syntax E.1 / AC-041** (systems-designer) — colon syntax creates String keys; assignment syntax creates correct keys matching D.1 canonical signature. Both locations changed to `{ hp_mult = 1.0, dmg_mult = 1.0, loop_count = 0 }`.
3. **`_warned_no_loop_curves` uncommented** (systems-designer) — moved from `# var` comment to live `var` declaration in C.1.4, matching peer fields `_is_debug`/`_error_reporter`/`_warning_reporter`.
4. **Reporter routing contract + AC-041 seam** (systems-designer + qa-lead) — added contract paragraph to C.1.4; updated AC-041 to specify `_error_reporter` injection and stub-count assertion.
5. **AC-011b — is_boss warning AC** (qa-lead + systems-designer) — new AC covering `is_boss: true AND spawn_count > 1` warning; H.2 blocking gates and H.8 table updated; completes pass-5 blocker fix #5.
6. **Python syntax + coverage gate** (godot-gdscript-specialist) — `_validation_errors.join("\n")` in C.1.4; H.8 coverage gate relabeled advisory with OQ-9 added.

### Recommended deferred (10)
R1: AC-041/009a/042/054 `_error_reporter` injection not stated; R2: D.1 output range `> 0.0` → `≥ 0.0` (f64 underflow); R3: OQ-1 `CacheMode.IGNORE` false "C++ path" claim; R4: E.3 `resource_local_to_scene` failure description; R5: C.1.5 `duplicate(true)` "emits engine warning" false; R6: AC-001 `balance_load_failed` NOT-fire clause; R7: AC-019 fixture three-rule spec; R8: `spawn_count` loop non-scaling documented in G.2; R9: `is_boss: true AND spawn_count == 0` → validator fail; R10: `is_boss` authoring notes (cadence + Common Mistakes).

---

## Review — 2026-04-20 (pass 5) — Verdict: NEEDS REVISION (7 blockers applied in-session, awaiting fresh-session pass 6)
Scope signal: S (all fixes are targeted text edits; ~2 hours; no architectural rework — wave entry `is_boss` field is the only schema addition)
Specialists: game-designer, systems-designer, qa-lead, godot-gdscript-specialist, creative-director (senior synthesis)
Blocking items: 7 (all applied) | Recommended: 10 (deferred) | Nice-to-have: 6 (deferred)

Summary: Fresh-session pass-5 re-review of pass-4 revisions. Architecture confirmed stable; all prior blockers held. 7 new blockers surfaced and all resolved in-session. Key fixes: (1) AC-041 empty-entries guard return extended from 2-field to 3-field dict `{hp_mult, dmg_mult, loop_count:0}` — matching D.1 canonical signature; consumers can safely read `result.loop_count` from all exit paths. (2) C.3 Enemy System contract `Array.map()` → explicit typed `for`-loop — `map()` returns untyped `Array` in GDScript 4.x; direct assignment to `Array[EnemyDefinition]` was a runtime crash on first wave-start. (3) `_warning_reporter: Callable` injection seam added to C.1.4 — mirrors `_error_reporter` pattern; makes AC-026, AC-053, AC-051a, AC-051b fully automatable as blocking tests (previously untestable because `push_warning` cannot be intercepted without a seam). (4) AC-044 `_is_debug = false` injection added — same class of missed fix as AC-002/018/019/031/032 in passes 3-4; without it the debug CI runner would crash. (5) `is_boss: bool = false` added to wave entry required-keys schema + Rule 7 validator — Wave & Phase Manager cannot data-drive boss-gate detection at all without this; hardcoding `wave % 9 == 0` in GDScript would break the designer-tunable pillar. (6) OQ-1 resolved inline — `docs/engine-reference/godot/modules/core.md` cited by OQ-1 did not exist; resolution inlined: `ResourceLoader.CACHE_MODE_IGNORE` (flat namespace) is correct; `CACHE_MODE_IGNORE_DEEP` not needed because C.1.5 prohibits nested sub-resources in Balance Resources; one-time live-editor confirmation required at implementation time. (7) D.1 one-time warning state ownership specified — `BalanceDatabase._warned_no_loop_curves: Dictionary` added to C.1.4 with lifecycle spec; prevents template mutation (templates must not hold mutable session state).

Prior verdict resolved: Yes — pass-4's 5 blockers confirmed held after fresh-session inspection.

### Blockers applied (7)
1. **AC-041 2-field → 3-field return dict** (systems-designer + qa-lead) — empty-entries guard returned `{hp_mult, dmg_mult}` while all other D.1 paths return `{hp_mult, dmg_mult, loop_count}`. Silent `null` for `loop_count` in any consumer. Fixed in E.1 and AC-041.
2. **Array.map() type error in C.3 Enemy System contract** (systems-designer + godot-gdscript-specialist) — `var defs: Array[EnemyDefinition] = ids.map(...)` crashes at runtime. Replaced with explicit typed `for`-loop + `defs.append(db.get_enemy(id))` pattern with inline comment explaining why `map()` cannot be used.
3. **`_warning_reporter` injection seam + AC-026/053/051a/b rewrites** (qa-lead) — added `var _warning_reporter: Callable` to C.1.4; rewrote four ACs to assert stub call count and message content rather than relying on uninterceptable `push_warning` output.
4. **AC-044 `_is_debug = false` injection** (qa-lead) — explicit injection added; H.6 blocking-gates note updated.
5. **`is_boss: bool` in wave entry schema** (game-designer + systems-designer, creative-director adjudicated BLOCKER) — added to C.1.1 `WaveScalingCurve.wave_entries` required keys table; added to Rule 7 validator; validator warning if `is_boss: true` AND `spawn_count > 1`.
6. **OQ-1 resolved inline** (godot-gdscript-specialist) — broken file citation removed; resolution inlined with guidance on `CACHE_MODE_IGNORE` vs `CACHE_MODE_IGNORE_DEEP` and one-time live-editor confirmation requirement.
7. **D.1 one-time warning state ownership** (systems-designer) — `BalanceDatabase._warned_no_loop_curves: Dictionary` specified in C.1.4 with key type (StringName curve id) and lifecycle (populated on first out-of-bounds query, never cleared within session).

### Specialist divergences (creative-director resolutions)
- **spawn_count loop scaling as BLOCKER** (game-designer + systems-designer): declined — additive migration path (`loop_spawn_scale: float = 1.0`) is genuine; Wave & Phase Manager GDD owns the feature; deferred as RECOMMENDED with explicit documentation note to avoid future re-escalation.
- **mana_regen_rate as BLOCKER** (game-designer): declined — Combat Engine / Skill System GDD has not determined whether regen lives on CharacterProgressionCurve, SkillDefinition, or its own curve; added as OQ-8 with Combat Engine GDD owner.
- **SkillDefinition target_type/hit_count as BLOCKER** (game-designer): declined — RECOMMENDED for Combat Engine GDD to address; duration_sec stays on effect_tags pending skill taxonomy design.
- **`is_boss` as BLOCKER** (game-designer + systems-designer): CONFIRMED as BLOCKER and applied. Boss cadence is a stated game rule, not speculative; two specialists independently confirmed.

### Recommended deferred (10)
Formula guard `self.loop_hp_scale` mutation risk; `_init()` default claim correction; `resource_local_to_scene` failure description; `duplicate(true)` engine-warning overstatement; GdUnit4 coverage gate tooling setup; AC-019 three-violation fixture underspecified; AC-051d "info message" mechanism (no push_info in GDScript); `balance_load_failed` NOT-fire AC missing; spawn_count no loop scaling (additive migration documented); mana_regen_rate (new OQ-8, Combat Engine GDD owner).

---

## Review — 2026-04-20 (pass 4) — Verdict: NEEDS REVISION (5 blockers applied in-session, awaiting fresh-session pass 5)
Scope signal: S (all fixes are in-session text edits; ~45–75 min; no architectural or schema changes)
Specialists: game-designer, systems-designer, qa-lead, godot-gdscript-specialist, performance-analyst, creative-director (senior synthesis)
Blocking items: 5 (all applied) | Recommended: 8 (deferred) | Nice-to-have: 5 (deferred)

Summary: Full fresh-session pass-4 re-review of pass-3 revisions. Architecture holds; pass-3 fixes verified. 5 new blockers surfaced and all resolved in-session. Key fixes: deprecated `emit_signal("signal_name", ...)` form replaced with typed `signal.emit(arg)` idiom in C.1.8 hot-reload pseudocode (same class as pass-3's `duplicate(true)` sweep); AC-002 rewritten to separate observable-effects automated path (with `_is_debug = false` injection) from debug-assert advisory path (AC-002b) — completing the AC-018/019/031/032 rewrite pattern started in pass 3; new AC-029b added for D.1 INF/NaN overflow guard branch (formula branch 5 — most consequential fallback path, previously untested, threatened 70% coverage gate); Rule 4 extended with `CharacterProgressionCurve.base_stats` structural validator (all 4 keys required with `int` values), Rule 5 extended with `stat_points_per_level >= 0`, new AC-008a added; new AC-009a added for `defense_per_vit > 0` pillar-protection invariant (only Rule 5 sub-check where `= 0` is forbidden — needed a named test). H.8 evidence table and blocking gates list updated for all new ACs. AC-055 added to blocking gates list and H.8 (previously absent).

Prior verdict resolved: Yes — pass-3's 7 blockers confirmed held after fresh-session inspection.

### Blockers applied (5)
1. **`emit_signal("balance_database_reloaded", ok)` → `balance_database_reloaded.emit(ok)`** (godot-gdscript-specialist) — deprecated string-based emit form bypasses compile-time arity checking; GDD self-contradictorily said "Godot 4.6 enforces typed signal arity at runtime" while using the string dispatcher. Fixed in C.1.8. Note added explaining why `.emit()` is required.
2. **AC-002 debug-assert separation** (qa-lead) — same broken pattern as pre-pass-3 AC-018/019/031/032. AC-002 was not fixed when those were. Split into: AC-002 (automated release-path observable effects with `_is_debug = false` injection) + AC-002b (debug-assert advisory manual smoke, same evidence file as AC-031).
3. **AC-029b — D.1 INF/NaN overflow guard branch** (qa-lead) — formula branch 5 (`not is_finite(effective_hp_mult)`) had no AC despite being the most important runtime guard. New AC-029b: fixture with `loop_hp_scale = 1e200`, `loop_dmg_scale = 1e200`, `loop_count = 2`; asserts push_error called + unscaled baseline returned + loop_count preserved.
4. **Rule 4 `base_stats` structural validator + Rule 5 `stat_points_per_level >= 0` + AC-008a** (systems-designer) — `base_stats` Dictionary had no check for all 4 required keys with correct types; partial-key miss causes silent null-arithmetic in Character Stats. Added to Rule 4 with parity note to Rule 10. `stat_points_per_level >= 0` added to Rule 5 (negative value subtracts stat points on level-up). New AC-008a covers both.
5. **AC-009a — `defense_per_vit > 0` pillar-protection invariant** (qa-lead + systems-designer) — the only Rule 5 sub-check where `= 0` is specifically forbidden (all others allow `= 0` or only forbid negative). Named "pillar-protection invariant" across passes 2–3 but lacked a dedicated AC. New AC-009a with explicit error message quoting concept §7.2.

### Recommended deferred (8)
`Array.map()` untyped Array assignment in C.3 Enemy System contract; AC-019 three-violation fixture underspecified; AC-026/AC-053 need `_warning_reporter` injection seam; AC-039 evidence file fields not enumerated; AC-031 dev-console reference should be removed; Rule 5 `loop_hp_scale < 1.0` + `allow_loop_seam = false` E.2 interaction note; `mana_regen_rate` no data home; boss-wave no data representation.

### Specialist divergences (creative-director resolutions)
- **`spawn_count` not loop-scaled as BLOCKER** (game-designer): declined — Wave & Phase Manager GDD owns per G.1; additive migration path open; data layer's job is to not prevent it.
- **`allow_loop_seam` UX as BLOCKER** (game-designer): demoted to RECOMMENDED — default `false` is safe; designer must actively override; polish when real authoring workflows exist.
- **`behavior_tag` magnitude params as BLOCKER** (game-designer): declined — Combat Engine owns global behavior constants; per-enemy variation is future additive field.
- **OQ-1 as review blocker** (godot-gdscript-specialist): declined — gate is `/create-stories` per OQ-1's own target field, not design-review approval.
- **De-escalating `loop_hp_scale` + `allow_loop_seam = false` contradiction** (systems-designer): declined — spec is coherent; Rule 12 correctly fires for any difficulty drop; `allow_loop_seam = true` is the documented override; one-sentence clarification in E.2 deferred to recommended.

### Nice-to-have deferred (5)
`allow_loop_seam` absent from G.2 tuning table; `push_warning()` vs `push_error()` consistency in advisory paths; Rule 9 `xp_per_level[0] == 0` no dedicated AC; D.1 output table needs player-stat counterpoint; AC-048 and AC-047a should be separate test files.

---

## Review — 2026-04-20 (pass 3) — Verdict: NEEDS REVISION (7 blockers + 8 recommended applied in-session, awaiting fresh-session pass 4)
Scope signal: S (creative-director — all fixes in-session text edits; ~60–90 min; no architectural rework)
Specialists: game-designer, systems-designer, qa-lead, godot-gdscript-specialist, performance-analyst, creative-director (senior synthesis)
Blocking items: 7 (all applied) | Recommended: 8 (all applied) | Nice-to-have: 4 (deferred)

Summary: Fresh-session pass-3 re-review of pass-2 revisions. Architecture holds; pass-2 fixes verified. 7 new blockers surfaced around engine-API drift (deprecated `duplicate(true)` since Godot 4.5), test-contract impossibility (GdUnit4 cannot catch native `assert(false)` — AC-018/019/031/032 overclaimed), and three real spec holes (Rule 12 silent `[-1]` wrap, `Performance.MEMORY_STATIC` wrong monitor, AC-047 "headlessly on Android" impossible). All 7 resolved in-session. 8 recommended items also applied per user decision: provisional AUTHORING_NOTES.md created adjacent to GDD, AC-035 concrete regex pair specified, E.5 schema downgrade path added, `base_stats` StringName fix, `balance_load_failed` consumer guidance, Combat Engine "never direct" contract, new F.2b CharacterProgressionCurve single-archetype constraint, AC-047 ↔ OQ-2 bi-directional link.

Prior verdict resolved: Yes — pass-2's 8 blockers confirmed held after fresh-session inspection (hot-reload sequence, `_validation_errors` accumulator, Rule 12 severity + AC-051 split, autoload #1, defense_per_vit strict, AC-033/035 unified, AC-016 key fix, AC-051 split).

### Blockers applied (7)
1. **`duplicate(true)` → `duplicate_deep()` sweep** (godot-gdscript-specialist) — deprecated in Godot 4.5+; swept 10 call sites across C.1.1, C.1.4, C.1.5, C.3 matrix, C.3 per-consumer contracts, E.4, AC-034, AC-035. Added explicit "4.5+ deep-copy API" callout in C.1.5.
2. **AC-018/019/031/032 test contracts rewritten** (qa-lead + godot-gdscript-specialist) — native GDScript `assert(false)` cannot be caught by GdUnit4 as signal/exception. ACs now test observable effects (validation_errors count, reporter call count, signal emission, is_ready state, null returns). Debug-branch assertions (AC-031, AC-019 debug) demoted to manual smoke-check items with named evidence files (`balance-debug-assert-smoke.md`, `balance-getter-miss-debug-smoke.md`). C.1.4 injection-seam commentary reconciled to match new AC language; "Test coverage boundary" note added.
3. **D.1 formula guards — push_error + fallback, not assert** (systems-designer + godot-gdscript-specialist) — `assert(is_finite)` and `assert(loop_*_scale > 0)` are compile-time directives stripped from release exports; dead code in shipped binary. Replaced with `if not is_finite: push_error + return wave_entries[e] unscaled` (user-chosen fallback: graceful plateau at authored baseline, preserves loop_count for telemetry). `loop_*_scale <= 0` case clamps to 1.0 with push_error.
4. **Rule 12 `loop_after_wave == -1` skip + AC-051e** (systems-designer) — GDScript `wave_entries[-1]` wraps to last element; spec must explicitly skip. Added load-bearing skip clause in C.1.6 Rule 12 + AC-051e coverage. Also added degenerate `loop_after_wave = 0` tuning note (trivially satisfied for `loop_hp_scale >= 1`).
5. **AC-047 methodology split** (performance-analyst + qa-lead) — "headlessly on mid-range Android 2020+" impossible (no Android headless mode in Godot). Split into AC-047a (desktop CI headless, 200ms, blocking) and AC-047b (Pixel 4a pinned as reference, 500ms, advisory). OQ-2 ↔ AC-047b bi-directional link. Substitute Snapdragon 720/730/765 device allowed with evidence-file log.
6. **AC-050 monitor fix** (performance-analyst) — `Performance.MEMORY_STATIC` measures engine-static pools, returns near-zero for Resource dictionary heap; would produce false PASS. Changed to `Performance.MEMORY_DYNAMIC` with monitor-choice rationale paragraph. Required evidence-file fields enumerated (device, Godot version, OS, fixture hash, baseline MB, post MB, delta, pass/fail). QA-lead owner named for creation.
7. **"11 rules" → "12 rules"** (systems-designer) — H.2 header + H.8 row corrected; cross-reference to Rule 12 ACs in H.7b added.

### Recommended applied (8)
1. **Provisional AUTHORING_NOTES.md** (game-designer) — created `design/gdd/balance-data-layer-authoring-notes.md` adjacent to GDD (not embedded, preserving G.1 ownership model). 5-step quick-start + provisional safe ranges per family + common-mistakes list. Cross-References section in GDD points to it.
2. **AC-047 ↔ OQ-2 bi-directional link** (performance-analyst) — 500ms labeled as target-not-verified until AC-047b passes; `.tres → .res` flip noted as schema-transparent.
3. **E.5 schema_version > CURRENT_SCHEMA downgrade bullet** (systems-designer) — migration tool must detect and refuse to run; no auto-downgrade.
4. **`base_stats` StringName key fix** (godot-gdscript-specialist) — `{ &"str": int, ... }` not `{ "str": int, ... }` — matches closed base-stat namespace in C.1.2 and prevents silent Dictionary-lookup mismatches.
5. **`balance_load_failed` consumer guidance** (game-designer) — new subsection in C.3 recommends hard error screen over degraded continue, with rationale grounded in solo-indie AFK context.
6. **Combat Engine "never call BalanceDatabase directly"** (systems-designer) — updated C.3 matrix row + preamble to make the contract explicit (stronger than per-frame lint).
7. **New Section F.2b: CharacterProgressionCurve single-archetype constraint** (game-designer) — explicit Dependency constraint on upstream game-concept; promotes OQ-6 to visible design rule.
8. **AC-035 concrete regex spec** (qa-lead) — replaced the "grep on typed variable" hand-wave with a two-pass heuristic: (1) same-line `.duplicate*` + curve-class-name coarse grep; (2) two-step type-declaration + subsequent-line scan. Known false-negative (inferred types) documented, not concealed.

### Specialist convergences (multiple independent flags on same issue)
- `is_finite` + `loop_*_scale > 0` assert-stripping in release: systems-designer (REC-4) + godot-gdscript-specialist (REC-2) → elevated to BLOCKING per creative-director synthesis.
- AC-018/019/031/032 test-contract impossibility: qa-lead (B1/B2) + godot-gdscript-specialist (B2) → BLOCKING; rewrite to observable effects.
- AC-047 "headlessly on Android": qa-lead (B4) + performance-analyst (B1) → BLOCKING; split into desktop CI + device manual.

### Specialist disagreements (creative-director resolutions)
- **Player Fantasy blocking-or-recommended?** game-designer called the Rule-12/authoring-experience gap BLOCKING; no other specialist. Creative-director: demoted to RECOMMENDED; fix belongs in adjacent AUTHORING_NOTES.md, not inside the data-layer GDD. Applied.
- **`allow_loop_seam` per-curve vs project-setting?** game-designer suggested move to project-setting. Creative-director: accept pass-2 per-curve decision; re-litigating stable choices on pass 3 without new information violates decision stability. Not applied.
- **`duplicate(true)` sweep blocking?** Creative-director: yes, blocking — deprecated API in pinned engine version. Applied.
- **Rule 12 `-1` gap blocking?** Creative-director: yes, blocking but trivial. Applied.

### Nice-to-have deferred (4)
- OQ-1 CACHE_MODE_IGNORE constant-name verification (still open across 3 passes; owner = architecture at first sprint).
- AC-026/AC-053 one-time-warning overlap consolidation.
- 946-line ceremony trim pass (deferred pending 2+ consumer GDDs to validate load-bearing ACs).
- H.8 table rows audit for H.7b AC coverage (partial; pass 4 can confirm completeness).

---

## Review — 2026-04-19 (pass 2) — Verdict: NEEDS REVISION (revisions applied in-session, awaiting fresh-session re-review)
Scope signal: L (unchanged — multi-system foundation hub; 1 formula, 5 Resource families, 12 validator rules, 57 ACs after split, 8 hard downstream dependents)
Specialists: game-designer, systems-designer, qa-lead, godot-gdscript-specialist, creative-director (senior synthesis)
Blocking items: 8 (all applied) | Recommended: 12 (deferred) | Nice-to-have: 4 (deferred)

Summary: Fresh-session re-review of pass-1 revisions. Prior 5 blockers confirmed resolved (slot enum, stat namespace, wave-loop validator, C.1.7 vs E.5 contradiction, test contracts). 8 new/tighter blockers surfaced and all resolved in session. Key fixes: hot-reload `CACHE_MODE_IGNORE` misuse + missing signal `success` arg corrected; `_assert_handler` Callable seam removed in favor of accumulator+terminal-assert pattern; Rule 12 loop-boundary severity upgraded to release-fail with `allow_loop_seam` override; formula-level `is_finite()` guards added; `defense_per_vit > 0` strict enforced; autoload-ordering promoted from edge-case to hard constraint; AC-033/AC-035 gate classification unified; AC-016 key fix + H.8 stale row removed. Pass-2 arithmetic verification (AC-022/023/024) independently agreed — prior dispute closed.

Prior verdict resolved: Yes — all 5 pass-1 blockers confirmed held after fresh-session inspection.

### Blockers applied (8)
1. **Hot-reload sequence (C.1.8)** — rewritten to load into fresh dict using returned `ResourceLoader.load(..., CACHE_MODE_IGNORE)` value directly; atomic `_templates = new_templates` on success. `emit_signal("balance_database_reloaded", ok)` with required typed `success: bool` arg.
2. **`_assert_handler` seam removed (C.1.4)** — replaced with `_validation_errors: Array[String]` accumulator + terminal `if _is_debug: assert(false, joined_errors)`. AC-018/019/031/032 rewritten to test real debug/release branches without a Callable seam.
3. **Rule 12 severity + AC-051 split (C.1.1, C.1.6, H.7b)** — added `allow_loop_seam: bool = false` field to `WaveScalingCurve`. Rule 12: debug always warns; release fails unless override. AC-051 split into 051a (hp debug warn), 051b (dmg debug warn), 051c (release fail no override), 051d (release pass with override).
4. **Formula-level degeneracy guards (D.1)** — added mandatory implementation guards: `w < 0` fallback returns `wave_entries[0]` (prevents GDScript negative-index wrap); `assert(loop_*_scale > 0)` at entry; `assert(is_finite(result))` at output. Covers INF/NaN propagation into Combat Engine.
5. **`defense_per_vit > 0` strict (C.1.6 Rule 5)** — pillar-protection invariant. Allows no silent drop of VIT's damage-reduction role from concept §7.2.
6. **Autoload-order hard constraint (C.1.4)** — promoted from E.4 edge case to hard rule: "BalanceDatabase MUST be autoload #1; peer autoloads listed before it cannot safely call getters or await database_ready."
7. **AC-033/AC-035 unified BLOCKING classification (H.8)** — table row updated to `Logic (blocking)`; summary paragraph rewritten to list explicit blocking gates including all three lint ACs (AC-033, AC-035, AC-052) via `tools/ci/lint_forbidden_patterns.sh`.
8. **AC-016 key fix + H.8 stale row removed** — AC-016 uses valid key `&"str"` with inverted Vector2 (isolates Rule 10 from Rule 6). H.8 duplicate-budget row struck through, pointing to Enemy System GDD per AC-049.

### Specialist convergences
- `_assert_handler` architecture (systems-designer + godot-gdscript-specialist agreed from different angles — creative-director adjudicated removal).
- Hot-reload signal arity (game-designer framed as NICE-TO-HAVE; godot-specialist framed as BLOCKING — creative-director adjudicated BLOCKING since runtime error on every reload breaks the designer pillar).
- AC-022/023/024 arithmetic (qa-lead and systems-designer independently re-verified correct — prior pass-1 dispute closed).

### Specialist disagreement resolutions
- **AC-004 synchronous-init contract** — qa-lead BLOCKING; creative-director downgraded to RECOMMENDED (missing-spec gap, not broken behavior). Deferred with other recommended items.
- **Ceremony concern** — prior creative-director note acknowledged as tolerated tradeoff. Trim-down pass deferred until Foundation ships and 2+ consumer GDDs exist to validate load-bearing ACs.

### Recommended deferred (12)
Slot-enum display-mapping pointer; derived-stat display contract pointer; spawn-count loop scaling (concept §5.2); boss-wave difficulty multiplier (concept §5.3); AC-029 negative-index guard (now covered by Edit 5 guard, verify in re-review); `spawn_count = 0` warning; OQ-1 pre-implementation gate for H.5; injection seam release-mode coverage AC; `loot_tier` typeof() mechanism explicit; Rule 13 nested Node-resource guard; `balance_load_failed` NOT-fire-in-debug AC; AC-004 synchronous-init contract text.

### Nice-to-have deferred (4)
AC-052 grep heuristic blind-spot note; AC-055 migration-tool headless-compat classification; post-MVP trim pass (extract migration framework to appendix); AC-047 Android 500ms budget verification (OQ-2 owns).

---

## Review — 2026-04-19 (pass 1) — Verdict: MAJOR REVISION NEEDED (revisions applied in-session)
Scope signal: L (multi-system integration hub — 1 formula, 5 Resource families, 11→12 validator rules, 50→55 ACs, 8 hard downstream dependents, hot-reload infra, schema migration tooling)
Specialists: game-designer, systems-designer, economy-designer, qa-lead, godot-gdscript-specialist, creative-director (senior synthesis)
Blocking items: 5 | Recommended: 3 | Nice-to-have: 4

Summary: First MVP GDD (Foundation layer). Architecturally sound but carried three load-bearing schema holes (slot enum collapse from 13→3, mixed base/derived stat namespace, wave-loop boundary 42% difficulty drop), one doc-internal contradiction (C.1.7 `_init()` claim vs E.5), and several under-specified test contracts. All five blockers + all three recommended fixes applied in-session. Awaiting fresh-session re-review to confirm fixes hold.

Prior verdict resolved: First review (no prior).

### Blockers applied (5)
1. **Slot enum** — expanded `ItemDefinition.slot` closed enum from 3 categories to 13 concrete values matching concept §3.4 (helmet, chest, pants, boots, gloves, shield, weapon, necklace, wings, bracelet, ring, artifact, pet). Per-slot-count logic (2× rings, 2× bracelets, 2× artifacts) deferred to Inventory & Equipment GDD per the comment in C.1.2.
2. **Mixed stat namespace** — `stat_roll_ranges` keys reduced to base stats only `{str, dex, int, vit}`. ATK/DEF remain derived via `CharacterProgressionCurve` coefficients.
3. **Wave-loop validator gaps** — rule 5 extended to enforce `loop_hp_scale > 0`, `loop_dmg_scale > 0`, per-entry `hp_mult > 0`, `dmg_mult > 0`, `spawn_count ≥ 0`, `loot_tier ≥ 0`. New rule 12 (warning) detects the 42% loop-boundary difficulty drop invariant violation. AC-051 covers the warning path.
4. **C.1.7 vs E.5 contradiction** — removed the `_init()` default claim from C.1.7; replaced with canonical `@export`-line default instruction matching E.5. Added explicit statement that each Resource family has its own `CURRENT_SCHEMA` constant.
5. **Test contracts** — added injection seams (`_is_debug`, `_error_reporter`, `_assert_handler`) to BalanceDatabase API (C.1.4); rewrote AC-018/019/031/032 to use them. AC-033/035 defined concrete regex + script path (`tools/ci/lint_forbidden_patterns.sh`) + CI step name; AC-033 promoted from ADVISORY to BLOCKING. AC-049 moved to Enemy System GDD (cross-GDD dependency). Rule 7 extended to validate `wave_entries` Dictionary per-entry keys/types. Formal signal signature `balance_database_reloaded(success: bool)` declared.

### Recommended applied (3)
6. **`defense_per_vit` added to `CharacterProgressionCurve`** — gives VIT's damage-reduction effect from concept §7.2 a data home.
7. **`loot_tier: int` added as required key on `WaveScalingCurve.wave_entries`** — reserves the field so Drop & Loot Tables GDD can bias drop weights by wave without a schema migration.
8. **Enum alignments + `await` guard pattern** — `behavior_tag` {melee, ranged, aggressive, tank}; `size_category` adds `huge`; `skill_type` adds `debuff`; canonical `if not is_ready: await database_ready` snippet added in C.1.4.

### Other clarifications
- `loop_count` variable-table description rewritten — 1-indexed once looping is active; `0` for pre-loop/no-loop.
- AC-050 baseline measurement methodology concretized (pre-ready hook + post-`database_ready` delta; reference Android device logged in `production/qa/evidence/balance-memory-smoke.md`).
- 5 new ACs: AC-051 (loop-boundary warning), AC-052 (per-frame getter ban), AC-053 (one-time clamp warning), AC-054 (unrecognized-class skip), AC-055 (migration tool `schema_version == 0`).

### Specialist disagreement resolutions
- **AC-024 arithmetic** — qa-lead flagged as wrong; creative-director agreed. Verified independently against the formula (`loop_span=10, offset=13, loop_count = 13/10 + 1 = 2`). **AC-024 is correct as written.** QA-lead's calculation missed the `+1` term in the formula. No edit applied.
- **Slot enum fix-now vs defer** — resolved as fix-now per creative-director. This review's cheapest window.
- **DropTableDefinition deferral** — GDD stays deferred; field reservation (`loot_tier`) added here to avoid later migration.

### Remaining work (for fresh-session re-review)
- **Unverified**: OQ-1 `CACHE_MODE_IGNORE` constant name in Godot 4.6 — still an Open Question; must be resolved before C.1.8 implementation.
- **Pillar tension** (flagged by creative-director, not resolved): GDD is ceremony-heavy (844 lines, migration framework, dev-only hot reload) for a layer meant to enable effortless balance iteration. Live-service balance strategy not addressed. Consider addressing in a follow-up pass if/when a retention-tuning need is surfaced.

### Nice-to-have (deferred)
- Post-launch live-balance strategy (remote config / fallback).
- 5-step quick-reference for designers ("how to add a new enemy").
- Verify `.godot/uid_cache.bin` path against Godot 4.6.
- Split `test_validator_rules.gd` into focused suite files per rule family.
