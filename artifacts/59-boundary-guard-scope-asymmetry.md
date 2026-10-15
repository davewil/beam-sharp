# 59 -- The boundary guard applies two rules with different scopes

Status: brief only; ticket left OPEN for David. ENG-241. Measured on `compiler/` identical to 019533d
(`git diff 019533d HEAD -- compiler/src` is empty), OTP 28.5, x86_64 Linux, JIT.

## What the ticket asks, and what changed since

`bs_emit:guard_one/7` (called from `boundary_guards/6`; the ticket still says `/5`, 46 says `/4`) emits the
record **tag** test on every function, private included, and the **kind** tests (`is_integer`, `is_float`) and
the F37 **range** comparisons on exported functions only. The ticket asks whether the private tag test is a
defect against 18 s4, or whether 18 s4's "exported" is too narrow, and what the answer costs.

Since it was written: F37 (range, exported-only, 2026-09-08) and F51 (`is_float`, exported-only) copied the
exported-only rule, so the scope now governs **four** guards, not two. F42 guards a foreign *return* at its door.
No ticket or feature has touched the private tag test (`grep -l 'ticket 59\|ENG-241'` hits only 46, 58, F24, F37).
The shipped corpus contains **no private function that takes a record** (`59_corpus`), so today the choice
changes no emitted byte in `compiler/examples`.

## The gating question (alone)

> **Does a guard belong to the exported door only, or to every function that consumes a typed parameter?**

One answer fixes the scope of all four guards (tag, `is_integer`, `is_float`, range). Everything else follows:
whether F24/F37's "exported only" paragraphs are rewritten (answer: every function) or the tag test is deleted
from private functions (answer: exported only); what 18 s1's cost paragraph says; and whether the depth hole in
Findings 2 is closed at the door (46 s4 projections) or at the use (a private test). No sub-decision is asked
until this one is answered.

## Findings

**F1. The private tag test is real, unconditional, and equal in cost to the exported one. CONFIRMED.**
`59_reach.sh` (guard table read from the emitted abstract code):
```
HEAD  Priv/1   private  tag_guard=Y        Direct/1 exported tag_guard=Y     ViaList/1 exported tag_guard=n
```
`erlc` does not remove it even when the exported caller has just tested the same tag: `59_elision` shows
`PR1/1` (called only from the tag-tested `QRecDirect`) still carrying `map_get('Kind')` + `is_eq_exact`.

**F2. A wrongly-tagged record DOES reach a private function through an exported one, and only the private tag
test stops it. CONFIRMED, but only through a NESTED position. PARTLY for the ticket's framing.**
`59_reach.sh`, plain-Erlang forged maps `I = #{Kind => 'G.Invoice', Id => 1, Total => 5}`:
```
                                        HEAD (as shipped)       EXP (private tag test removed)
Direct      Invoice-tagged              error:function_clause   error:function_clause   (door tests it)
ViaNested   Inner Invoice-tagged        error:function_clause   ok 5                    <- silent
ViaList     element Invoice-tagged      error:function_clause   ok 5                    <- silent
ViaTuple    component Invoice-tagged    error:function_clause   ok 5                    <- silent
ViaNested   Inner = 42                  error:function_clause   error:badmap            (loud either way)
```
`ViaNested(Wrapper w) -> Priv(w.Inner)`: the exported guard tests `Wrapper`'s tag and stops. The ticket's
"defect" argument -- "site 1 has already rejected a wrong tag" -- is **false for any value taken out of an
aggregate**: the checker believes the declared type of `w.Inner`, and nothing validated it. Removing the private
test (EXP) turns three `function_clause` rows into silent `ok 5`.

