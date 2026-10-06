# Brief: ticket 59, the boundary guard applies two rules with different scopes

Ticket: `wayfinder/issues/59-boundary-guard-scope-asymmetry.md`, [ENG-241](https://linear.app/davewil/issue/ENG-241).
Status when read: open. This brief resolves nothing. Probes are in `artifacts/probes/59/`; each has a
captured `.out` next to it. A separate verifier should re-run them.

## What the ticket asks

`bs_emit:guard_one/8` (called from `boundary_guards/6`, `compiler/src/bs_emit.erl:265-290`) gives a
private function the record tag test but not the int kind test. 18 §4 says the analysis is
*"the exported function's own clause heads and body, and no further"*. The tag test contradicts
that; the kind test (F24) obeys it. The ticket asks which scope is right, stated once for both,
whether "exported" is the right discriminator at all, and what widening would cost.

## Stale or wrong premises (read these first)

1. **The asymmetry still exists, unchanged** (re-run today against the current `$BSC`):
   private `InnerTotal(Order o)` has `when map_get('Kind', O) =:= 'Scope.Order'`; private
   `InnerInt(int n)` has no `is_integer`; exported `OuterInt` has it
   (`59a_asymmetry_rerun.out`, four PASS lines including two controls).
2. **"A private function's every call site is a checked beam-sharp call site" is false** in two
   ways, both executed:
   - the *value* arriving at a private function can be unproven even when the *call site* is B#:
     an element of an exported `list<Order>`, or a field of an exported `Box`. 18 §2 checks the
     shallow part of a parameter only (`59b`: `ViaBox`, `ViaList`, `ViaInts`).
   - the call site can be foreign: a private function captured as a fun value and handed to
     `:lists.map` is called by Erlang, not by checked B# (`59b`: `Hof:Run([1.5])` returns `[2.5]`
     today).
3. **The ticket's reading of 18 §4's sentence does not match what the compiler does.** The ticket
   says the private callee guards "because the caller's analysis stopped at its own boundary". But
   18 §4's sentence (*"a value handed to another function counts as unchecked, and is guarded"*)
   puts the guard on the **exported** function, and it does: `ViaTotal(Order o) -> InnerTotal(o)`
   emits the tag test on `ViaTotal` itself (`59a.out`). For a direct pass-through the private test
   is a duplicate. The private test only does work for values that were never a parameter of the
   exported function: nested fields, list elements.
4. **18's "the same code un-exported has the test elided entirely" is true only when the BEAM
   compiler can prove the caller's type.** Under a compiler that emits `is_integer` on private
   functions, the test vanishes from `Scope:InnerInt` (sole caller already guarded) and stays in
   `Forge:Plus1` (fed by a list element) and in the exported control. The tag test is never
   elided, because the optimiser has no record types (`59f.out`). So "private pays nothing" is not
   a property of the BEAM; it is a property of what B# emits.
5. **Numbers re-measured** (`59c`, `59d`): the ticket's "+14 bytes tag" is 12 bytes of `Code`
   chunk for one private function and 13.2 on average over ten (instructions 21 to 19, and 125 to
   105). `is_integer` is +5 bytes where it survives and exactly 0 where the optimiser removes it.
   The ticket's "below ±0.09 ns/call" does not reproduce on this VM: the noise floor here is about
   ±1.3 ns/call, so only the tag test (about +2.4 ns on a 15.8 ns call) is resolvable and the
   `is_integer` cost is not.
6. **The corpus does not decide this.** `compiler/examples` has 15 private signatures and none
   takes a record parameter (`59i.out`). Narrowing changes 0 compiled modules; widening changes 1
   (`Shop/Pricing`, +9 bytes of Code) (`59h.out`).

## Sub-decisions

1. **Gate: what is a boundary guard for?** The foreign boundary only (shallow, at exported
   functions), or every function that can receive an unproven term? Everything else follows from
   this, so it is asked alone below.
2. Follows from 1, only if the answer is "wherever an unproven term can arrive": is *exported* the
   right discriminator, or *exported or captured as a fun value*? (Not built; see Not verified.)
