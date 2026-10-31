# Verification of the ticket 65 decision brief

Verifier run 2026-10-30. Probes copied to a fresh `/tmp` dir and re-run with their documented commands.
Nothing in `brief.md` or `probes/` was edited. bsc, gleam and elm were not available, so no B# program was compiled.
OTP 25, Elixir 1.14.0.

## 1. Re-runs against the saved .out files

All 7 probes ran to completion (exit 0). I diffed fresh output against saved output with timestamps and pids normalised.

| Probe | Fresh vs saved |
|---|---|
| p1 | Same except one line. The saved run has `Logger - error: {removed_failing_handler,...}` and the fresh run does not. It is async logger noise and has no bearing on the result. All semantic lines are identical. |
| p2 | Same on every result (erlc exit 0, `sticky_directory`, `-pa` boot crash exit 1, `-pz` OTP wins, embedded boot crash, F, G). Only the interleaving of the async `=ERROR REPORT` and "no logger present" lines differs. |
| p3 | Identical. |
| p4 | Identical. |
| p5 | Identical. |
| p6 | Counts identical: 4 quals, `Enumerable`, 30 rows (List 16, Map 12, Term 1, Float 1), 5 distinct names, hits 1. Timings differ. See the timing note in section 3. |
| p7 | Identical. |

Extra check, not in the brief: I put each of `lists`, `maps` and `string` alone in a `-pa` dir. Each one alone also makes the VM fail to boot (rc 1). The brief's claim 9 generalises from a dir holding all three, and it holds for each name.

## 2. Per-probe verdict, and circularity audit

| Probe | Verdict | Evidence |
|---|---|---|
| p1 Elixir `defmodule Map` | PASS (observational) | There are no assertions. It prints what Elixir does, and a control (C) shows `Map.update!/3` exists unclobbered. The "undefined function" results follow almost by construction once `Map` is replaced by a 1-function module. They are real observations, but the information content is "Elixir lets you do it and breaks". One flaw: the probe's `echo "exit=$?"` reports `head`'s status, so the saved `exit=0` is meaningless. The `elixirc` exit does use `PIPESTATUS` and is correct. |
| p2 Erlang module named stdlib | PASS | Observational with a control (G) and a negative control (`-pz`). I confirmed the control logic. Cited source lines check out: `code_server.erl:1076-1077` and `1118-1122`, `code.erl:732`, `erl_lint.erl:272-286`. Nothing is hard-coded, and `erlc` and `erl` results are printed as seen. |
| p3 Same module, two paths | PASS | Real VM and `systools` results printed as seen. Cited lines OK (`code.erl:965-969`, `systools_make.erl:992`). |
| p4 OTP 25 builtin type | PASS, with one flagged inference | A, C and D are genuine compiler results. B (claim 19, "uses still resolve to the builtin") is an inference from an "unused type" warning. The brief says so itself. I did not independently test it. Claim 17 line cites `erl_lint.erl:2985-2998`, which matches. |
| p5 Emitted-call collision | PASS, not circular, but weak by construction. See below. | |
| p6 Set size and cost | PASS | See the mutation results below. |
| p7 Corpus scan | PASS on counts. PARTIAL on provenance. See below. | |

