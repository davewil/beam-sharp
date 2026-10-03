# VERIFY: ticket 57 brief (independent verifier, 2026-10-03, OTP 29)

Method: copied probes/57 to scratch, rewrote /tmp paths, ran `EUNIT=1 ./run.sh` from scratch (builds base + A/B/C from
current compiler/src + proto/). Plus my own hand-written programs against the ENV pristine build and the C build.

## Per-claim verdicts
- Ticket table, 5 rows + extras, A/B/C acceptance, guard agreement G1-G5: REPRODUCED (table.out, literal_use.out,
  roundtrip.out, ast.out, conflicts.out, yecc_*, 38b_shim_*, n_* byte-identical modulo path).
- yecc 6 s/r all builds; 226/230/226/226: REPRODUCED.
- Unit suite: 8 baseline failures identical across my run and capture; delta A = 1 (intervals_tests), B/C = 0: REPRODUCED.
  Baseline = pristine compiler/src build with same harness, so like-for-like. The "environment" cause is inferred
  (tests read src/bs_parser.yrl, aoc/, escript) and I confirmed the conflict test reads `src/bs_parser.yrl` which the
  scratch root lacks; the other 7 causes are not individually diagnosed: SUPPORTED, not proven.
- Compile-time "no delta beyond noise": REPRODUCED (my medians 89-97 ms, order differs from capture; B is highest in
  4 of 5 of my cells, ~3-4%; consistent with the brief's hedge but do not read as "B is free").
- Pristine-compiler facts (my own programs): `Nz Neg() -> -5` refused ("not covered ... 0"); `type V = int where value == 5`
  -> `bad range type`; guard `n >= -5` residual `F(n)` vs `n >= 5` -> `F(<= 4)`; `x / -0` compiles, `x / 0` refused:
  REPRODUCED. C: `x / -0` refused. REPRODUCED.
- Source claims: `alternatives/1` shared by `refine` (bs_check:1899) and `apply_guard` (:4918); `comparison` matches only
  `{e_int,_,K}` (:4949); `type_of e_int` point type (:2867) vs `e_neg` (:2874); `negate/2` floats only (:944); `int_lit`
  `'-' integer` (:470); e_neg in F51: all CONFIRMED. Only users of e_neg: expr_vars, type_of, used_vars, emit, so the
  Option-1 fold has no hidden consumer.
- Beyond the brief (my addition): under C, runtime works: `Low() -> -5` returns -5, `--7` -> 7, `Dbl(-50)` function_clause.
- 38b shim: sed changes only `bsc=`, the `[ ! -x ]` build guard, and the `-pa` path; cases/expectations untouched. FINE.
  Note (not in brief): shim on A/B/C reports "3 probes DIVERGED" (expected: they are the fixes); brief cites only baseline 7/7.
- Circularity: A/B/C patches contain nothing fixture-specific (diffs read in full). B's `const/1` and A's grammar are
  plausible readings of the ticket's branches, not tuned. The "revisions/" v1 run differs from final only in site-row
  module names (spaces) and added rows: refinement rows identical. NOT CIRCULAR. One soft point: A and B were built by the
  author, and the "A fails G2/HeavyNeg" result is a property of A's closed grammar choice (brief admits this in Limits).
- Neighbours: Erlang (erl_lint.erl:2431-2480, erl_parse.yrl:331 and :1984), Elixir behaviour/beam read, Gleam 1.18.1 table:
  REPRODUCED from real runs/installed sources. Elm: /tmp/elmsrc is a genuine git clone of github.com/elm/compiler at tag 0.19.1
  (commit c9aefb6); Syntax.hs:4788 text and Pattern.hs:63 quoted verbatim; run-time compile hit 403 (package.elm-lang.org) and
  was not bypassed (I found no sign of workaround; the clone used the proxy-configured git route to github, which the
  status endpoint treats as allowed). Brief labels run-time UNMEASURED: honest. Note brief says "Elm 0.19" while installed is 0.19.2.
- UNMEASURED-as-fact: none found; tree-sitter/LSP/`-spec` for negative bounds listed as not tested (I ran a negative-bound
  Delta at runtime under C; fine, but the emitted -spec text was still not inspected).

## Logic
Recommendation (literal fold in `negate/2`) follows: it is the only prototype green at refinement, guard and body sites
(measured), costs one clause, adds no conflict or red test. The hedge that `2 + 3` stays refused is stated with its
evidence. Weak point: "consistent with Take(2+3) refused" argues from the same compiler gap; fine as scoping.

Overall: REPRODUCED, not circular, no UNSUPPORTED claims; minor wording gaps only (8 env failures causes, B timing trend, 38b divergence on prototypes).