3. Follows from 1: what text in 18 §4, F24 §2/§3, F3.9 and the `bs_emit.erl:330-333` comment changes,
   so the scope is stated once. No new decision; list only.

## Sub-decision 1: which scope, for both guards

All three options are the same B# program. It is `probes/59/src/Forge/forge.bs`; the three
compilers differ only in `guard_one`.

```csharp
module Forge

record Order   { Id: int, Total: int }
record Invoice { Id: int, Total: int }
record Box     { Item: Order }

int Total(Order o)
Total(o) -> o.Total

int Plus1(int n)
Plus1(n) -> n + 1

public int ViaBox(Box b)
ViaBox(b) -> Total(b.Item)               // forgery one level down

public int ViaInts(list<int> xs)
ViaInts([n, ..t]) -> Plus1(n) + ViaInts(t)   // float one level down

public int Inline(Box b)
Inline(b) -> var i = b.Item
             i.Total                      // same forgery, no helper
```

Called from Erlang with `Box{Item = Invoice{Total = 5}}`, `[1.5]`, and (Elixir gives the same terms):

| call | A: no private guards | B: both on private | C: today |
|---|---|---|---|
| `ViaBox(Box{Item=Invoice})` | `5` | `function_clause` | `function_clause` |
| `ViaList([Invoice])` | `5` | `function_clause` | `function_clause` |
| `ViaInts([1.5])` | `2.5` | `function_clause` | `2.5` |
| `Hof:Run([1.5])` (private fn via `lists:map`) | `[2.5]` | `function_clause` | `[2.5]` |
| `Inline(Box{Item=Invoice})` | `5` | `5` | `5` |
| `ViaOrder(Invoice)` (exported own param) | `function_clause` | `function_clause` | `function_clause` |

(`59b_forgery.out`. `ViaOrder` and `Inline` are the controls: the first is caught everywhere, the
second by no variant.)

### Option A: the guard is at the exported function and nowhere else

Rule, one sentence: *a boundary guard is emitted on an exported function's own parameters; a
private function is never guarded.* The record side moves to match the int side.

Compiler delta: one clause in `guard_one/8`, ahead of the tag clause:

```erlang
    case record_tag(TypeExpr, Ctx) of
        {ok, _Tag} when not Public -> {Pat, []};   % new
        {ok, Tag} -> ...
```

That is exactly the `narrow` variant `lib.sh` builds. Also: replace the "that asymmetry is
deliberate" comment (`bs_emit.erl:330-333`) with the one sentence; change F24 §3 and ticket 46's note;
add one F3 test (private record parameter, tag test absent, exported control present) beside
`a_private_function_is_not_guarded_test` (`compiler/test/boundary_kind_tests.erl:88`). No
existing test I found pins the private tag test (grepped `compiler/test`).

Evidence: 12 bytes of Code and 2 instructions per private record function (`59c`), about 2.4 ns
less per call (`59d`, `ViaList` min 15.8 to 13.4, noise at about 1.3). Corpus: 0 modules change
(`59h`). Behaviour: the `ViaBox`, `ViaList` rows go from `function_clause` to a silent `5`.

Strongest counterargument: it removes a check that fires today. `ViaBox(forged)` is an outcome-3
"wrong answer, no crash" in exactly the sense ticket 06 calls the thing to avoid, and 18's whole
cost argument was "too narrow is a silent hole, too wide is measurable and loud". Against that:
the same program with the body written inline (`Inline`) is silent under every option, so under
today's compiler whether a forged field crashes depends on whether the author factored a helper.
That is the edit-at-a-distance effect 18 §4 rejected for whole-aggregate analysis.

### Option B: guard every function

Rule: *a boundary guard is emitted on every function's parameters.* The int side moves to match
the record side, and so do the float test and the range test, which share the same branch.