### p5, the 'F62 shape' caller
- The F62-shape caller is faithful. `compiler/src/bs_emit.erl` around lines 1048-1062 (`expr({e_qcall,...})`) emits a remote `TMod:TFn(...)` call using the OTP target from `bs_check:standard_target/1` when `Mod` is in `reserved_qualifiers()`. A `generated` row emits a local function call. Otherwise it goes to `remote(L, Mod, Fn, ...)`, the `'Mod':'Fn'` shape for user modules. F62's header says the same (`Top` compiles to `lists:reverse(lists:sort(...))`, "No `List.beam` ships"). F11 confirms `module Shop.Orders` emits `'Shop.Orders'`.
- The hand-written Erlang is therefore the right shape. But bsc was not run, so it is a simulation, and the brief says so.
- The result is near-tautological. A module `'List'` that exports only `Length/1` cannot satisfy a call to `'List':'Reverse'`, and `lists:reverse` never mentions the atom `'List'`. The "shipped-module" caller is a straw man for a design already rejected by 67. The probe cannot fail on the claim that matters (that B# as built has no VM-level collision), because the claim rests on `bs_emit.erl`, not on the VM.
- Mutation: I changed `caller_f62` to call `'List':'Reverse'`. Section B then showed the F62 caller dying with `undef`, so the probe does go red. Not circular.

### p6
- The reserved set is extracted by parsing `bs_check.erl` with `erl_scan` and `erl_eval`, not hard-coded.
- Mutation 1: I added `'Stream'` to `reserved_qualifiers()` in a copy. The probe reported 5 qualifiers, so the extraction follows the source.
- Mutation 2: I deleted the Map Take/Drop rows in a copy. The probe reported 28 rows and Map 10, so the row count follows the source.
- Mutation 3: I broke the map implementation (`is_map_key(foo, Map)`). The probe printed `MISMATCH hit counts [0,1]` and exited 2, so its cross-check can fail.
- One caveat: the benchmark times probe-local `lists:member`, map and sets code. It does not time `bs_check` itself. The brief's phrase "what bs_check does per module" matches `reserved_module_name/2`, which does `lists:member(Module, reserved_qualifiers() ++ maps:keys(protocol_table()))`. That is fine.

### p7
- Independent re-derivation with my own grep (`^\s*module\s+...` over `*.bs`, excluding `_build`). The brief's figures reproduce: 163 `.bs` files, 121 module declarations, 112 bare, and exactly one match against any current or planned name (`Stream`, `compiler/examples/Stream/stream.bs:22`). No corpus module is named List, Map, Term, Float or Enumerable. No `.bs` files exist under `_build`.
- Mutation: I pointed a copy of the probe at a temp tree containing `module List` and `module Task`. The probe printed `List` under CURRENT and `Task` under PLANNED, so the filter works and is not constant.
- Provenance flaw (partial circularity): the header says the "planned set is read from the ticket text by grep, shown, not assumed". In fact `PLANNED="Enum String Int Process ..."` is hard-coded, and the grep lines are display only. They do not feed the set. The grep also does not show the Enum or System names, and it shows no Agent line. I checked the tickets myself, and ticket 96 Q6 lines 189-191 do name `Enum`, `String`, `Int`, `Process`, `GenServer`, `Supervisor`, `Logger`, `System`. The numeric result is unaffected, because the set is correct and the match count is independent of the grep.
- Another weakness: the "must be none" check for the CURRENT set only prints. It does not assert or exit non-zero.

## 3. Claims table, spot-check against source

Verified true by reading the files:
- `bs_check.erl:1699` is `reserved_qualifiers() -> ['List','Map','Term','Float']`. `:241-254` is `reserved_module_name/2`, and it also refuses `maps:keys(protocol_table())`, which is `Enumerable` only.
- `bs_diag.erl:1385-1397` is the reserved-module refusal text, and `:1405-1413` is `reserved_qualifier_shadowed` with the "write the module's full path to reach it" fix. `bs_check.erl` around line 3283-3290 is `reserved_call`, which raises it (the brief's `:3290` points at the right spot).
- Ticket 96 Q6, lines 189-212, is exactly as quoted: "Round 3 answered 2026-09-25 (David): Q6 yes ... This answers ticket 65's first question by rule".
- Ticket 67: lines 270-271 say "the set is closed by construction", and lines 388 and 465 say the reservation policy "stays its own". The "answered twice, in opposite directions" description is fair. 67 answered closedness, 96 Q6 overrode it with accretion.
- Ticket 65 still says "B# reserves no name today" and is `Status: open`. Its premises are indeed stale. The names are reserved and built. F32 and F62 exist, and the F62 header says `done 2026-10-04`. F32 says `reserved_module_name/2` is called before `module_matches_path/3`. `standard_table` has 30 rows (6 literal plus 24 `declared_rows`, List 16 / Map 12 / Term 1 / Float 1).
- Ticket 48 Q9 DECIDED, with `types.ex:291` and Elixir 1.19.5, exists (lines 425-440). Claim 4 is correctly marked INHERITED.
- The ticket 17 line 396 `Stream.Map` example exists. Ticket 98 is resolved (Task, Agent in). Ticket 93 (`Binary`) is **open**.

Misstatements and imprecisions found (none changes the verdict):
1. Section 1a says "11 firm". `Binary` comes from ticket 93, which is `Status: open` (ENG-434), so it is proposed, not decided. The firm count is 10, or 11 only if an open ticket's delta counts.
2. The brief says the map lookup is "flat (8-10 us) at every N". The saved p6 output shows 7.2, 17.3, 13.1, 9.6 and 8.5 us, and my fresh run showed 2.9, 13.4, 10.5, 9.0 and 10.5 us. The shape (flat) holds. The quoted range does not.
3. Claim 25 says "3.5 ms at N=1000". My fresh run gave 1.66 ms, a 2x run-to-run variance. The brief does warn that timings come from one run. The shape (linear growth, under 20 ms at N=10000) holds, and the conclusion "not a reason to prefer an option" survives.
4. The brief cites `bs_parser.yrl:626-667`. The call productions are at lines 619-662. The "accepts only" gloss omits the `lident(...)` bound-name call (ticket 75) and the `uident<...>(...)` instantiation, though neither is a qualified-module spelling, so the argument stands.
5. The p7 header "read from the ticket text by grep" is partly wrong. See section 2.
6. Claim 26 and the sentence "found by grep" in 1a overstate: the planned set is hard-coded in p7, though correct.
7. Claims 30, 31, 32 and 34 are labelled reasoned or unprobed by the brief itself, and I agree. Claims 16, 20, 33 are labelled INHERITED or unprobed, and I agree. I found no claim stated as measured that was actually unexecuted.

## 4. Key assertion: ticket premises are stale

Confirmed by reading `bs_check.erl`, `bs_diag.erl`, `bs_emit.erl`, F32, F62, and tickets 65, 67 and 96.
- Four qualifiers plus the `Enumerable` protocol name are refused as whole module names.
- 96 Q6 (David) answers the first question by rule in favour of "reserved, accreting".
- `Map.Get` and `List.*` lower to OTP calls (or generated local functions) and ship no beam.

One nuance the brief handles but should be read carefully: 96 Q6 settles *which names*, and it assumes the reserve policy ("on the terms List and Map took it"). It does not formally address options B (shadow) or the unreachable-namespace option. The brief's recommendation that A is already answered by decision plus build is supported, but whether B and C are closed is David's call. The brief leaves that open as its own question 1.

## 5. Overall verdict

The brief is **sound**. Every probe reproduces, with differences only in async logger interleaving and timings. No probe is circular in a way that affects a conclusion. p5 and p6 go red under mutation, and p7 goes red when I plant a collision. The factual claims I could check against source are correct. The flaws are small:
- p5's result is true by construction (labelled as a simulation in the brief).
- p7's "planned set read by grep" is hard-coded.
- p1's `exit=$?` is meaningless.
- `Binary` is counted as firm though ticket 93 is open.
- The map lookup range "8-10 us" is looser than the data.
- The `bs_parser.yrl` line range is off by about 7 lines.
- The "3.5 ms" figure varied 2x between runs.

All of these are correctable without changing the recommendation. The brief is accurate about what it did not run: nothing went through bsc.
