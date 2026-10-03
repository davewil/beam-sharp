# VERIFY — ticket 59 brief (independent verifier)

Method: probes copied to scratch, `WORK` pointed at a fresh dir, `SKIP_E=1 ./run.sh` (all three compilers rebuilt from a fresh
copy of `compiler/src`; `compiler/src` unchanged between brief HEAD 5133d97 and now e08397d). The call-time harness was run
separately 3 times (15 VMs x 5e7 iterations each). Nothing in the repo or the probes was edited. No proxy/egress block hit.

## 1. Re-run vs captured output

| probe | result |
|---|---|
| 00 env | identical apart from HEAD sha and work paths |
| 01 emitted | byte-identical |
| 02 forged (Erlang + Elixir, shipped / PROTOTYPE-A / PROTOTYPE-W) | byte-identical; every row of the brief's §1 table reproduced |
| 03 bytes | Code and stripped columns identical; full-file column +48 B everywhere (longer path in compile info). Delta unchanged |
| 04 elision | identical except one JIT address in a `call` line. I also dumped `proto` Leaf/Unproven and wide `IntFromProven` abstr myself (below) |
| 06 f, 07 g | identical (Gleam: compile time only) |
| 08 corpus | identical: proto 0/21, wide 5/21, +19 is_integer, 62 tag tests |
| 05 call time | three fresh runs, below |

Call time, my runs (ns per loop iteration, median diff; A/A in brackets):

| comparison | run 1 | run 2 | run 3 | brief |
|---|---|---|---|---|
| tag test removed (proto-base) | -3.37 [+0.41] | -2.94 [-0.08] | -3.13 [+0.29] | -3.28 / -3.22 |
| same-code LoopCtl control | -0.80 | -0.80 | -0.03 | -0.78 / -0.43 |
| is_integer added (wide-base) | +0.07 | -0.21 | -0.29 | -0.77 / -0.37 |
| same-module record vs structural | +3.19 | +2.48 | -1.02 (base IQR 3.1, noisy) | +2.73 / +7.60 |

Ordering (proto faster than base) held 3/3 and in the brief's two runs. Magnitude about 3 ns, but the same-code control
reads -0.8 in 4 of 5 runs, so a bias-corrected figure is nearer 2.2-2.6 ns. The brief says "~3 ns, +/-1 ns resolution", which
is fair but slightly flatters the effect. The is_integer cost is sign-unstable across 5 runs, so "UNRESOLVED below ~1 ns" is
right. The same-module A/B is not stable (one of my three runs was negative), so it should not be cited as corroboration.
The brief already discards its +7.60. LoopRec/LoopCtl loop code is asm-identical between base and proto: reproduced
(same md5s).

## 2. Circularity hunt

- **Prototypes.** `diff` of the patched `bs_emit.erl` copy against the shipped copy: PROTOTYPE-A differs by one line
  (`orelse not Public`) plus a comment header. PROTOTYPE-W differs by `none when Public` -> `none` plus a comment. Not
  circular. Forge.abstr base vs proto differs only in `Amount`'s clause, and base vs wide only in `Classify`.
- **Forged fixtures.** These are plain maps built in `forge.escript` and `forge.exs`, passed to the compiled exported
  functions. No bypass. I dumped the shipped exported heads: `ViaCart` and `InlineCart` test only `Kind =:= 'Forge.Cart'`;
  `ViaList` and `ViaOctets` have no guard at all. So the shipped compiler really emits no guard at depth, and the 999 comes
  from `Invoice.Total = 999`, as claimed. REPRODUCED.
- **InlineCart vs ViaCart.** The same read (`map_get('Total', map_get('Item', C))`); only the private extraction differs.
  Fair comparison.
- **BEAM elision.**
  - REPRODUCED. Base/proto/wide asm show the `Kind` test kept on `OnlyLit`, `AfterTest`, `Unproven` and `Mid`. The BEAM
    only tracks `t_map`, not map-key values.
  - Wide `IntFromProven`: abstr has `is_integer`, asm has none and carries `{tr,x0,t_integer}`. `IntUnproven` keeps the test.
  - Proto `Leaf`: the explicit `Kind` test disappears and the `map_get` stays unannotated (`{x,0}` rather than
    `{tr,{x,0},t_map}`). This is consistent with "0 JIT lines saved on Leaf".
- **Corpus.** The 7 "not compiled" exemplars (`25a`-`25g`) are not B# modules: `bsc` says "no `module` line". The brief's
  "may need other flags" is wrong but harmless. The claim "corpus has no private record-parameter function" is true of the 21
  and says nothing about those 7. The 0/21 under N is vacuous as evidence of safety: no module would exercise the guard
  either way.

## 3. LOGIC: does Option N follow from the evidence?