Compiler delta: in `guard_one/8`, change `none when Public ->` to `none ->` and delete the final
`none -> {Pat, []}` clause (the `widen` variant; I used `sed` for this and it compiled). Because
`int_guard/6` and `float_guard/3` live in that branch, the range tests of F37 are widened too.
Tests to invert: `a_private_function_is_not_guarded_test` (`boundary_kind_tests.erl:88`),
F24.6, `a_private_function_carries_no_range_guard_test` (`boundary_range_tests.erl:122`,
F37.5). Text to amend: 18 §4 (*"exported function's own clause heads"*), 46 §1, 58, F24 §2.

Evidence: where the caller proves the type, `Code` is byte-identical to today (md5 equal over the
`Many` program and 26 of 27 corpus modules); where it does not (`Forge:Plus1`, list-element fed)
the test stays, +5 bytes (`59c`, `59f`). Corpus: 1 of 27 modules changes, `Shop/Pricing`, +9 bytes
(`59h`). Run time: not resolvable above the noise (`59d`: `ViaInts` cur 12.5, widen 12.3 min).
Behaviour: closes `ViaInts([1.5])` and `Hof:Run([1.5])`.

Strongest counterargument: it advertises protection it cannot give. `Inline` is still silent, so
"private functions are defended" is false the moment the value is used in the body rather than
passed on, and the program's behaviour still changes when a helper is factored in or out. It also
reverses a decision three tickets deliberately made (18 §4, 46, 58) to fix an inconsistency that
no corpus program exhibits.

### Option C: keep today's split and write down why

Rule: *the tag test is an identity check no body performs (26 §1), so it is unconditional; the
kind test follows 18 §4.* No compiler change except the comment.

Strongest counterargument: the reason for the tag test is 18 §1 rule C case (b) applied to a check
no body makes, and case (b) is exactly the argument for the int test (`n + 1` on a float is
silent). The same deep forgery is caught for a record and missed for an int (`ViaBox` versus
`ViaInts` in the table), so the split tracks the parameter's *type*, not its *risk*. This option
keeps the inconsistency the ticket was raised to remove, and gives it a sentence.

### Recommendation: A

A keeps one rule that matches 18 §4, 46, 58 and F24 as written. The private tag test is not
18 §4 working (premise 3): the exported function already guards a direct pass-through, and the
test only ever caught forgeries that nothing guards in an `Inline` body, so it is protection by
accident of factoring. The real hole is shallow-only guarding of nested values, which is 18 §2's
two-step crossing (`ValidateAs`) and a separate question; B and C both leave it open while
advertising otherwise. B is the fair alternative if David weights "never silently" above one-sentence
scope: it is cheap (0 bytes where provable, +5 where not, 1 of 27 corpus modules) and loud only in
the direction the ticket says is acceptable. Choose A or B; do not keep C.

## How neighbouring languages treat it

| language | private versus exported argument checking | source |
|---|---|---|
| Gleam | No runtime check on either. `public_total` and `inner_total` both emit `erlang:element(3, O)`; a forged `{invoice,1,5}` returns `5` from the public function. | `59g_neighbours.out` (built with `gleam build`, Gleam 1.18.1) |
| Erlang | `-spec` is not enforced at any scope (`pub_spec(1.5)` returns `2.5`); a guard is enforced at any scope and is the author's choice. OTP's own `lists:seq/2` guards `is_integer` on the exported head and `seq_loop/3` (local) compares unchecked: `lists.erl:477-481`. | `59g.out`, `stdlib-7.3/src/lists.erl:477` (`when is_integer(First), is_integer(Last)`), `:481` (`seq_loop(N, X, L) when N >= 4`) |
| Elixir | `def` and `defp` are checked identically (not at all); a `%O{}` pattern in a `defp` head is the author's opt-in and raises `FunctionClauseError`. | `59g.out` |
| OTP and Elixir stdlib as practised | Local-only functions are defended less than exported ones: stdlib+kernel 10.6% of local parameter positions against 16.7% of exported; Elixir 7.6% against 26.4%. The control reproduces ticket 18's recorded 7606 exported positions. | `59e_platform_census.out` |
| Elm | Not probed: `package.elm-lang.org` is unreachable here, so `elm make` cannot run. The repo's own `wayfinder/research/18-elm-port-validation.md` covers ports only and says nothing about private functions; I did not re-verify it. | `59g.out` last lines |