**F3. Passing a `term`, a narrowed `term`, a union or a foreign value to a private `Order` parameter is REFUSED
at compile time; the forged-through-the-door path the ticket names does not exist for those. CONFIRMED (the
ticket's example is narrower than it reads).** `59_checker_refuses.sh`, real diagnostics:
```
F(term t) -> Priv(t)          G/g.bs:8:9: error: F hands Priv an argument it does not accept
                                argument 1 is not covered by Priv's declared type:  term
F(Order o) from term t        ... not covered by Priv's declared type:  { Kind: :'G.Order' }   (tag only; fields unknown)
F(Doc d) -> Priv(d)           ... { Kind: :'G.Invoice' }  the clause to add here: F(Invoice i) -> ...
CONTROL ValidateAs<Order>(t)  exit=0      CONTROL F(Order o) over Doc  exit=0
```
`ValidateAs` is a full structural check (`ViaValidate`: Invoice-tagged and bad-payload both return `-1`).
So the only channel is **a typed aggregate's interior**: record field, list element, tuple component.

**F4. The same hole exists, with NO guard at all today, for the other three guards. CONFIRMED -- the asymmetry
is not "tag vs kind", it is "the one test that happens to be on the private function".** `59_reach.sh`:
```
ViaIntList [1.5]    (public int, list<int> -> private PrivI)   HEAD ok 1.5   EXP ok 1.5   ALL error:function_clause
ViaOctList [300]    (list<Octet> -> private PrivO)              HEAD ok 300   EXP ok 300   ALL error:function_clause
ViaOctList [1.5]                                                HEAD ok 1.5   EXP ok 1.5   ALL error:function_clause
```
That is ticket 18's outcome 3 (a float out of `public int`) at HEAD, through F24/F37's own guarded types.
F24 s5 lists "a refined int below the top of a parameter" as a known open edge; this shows the open edge is
also where the private-scope choice bites.

**F5. Payload forgery passes everywhere under every scope. CONFIRMED -- the tag test is a partial backstop.**
`Direct(#{Kind=>'G.Order', Total=><<"x">>})` -> `ok <<"x">>` from `public int` under HEAD, EXP and ALL; same for
`ViaNested` inner. 18's sentence "never silently" is already false for the payload; no scope in this ticket
changes that (it is 46 s4's projections, owed).

**F6. "An exported function pays its guard on calls from inside its own module (one entry label)". CONFIRMED.**
`59_entry_label.sh`: `OuterExp([1.5])` (guard-less caller of exported `Inner`) -> `error:function_clause`;
`OuterPriv([1.5])` (caller of private `InnerP`) -> `ok 1.5`. Export table `'Inner'/1 -> label 4`; the local
call is `{call_only,1,{f,4}}`; label 4 holds `{test,is_integer,{f,3},[{x,0}]}`. Pure-Erlang control identical.
**18's corollary "a guarded-public/unguarded-internal pair is impossible" is PARTLY wrong:** impossible as one
function, possible as two. `59_split_entry.sh`: exported stub with guard + local twin gives
`inner(1.5)` -> `function_clause`, local `outer([1.5])` -> `ok 1.5`, Code chunk 89 -> 102 B (+13).

**F7. "The same code un-exported has the test elided entirely" (18 s1, quoted by the ticket). PARTLY.**
It holds only when `erlc` can prove the argument at every call site, and only for tests `erlc` understands.
`59_elision.sh`, B#-emitted beams, `ALL` variant (is_integer on every function):
```
PI/1 (only caller QDirect(int n), proven)      no is_integer test; body gc_bif '+' with {tr,{x,0},{t_integer,any}}
PU/1 (caller QList(list<int>), not proven)     {test,is_integer,{f,7},[{x,0}]}  kept
HEAD, record tag test: PR1/1 (proven caller) AND PR2/1 (unproven) both keep map_get('Kind') + is_eq_exact
```
So a private `is_integer` is free where it is redundant and paid where it protects; the private tag test is
never elided. On the corpus (`59_corpus`): under `ALL`, 5 beams gain 9 private int/float tests in the abstract
code and the Code chunk grows **0 bytes** in every one (all proven by callers).

**F8. 26a/18's quoted costs REPRODUCE on B#-emitted code; the call-time sentence does NOT transfer to the tag
test. CONFIRMED / PARTLY.** See Measurements. Tag +13.5-13.75 B (ticket: +14), flat in field count (3 vs 8
fields: 13.5 B each); `is_integer` +3.88 B (ticket: +3-5); `is_integer` call time inside noise (ticket: below
+-0.09 ns). But the tag test is ~4 ns per call, roughly 3x an empty recursive loop. 26a's "costs nothing
measurable" compared guarded tagged vs guarded untagged maps; against *unguarded* it is +4 ns (26a's own tuple
numbers: 2.17 vs 7.04 ns). In absolute terms still negligible for any body that does work.

**F9. Stale or inexact statements in the ticket and its neighbours.**
(a) "`boundary_guards/5`" is `/6` now. (b) F37/F51 extend exported-only to `is_float` and range; the ticket
names two guards, four exist. (c) "18's own cost section measured that a non-exported function has the test
elided entirely": only with a proving caller (F7). (d) "A private function's every call site is a checked
call site, so site 1 has already rejected..." (18 s4 via 46, 58, F24 s2, F37): false for interior values (F2, F4).
(e) 18 s1 "impossible pair" (F6).

## Neighbours

**Erlang.** A `-spec` guards nothing: `59_erlang_survey` `spec_only(1.5)` -> `ok 1.5`. Guards exist where the
author wrote them, and stdlib's idiom is guard at the exported door, none in the local worker:
`lists.erl:477-479` `seq(First, Last) when is_integer(First), is_integer(Last), First-1 =< Last -> seq_loop(...)`,
`lists.erl:481-487` `seq_loop` has only arithmetic guards. A record pattern in a *local* function head is a
tag+arity test the author chose: `via_nested(#wrapper{inner=#invoice{}})` -> `function_clause`; a forged payload
passes (`ok <<"x">>`). Visibility-blind, author-driven. (18's census: 83.3% of exported parameters are bare
variables, so the platform rarely guards at all.)

**Elixir.** No guard is inserted anywhere (`59_elixir.out`): `def nopattern(o)` with `@spec Order.t()` returns an
`%Invoice{}`; `defp priv_plain(o)` returns it too. `%Order{}` in a head is a user-written tag test and is
**visibility-blind**: `defp priv_tagged(%Order{})` rejects a nested Invoice (`FunctionClauseError`), and accepts
`total: "str"` (fields unchecked). `@enforce_keys` acts at construction only: `%Order{total: 1}` and
`struct!` raise, `%{valid | id: nil}` and a hand-built `%{__struct__: Order}` do not. Source:
`kernel.ex:5448-5450` "`@enforce_keys` is a simple compile-time guarantee ... not enforced on updates and it does
not provide any sort of value-validation"; `kernel/utils.ex:143-200` shows the check lives in the generated
`__struct__/1` constructor body. Elixir 1.18's type checker warns at compile time on the literal forged call
(`incompatible types given to M.pub/1`), not at runtime. (`elixir_map.erl` is not shipped as source in the nix
store; only `.ex` lines were citable.)

**Gleam 1.19.2.** (`59_gleam.out`; compiler source unavailable, run instead.) No runtime guard on any
function, `pub` or private, and `opaque` is compile-time only: from Erlang `direct({invoice,1,5})` -> `ok 5`,
`pub_total({invoice,1,5})` -> `ok 5` (field access is bare `erlang:element(3, X)`), `pub_case({invoice,1,5})` ->
`case_clause` (only a `case` on the constructor tests the tag), `add(1.5, 2.5)` -> `4.0`, `via_list([1.5])` ->
`2.5`, `sealed_total({invoice,1,5})` on an opaque type -> `ok 5`. Gleam has no scope question: no guard anywhere.

**Elm 0.19.2.** **Could not run:** `elm make` needs `package.elm-lang.org`, the proxy answers 403, so there is no
local output. Cited instead from `wayfinder/research/18-elm-port-validation.md` (observed 2026-08-13 with Elm
0.19.1): the generated decoder runs at ports and flags only (`:190-335`), `Json.Decode.Value` defers to a
hand-written decoder, and no ordinary function, public or private, is ever guarded (the interior is trusted
because one language checked it). Elm's lesson is the ticket 18 already drew: check at the one door you own.

## Measurements

B#-emitted, one generated module, K=8 functions per kind, four compilers differing only in guard scope
(`59_size.sh`; exact, deterministic, one build each so no n). Code chunk = `beam_lib` "Code" payload.

| quantity | result | ticket/18/26a quoted |
|---|---|---|
| tag test, private record fns, HEAD-EXP | 220 B over 16 fns = **13.75 B**/test, 2 instrs each | +14 B |
| tag test, 3 fields vs 8 fields (8 fns each) | 13.5 B vs 13.5 B | flat |
| tag test, exported+private, HEAD-NOTAG | 443 B over 32 = 13.8 B/test | |
| `is_integer`, private int fns, ALL-HEAD | 31 B over 8 = **3.88 B**/test, 1 instr | +3-5 B |
| `.beam` file bytes per tag test | 668/16 = 41.8 B (includes the abstract_code chunk B# keeps) | not quoted |
| `is_integer` kept on private fns across the corpus (ALL) | 9 added in abstract code, **0 B** Code delta (23 beams, 12 private fns) | |
| split stub+twin (Erlang) | 89 -> 102 B Code (+13 B) | |

Call time, ns per iteration (`59_time.sh`, 1e7 iterations x **n=15** runs, round-robin across variants;
`59_time_erlang.sh` independent Erlang control, same n and iterations). Private self-recursive loop, so every
iteration re-enters the guarded function.

| loop | variant | min | median | max |
|---|---|---|---|---|
| record, private (B#) | HEAD (tag test) | 6.473 | 8.175 | 11.020 |
| | EXP / private test removed | 2.005 | 2.510 | 3.429 |
| | ALL | 6.305 | 7.730 | 10.526 |
| | NOTAG | 2.296 | 2.788 | 6.440 |
| int, private (B#) | HEAD (no test) | 1.013 | 1.269 | 2.111 |
| | ALL (is_integer on n, acc) | 1.042 | 1.268 | 1.915 |
| Erlang control, record | unguarded / tag-guarded | 2.326 / 6.185 | 3.137 / 7.968 | 5.825 / 9.243 |
| Erlang control, int | unguarded / guarded | 0.954 / 0.979 | 1.237 / 1.309 | 1.720 / 1.444 |

Tag test: **+4.5 ns (B#) / +3.9 ns (Erlang) by min, +5.7 / +4.8 by median** -- larger than the unguarded run's
min-to-max spread, so resolved. `is_integer`: +0.03 ns (B#) / +0.03 ns (Erlang) by min, inside the spread,
consistent with 18's +-0.09. Not measured: native-code size under the JIT; other OTP releases or architectures;
a realistic workload (these loops have no body); compile time (the guards add one instruction to the emitted
forms, not measured); the F37 range comparisons' call time on a private function.

## Options

All three answer the one gating question. The runtime outcome differs; **no B# program is refused by one answer
and accepted by the other** (the checker is untouched), so the "refused" half below is the runtime
`function_clause`, which is what a guard is.

The program (`59_reach/G/g.bs`, compiles under all three):
```csharp
record Order   { Id: int, Total: int }
record Wrapper { Id: int, Inner: Order }
int Priv(Order o)
Priv(o) -> o.Total
public int ViaNested(Wrapper w)
ViaNested(w) -> Priv(w.Inner)
public int ViaIntList(list<int> xs)
ViaIntList([x, .._]) -> PrivI(x)        // int PrivI(int n) -> n
```
Forged from Erlang, `ViaNested(#{Kind=>'G.Wrapper', Inner=>#{Kind=>'G.Invoice', Id=>1, Total=>5}})` and `ViaIntList([1.5])`.

**A. Exported only, for all four guards (delete the private tag test).** Measured on the patched copy `EXP`:
`ViaNested` -> `ok 5`, `ViaList`/`ViaTuple` -> `ok 5`, `ViaIntList([1.5])` -> `ok 1.5`. Compiler delta: one clause in
`bs_emit:guard_one/7`, `{ok, _} when not Public -> {Pat, []}` (`59_uniform_exported_only.patch`, 1 line); update
the comment at `bs_emit.erl` "The record tag guard above is emitted on private functions too; that asymmetry is
deliberate"; rewrite F24 s3. Saves 13.75 B and ~4 ns per private record call; the corpus has none to save.
*Strongest counterargument, as its proponent would put it:* "18 s4 is explicit, and it was bought for a reason:
whole-module analysis lets an edit to one file move another file's boundary, so the unit is the exported
function. Function-local means the door, and the door's gap is the *depth* gap, which 46 s4 already owes a
fixed-projection fix for. The private tag test is not a design, it is an accident that catches one forgery
(wrong tag) in one shape (a record parameter) and none of the others (F4: floats, ranges), nor any payload (F5);
keeping it tells authors the interior is guarded when it is not. One rule, stated once, that you can explain in a
sentence, and the depth hole is a named, tracked limit rather than an arbitrary half-cover."

**B. Every function that consumes a typed parameter, for all four guards (add the kind/range tests to private
functions).** Measured on the patched copy `ALL`: `ViaIntList([1.5])`, `ViaOctList([300])` and `ViaOctList([1.5])`
-> `function_clause`; the tag rows are as HEAD. Compiler delta: `59_uniform_all_functions.patch`, `none when Public ->`
becomes `none ->` in `guard_one/7` (one line); `Public` stays threaded for nothing else, so the `Public` argument of
`boundary_guards/6` and `clause/4` and the `is_public/1` read in `function/2` would be unused (not tried); rewrite the
"Exported only" paragraphs of F24 s2/s3 and F37.5, and 46 s1's and 58's "dead weight" sentence, and 18 s1's cost
paragraph (F7). Cost: private `is_integer` is elided by
`erlc` where the caller proves it (0 B across the corpus, F7) and costs 3.88 B / ~0 ns where it protects; the
private tag test is not elided, so a private self-recursive record function pays ~4 ns per call (a 3x slowdown of
an empty loop) and 13.75 B. *Strongest counterargument:* "You are putting a map lookup in the hot path of every
private helper to cover an edge that the language should close properly. A private tail-recursive function over a
record re-tests the tag on every iteration (F8: 6.5 vs 2.0 ns), `erlc` cannot elide it, and one entry label means
you cannot guard only the first entry. And it does not even close the hole: payloads (F5) still pass, and the
tag test cannot see inside a list of records either, only the one element that reaches a record parameter. You
would be paying for the appearance of the guarantee."

**C. Exported only, but the door guards what it hands on (18 s4's own sentence, extended through projections).**
18 s4 says *"a value handed to another function counts as unchecked, and is guarded"*; `Priv(w.Inner)` hands a value
on, and C guards `Inner`'s tag at `ViaNested`'s entry. Not prototyped; not measured. Concretely: `guard_one/7` walks
the declared type one projection deep for closed-record fields and tuple components (46 s4's "fixed number of
projections", F24 s5 owed), plus `ViaNested`'s clause analysis (`accepts/3`) learning which projections reach a call.
**It cannot cover `list<Order>`:** guarding elements is O(n), violating 18 s2's one-guard-O(1) rule, so `ViaList`
stays silent under C (F2 row 2 has no door-side fix). *Strongest counterargument:* "It is the only option that
keeps 18 s4's function-local, exported-door principle and fixes the hole, but it is new analysis the compiler does
not have, it leaves list elements and payloads open, and until it lands you are choosing between A's hole and a
deferral; a ticket that decides C has decided to build something, not to change one line."

## Recommendation

**B.** The gating answer: 18 s4's "exported" is too narrow *as a statement of where a guard may go*, because 18 s4
defines when an exported function guards its **own** parameters and never says a private consumer must be bare;
the sentence "site 1 has already rejected it" that justified F24/F37/46/58 is false for interior values (F2, F4).
Reasons, all measured here: (1) the hole exists for all four guards and A leaves it open for tag, float, range and
int alike while B closes the first-order ones (F2, F4); (2) the list-element case cannot be closed at the door at
O(1), so a use-site test is the only cheap defence that exists today; (3) the cost is small and mostly self-eliding:
0 B across the corpus for kind/range, 3.88 B where it protects, and 13.75 B / ~4 ns for the tag (F7, F8), against the
ticket's own "too narrow is a silent hole, too wide is measurable and loud"; (4) 18 s1(d) already says the burden
is on omission. B also removes the inconsistency without a new analysis. C is the better long-term door and is
compatible with B (C adds door tests, B keeps the use-site backstop); B does not preclude it.

What would change my mind: a realistic workload where the private tag test costs more than, say, 5% (the loops
here have no body, so this is an upper bound that was not tested on real code); a finding that private functions
dominate real corpora (then A's saving is real, today the corpus has zero private record functions); or David
deciding that 46 s4 projections will land soon and lists of records are acceptable to leave open, which makes C
plus A the cleaner story.

## Probe log

Changed after the first run (all rerun, final `.out` files are from the last version):
- `59_reach` started with records only; the int (H) and Octet (I) shapes were added after seeing the record rows, to
  test whether the hole was tag-specific (it is not, F4). The record rows did not change.
- `59_checker_refuses`: a `map_literal` case was dropped; it failed with a syntax error of mine (`syntax error before: ':'`),
  not a refusal, so it tested nothing.
- `59_uniform_all_functions.patch` and `59_no_tag_test.patch` did not build at first (`warnings_as_errors`: unused
  `Public`, shadowed clause); rewritten until they built, before any measurement.
- `59_time.escript`: added a `max` column after the first run (spread was needed to judge resolution); the means did
  not change.
- `59_gleam.sh`: Gleam 1.19 writes `.abstr`, not `.erl`; the generated-code section now prints `beam_disasm` instead.
- `59_elixir.exs`: struct literals outside a module failed to compile; the runner moved into `defmodule Runner`.
- `59_entry_label.sh`: first behaviour block had an unbound variable and an `ExpT` parser of mine that was wrong;
  replaced by `59_call.escript` and `beam_disasm` exports.

Surprises (against my first expectation): (1) `erlc` removes the private `is_integer` when the caller proves it, so
B's kind/range cost is zero on the corpus; I expected a few bytes. (2) The tag test is ~4 ns, not "nothing
measurable". (3) The corpus has no private record function at all. (4) Gleam field access has no tag test even on
`pub` functions. (5) The ticket's "forged through an exported function" is impossible for `term`, unions and narrowed
terms, and possible only through an aggregate's interior.

Not run: Elm (registry 403). Not measured: JIT native size, real-workload cost, compile time, range-test call time.

## Probe index

All: `cd /home/user/beam-sharp/artifacts/probes && ./NAME` (each sources `env.sh` and builds its patched compilers into a
fresh temp dir via `59_lib.sh`, ~55 s on a clean shell; set `V59_DIR` to reuse). Outputs saved beside each as `.out`.

| probe | command | output that REFUTES the claim |
|---|---|---|
| `59_reach.sh` | `./59_reach.sh` | EXP shows `function_clause` for `ViaNested`/`ViaList`/`ViaTuple` Invoice-tagged rows (F2); ALL shows `ok` for `ViaIntList [1.5]` (F4) |
| `59_checker_refuses.sh` | `./59_checker_refuses.sh` | any bad program (`term_passed_on`, `term_narrowed`, `union_passed_on`) printing `exit=0`; a CONTROL printing `exit=1` (F3) |
| `59_entry_label.sh` | `./59_entry_label.sh` | `OuterExp [[1.5]]` returning `ok`; export label of `Inner` differing from the `call_only` target (F6) |
| `59_split_entry.sh` | `./59_split_entry.sh` | `two` raising on local `outer([1.5])`, or `one` not raising (F6 corollary) |
| `59_elision.sh` | `./59_elision.sh` | `PI/1` containing `is_integer`, or `PU/1`/`PR1/1` lacking its test (F7) |
| `59_size.sh` | `./59_size.sh` | per-test deltas outside 14+-2 B (tag) / 3-5 B (int); 3-field vs 8-field delta differing (F8) |
| `59_time.sh` | `./59_time.sh` | HEAD-minus-EXP record-loop gap smaller than EXP's min-to-max spread; ALL-minus-HEAD int-loop gap above the spread (F8) |
| `59_time_erlang.sh` | `./59_time_erlang.sh` | tag-guarded min within the unguarded min-to-max spread (F8 control) |
| `59_corpus.sh` | `./59_corpus.sh` (~3 min) | any row with a non-zero Code delta under ALL-HEAD, or a private tag test (F7, corpus claim) |
| `59_gleam.sh` | `./59_gleam.sh` | any forged call raising `function_clause`, or an `is_integer`/`element(1)` test in a prologue (Neighbours) |
| `59_elixir.sh` | `./59_elixir.sh` | `nopattern`/`pub_untagged` raising; `%Order{}` rejecting `total: "str"`; `@enforce_keys` blocking the update (Neighbours) |
| `59_erlang_survey.sh` | `./59_erlang_survey.sh` | `spec_only(1.5)` raising; `via_nested(#invoice)` returning (Neighbours) |

Helpers: `59_lib.sh`, `59_guards.escript`, `59_forge.escript`, `59_call.escript`, `59_disasm.escript`, `59_asm.escript`,
`59_expt.escript`, `59_size.escript`, `59_time.escript`; patches `59_uniform_exported_only.patch`,
`59_uniform_all_functions.patch`, `59_no_tag_test.patch` (apply with `patch -p1` to a copy of `compiler/`; the repo's
`compiler/` was never touched).