**It does not follow from the measurements; it follows from two design preferences, and the measurements point the other way.**
- Measured: the private tag test is the only thing that turns forged nested/list records into `function_clause` (ViaCart,
  ViaList). N removes exactly that. The brief concedes it ("the numbers do not answer it").
- Reason (c), "deleting an accident, not a defence", is contradicted by the brief's own table. The coverage is
  deterministic, and it holds on two measured shapes (projection and list element). "Accidental" means only
  refactor-dependent. It is also monotone: extracting a helper can only add a check, never remove one. So S already
  satisfies "extract-method never weakens the boundary"; N satisfies the stronger "never changes it" by weakening the
  loud case to match the silent one.
- Reason (d), cost, is ~13 B and ~2-3 ns on a micro-loop, so it argues for nothing strongly.
- Reason (a) is the letter of 18 §4 ("no further", `18:815`; "a guard can only move when you edit the function it sits on",
  `18:842`). The brief itself shows the premise behind that letter ("every call site is checked") is false at depth.
- Ordering contradiction: the brief says the real fix is a deep exported guard, after which both private tests are dead
  weight. If so, narrowing first creates a known safety regression window just to be deleted or moot later. The brief's own
  fallback (S as interim) is the order the evidence supports.
- Also internal tension: "if the tag test stays, the int test has no principled reason to differ" (S4) argues for W or N
  symmetry, yet the §5 counterargument to W is that it cannot close the hole. N has the same defect.

Verdict: the recommendation is a defensible spec-simplicity call (it would help the clean-room handoff), but "moderate
confidence in N" is not supported by the measured evidence. The evidence supports "S now, deep guard ticket next" at least
as well. Evidence on the 18-guarantee finding is solid: 18's only named limit is `sys:replace_state` (`18:807`), not depth,
and 18's own rule C ("outcome 3: wrong term traverses the body without an objection") describes InlineCart exactly.

## 4. Claims vs evidence

| claim | verdict |
|---|---|
| §1 forged table, all rows, Erlang and Elixir | REPRODUCED |
| finding 1: `Direct` is guarded by the exported fn; projection reached by neither guard | REPRODUCED |
| finding 3: int test has the same hole (`[100.5]`, `[300]`, `[<<"x">>]` -> `big`; wide -> `function_clause`) | REPRODUCED |
| S2: BEAM keeps tag test, drops `is_integer` when proven | REPRODUCED |
| S4 pins `boundary_kind_tests.erl:88`, `boundary_range_tests.erl:120` | test names/headers exist at those lines (F24.6 and "F37.5" label) |
| `bs_emit.erl:275/278/284/163/332` | correct (guard_one:275, case:278, `none when Public`:284, Public:163, comment:332-333) |
| bytes: +13.4 B/fn tag, +5.7 B/fn int (Code); stripped +6.3/+2.8 | REPRODUCED. Unstated: unstripped file is ~+36 B/fn for the tag test (debug info) |
| JIT line counts (45->39 etc., 0 on Leaf) | REPRODUCED |
| call time, tag ~3 ns | REPRODUCED in 5 runs (2.9-3.4 raw; ~2.5 control-adjusted) |
| same-module A/B +2.73 | NOT REPRODUCED reliably (+3.2, +2.5, -1.0) |
| is_integer cost unresolved | REPRODUCED (signs flip) |
| corpus 0/21, 5/21, +19 | REPRODUCED. Leave "no private record fn" caveat noted above |
| contradicts 26's "tag costs nothing measurable" (`26:313`) | quote exists; comparison is of a different test (tagged vs untagged, both guarded), as the brief says |
| 26a +14 B, 18a +3-5 B, 18 §1 "elided entirely" (`18:615`) | citations exist in `18-boundary-defence.md:227,302,438,615` |
| 18's sentence "crash, never silently" is false at depth | SUPPORTED, but the brief paraphrases and drops "not always where it entered" (`18:407-408`); the substance (silent) still holds |
| neighbours: gen_server `try_handle_call` private, not exported, tagged-tuple test (`gen_server.erl:2468`) | REPRODUCED; the `-export` range `:190-216` was not otherwise checked |
| Elixir `elixir_map.erl:33-44`, `utils.ex:176-205` | lines match; behaviour reproduced (7 / 999 / FunctionClauseError) |
| Gleam | REPRODUCED |
| Elm row | UNMEASURED, correctly labelled; cites a research file (not re-run) |
| "N changes 0 modules; eunit stays green" | first part REPRODUCED; second correctly labelled UNMEASURED |
| recommendation N, moderate confidence | NOT SUPPORTED by the evidence (see section 3) |
| overall findings (what the compiler does) | REPRODUCED; no CIRCULAR probes found |

Overall: measurements REPRODUCED, no circular probe; recommendation does not follow from them.