No neighbouring language has an analogue of an *automatic* guard that depends on visibility: the
only precedent for "private pays less" is that authors write fewer guards there by hand.

## Probe index

| probe | claim | result | control |
|---|---|---|---|
| `59a_asymmetry_rerun.sh` | private record fn has the tag test; private int fn has no `is_integer`; final BEAM keeps the tag test | confirmed, four PASS | exported `OuterTotal` and `OuterInt` carry both |
| `59b_forgery.sh` | a forged nested record, list element and a private fn called by `lists:map` reach private functions past the exported guard | confirmed for A, B, C as tabled; Elixir caller gives the same | `ViaOrder` caught by all; `Inline` caught by none; tier-2 bad field caught by none |
| `59c_size.sh` | tag test +12 to +13 bytes of Code; `is_integer` +5 or 0 | K=1: 181 / 169 / 181 bytes (cur / narrow / widen); K=10: 1110 / 978 / 1110; Forge: 328 / 316 / 333. Sizes identical over N=5 compiles | cur versus cur Code md5 equal |
| `59d_calltime.sh` | tag test about 2.4 ns/call; `is_integer` cost unresolved | `ViaList` min 15.8 (cur), 15.6 (cur2), 13.4 (narrow), 15.4 (widen); `ViaInts` min 12.5, 12.4, 13.7 (narrow, same code as cur), 12.3 | `cur2` is the noise floor; `narrow` on `ViaInts` is identical code and differs by 1.2, so floor is about 1.3 |
| `59e_platform_census.sh` | platform code guards locals less than exports | confirmed (numbers above) | reproduces 18b's 7606 |
| `59f_optimiser_elision.sh` | optimiser removes a private `is_integer` only when the caller proves it; never the tag test | `InnerInt` false, `Plus1` true, `OuterInt` true, `InnerTotal` tag true | exported control true |
| `59g_neighbours.sh` | Gleam, Erlang, Elixir have no visibility-dependent check | confirmed; Elm not probed | author guards raise in Erlang and Elixir |
| `59h_corpus.sh` | corpus effect of each option | 27 modules compiled: narrow changes 0, widen changes 1 | cur versus cur2 changes 0 |
| `59i_corpus_private_census.sh` | corpus has no private record functions | 15 private signatures, 0 with a record; 9 with int/float | public signatures: 10 with a record, 33 with int/float |

Variant compilers are built from a copy of `compiler/src/bs_emit.erl` into a temp directory; nothing
under `compiler/` was edited.

## Not verified

- **Elm**: not run (package fetch blocked). No claim about Elm is made beyond the pointer above.
- **Sub-decision 2 (guard a private function that is captured as a fun value)**: I showed such a
  function is reachable with unproven arguments (`Hof:Run`), but I did not build the checker
  change (a "captured" mark on the symbol table, set where a name is read in value position, and
  `Public orelse Captured` in `guard_one`), so its cost is unmeasured.
- **`widen` also enables the float and range tests on private functions**: read from the code
  (`guard_one`, `int_guard`, `owed_arms`), not separately probed.
- **Run-time cost of the `is_integer` test**: unresolvable at this noise level (VM shared, ±1.3 ns).
  Only the tag test's +2.4 ns is above it. JIT code size was not measured; byte counts are the
  BEAM `Code` chunk. `beam_lib:strip` output was reported in `59c.out` but is smaller than the Code
  chunk for reasons I did not investigate, so I rely on the Code chunk and instruction counts.
- **The `compiler/examples/exemplars/` programs do not compile** (out of the walking-skeleton
  slice) so they are not in the corpus numbers.
- **Mailbox, ETS and `code_change` channels into private functions**: not probed. 18 §3 treats
  them separately.
- Nothing here has been checked by anyone but me.
