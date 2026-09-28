# Decision brief: ticket 59 (ENG-241), the boundary guard's two scopes

Read-only research. Nothing under `wayfinder/` or `compiler/` was touched; Linear was not touched. `bsc` cannot be built here
(OTP 25 leex lacks TokenLoc), so **no probe runs bsc**. "Analogue" below means hand-written Erlang in the shape of
`bs_emit.erl:576-580` (tag test) and `:488-489` (is_integer), compiled with erlc on OTP 25. Labels: **MEASURED** (probe, cite
`probes/<file>.out`), **SOURCE** (file:line), **RECORDED** (a ticket/README says so, not re-run), **UNVERIFIED**.
Regenerate everything with `sh probes/run.sh`; every probe carries its PREDICTION in the header, written before its first run.

## Question

`bs_emit` emits the record TAG test on every function, private included, and the int KIND test (and float, and range) on
exported functions only (SOURCE `bs_emit.erl:261-277`, `guard_one/8`; the only `Public` consult is `:270`).
Is the private tag test a defect against 18 section 4, or is "exported" too narrow?

## Sub-decisions

a. Defect against 18 sec 4, or is 'exported' too narrow?  b. Is 'exported' the right discriminator?
c. One scope for every boundary guard, stated once.  d. Cost if it widens (kind/range on private) vs narrows (tag off on private).

## Four findings that reframe the ticket

1. **The ticket's "not a defect" argument names the wrong path.** It says a forged record reaches a private function "by being
   passed through an exported one". On that path (`top`: exported `E(Order o)` hands its own parameter to private `P`) the exported
   tag test has already thrown, so the private test is dead. MEASURED: identical outcome guard off/on, all four forgeries,
   all three body kinds (`p04_hole.out`, `top` rows). The ticket's "defect" argument is right for that path.
2. **Three other paths do reach a private function unchecked**, and there the private guard is the *only* defence. MEASURED
   (`p04_hole.out`): (nested) exported takes a wrapper and passes `w.Order`, which the exported test never inspects; (escape) an
   exported function returns `fun p/1`; (many) `lists:map(fun p/1, L)` over a list parameter. A wrong-kind same-fields record
   returns the forged record's field silently (`ok:7`, `ok:[3,7]`, `ok:true`) with the guard off, and `function_clause` at `p/1` with
   it on. The int analogue gives `ok:3.0` for `q(1.5)` with `N*2`, and `ok:low`/`ok:reserved` for a float/atom/binary into a
   `Classify`-shaped comparison. This is 18's "outcome 3", inside a private function.
3. **18 sec 4's premise "a private function's every call site is a checked B# call site" (RECORDED `F24-boundary-kind.md:115-116`,
   `F37`) stopped being true when F46 landed.** F46 hands out a private function as a value: `Rule(:staff) -> Free` lowers to
   `fun 'Free'/1` and `List.Map(xs, Double/1)` to `bs@List@Map@2(Xs, fun 'Double'/1)` (RECORDED `F46-function-as-a-value.md:93-98`,
   `:65-77`). The lowering is SOURCE `bs_emit.erl:1036-1040`. F24 and F37 cite the premise as the reason the kind/range tests are
   exported-only; both were written before F46.
4. **The ticket's cost premise ("elided entirely" on a non-exported function, RECORDED `18-boundary-defence.md:611-616`) holds for
   `is_integer` and for nothing else.** MEASURED (`p01_shapes.out` B): private + caller proved integer: test gone (+0 B); private +
   caller ran the *same* range test: the `is_integer` goes but both comparisons stay (+13 B); private + caller ran the *same* tag
   test, or built the literal, or passed a nested field: tag test kept (+12 B). OTP 25's type lattice knows "is a map" and
   "is an integer", not "the `Kind` key is `'Order'`" and not the range. So "private pays nothing" is true of the kind test
   and false of the tag and range tests.

Naming drift, for whoever edits: 46 says `boundary_guards/4`, F24/59 say `/5`; the source is `/6` (SOURCE `bs_emit.erl:251`).

## Evidence table

| claim | label | source |
|---|---|---|
| tag test = `erlang:map_get('Kind', V) =:= Tag`; unconditional on a single closed record type; skipped if the head pins `Kind` | SOURCE | `bs_emit.erl:261-269, 576-580, 1306` |
| kind/float tests only `when Public`; private falls to `{Pat, []}` | SOURCE | `bs_emit.erl:270-277` |
| range test lives in `int_guard`, same exported-only gate | SOURCE | `bs_emit.erl:322-340` |
| every clause gets the guard (per clause, not per function) | SOURCE | `bs_emit.erl:150, 155-181` |
| the comment claims "that asymmetry is deliberate" | SOURCE | `bs_emit.erl:316-319` |
| no test pins the private tag test; F3.9 covers exported `Pay` only | SOURCE | `compiler/test/records_tests.erl:123-130`; grep of `compiler/test` for `map_get` |
| tests that pin private = unguarded for kind and range | SOURCE | `boundary_kind_tests.erl:88-98` (F24.6), `boundary_range_tests.erl:122-131` (F37.5), comment `guard_kind_tests.erl:14` |
| private function is emitted, `-spec`'d, left out of `-export` | SOURCE | `bs_emit.erl:32-35` |
| tag test +12 B Code (OTP 25 x86-64); ticket says +14 (28.5 arm64) | MEASURED-analogue | `p01_shapes.out` A |
| `is_integer` +5 B, `is_float` +3, int+range 0..255 +18; ticket says +3-5 | MEASURED-analogue | `p01_shapes.out` A |
| private guard KEPT if the caller is unknown; ELIDED (is_integer) if caller proved integer or passed a literal | MEASURED-analogue | `p01_shapes.out` B |
| exported guard always KEPT, even when the in-module caller proved it (agrees with 18a sec 4a) | MEASURED-analogue | `p01_shapes.out` B control |
| private tag test kept in all four caller contexts; private range comparisons kept (+13 B) when caller ran the same range test | MEASURED-analogue | `p01_shapes.out` B |
| private recursive record loop, tag test per clause: **+7.6 to +8.1 ns/iteration** on a 12.0 ns loop (+63%); noise floor <0.1 ns; asm shows one extra `map_get`+`is_eq_exact` per iteration | MEASURED-analogue | `p03_time.out` (r_priv_*) |
| same loop when the record is rebuilt each turn: +7.6 to +9.2 ns | MEASURED-analogue | `p03_time.out` (u_priv_*) |
| private int loop, caller proves ints: +0.01 to +0.07 ns (twin noise 0.05), loop asm has no `is_integer` | MEASURED-analogue | `p03_time.out` (i_priv_g) |
| private int loop, caller unknown: +0.1 to +0.16 ns | MEASURED-analogue | `p03_time.out` (i_priv_gU) |
| exported int loop pays per iteration (`call_only` re-enters the guarded label): +0.5 to +0.85 ns | MEASURED-analogue | `p03_time.out` (i_ex_g) |
| single exported call, `is_integer`: -0.3 to +0.12 ns, inside the noise floor; agrees with 18 | MEASURED-analogue | `p03_time.out` (s_int_*) |
| single exported call, tag: +1.5 to +3.1 ns over four runs; clears the twin noise floor in three, not in one (twin noise 1.6 ns), so **only weakly resolved on this VM** | MEASURED-analogue | `p03_time.out` (s_tag_*) |
| ticket 26's "the tag itself costs nothing measurable" | RECORDED | `26-data-modelling.md:309-312` compares tuple-guarded (7.04) to tagged-map-guarded (8.78), not guarded vs unguarded. The loop result above disagrees with reading it as "tag is free" |
| forged values: which paths a private guard defends (findings 1-2) | MEASURED-analogue | `p04_hole.out` |
| escape-site wrapper `fun(O) when TAG -> p(O) end` defends `escape` and `many`, not `nested`, `top` unchanged | MEASURED-analogue | `p04_hole.out` (`wrap` column) |
| wrapper costs +25 B (tag) / +18 B (int) per escape site; guard on p costs +12 / +5 once | MEASURED-analogue | `p01_shapes.out` C |
| Dialyzer: a forged literal into a private spec'd function is reported (`breaks the contract`); into an exported one, reported when caller and callee are analysed together; via `binary_to_term`, nested field, or escaped fun: silent | MEASURED | `p05_dialyzer.out` |
| Dialyzer narrows a LOCAL function's domain to its visible callers (`is_integer(X) can never succeed`) but not an exported one, **and not a local one whose address is taken** | MEASURED | `p05_dialyzer.out` (D4, line `d3.erl:8`) |
| Elixir: `def e(%Order{})` and `defp p(%Order{})` both carry the author-written `#{'__struct__' := 'Elixir.Order'}` head pattern; a forged bare map with that key passes; `@enforce_keys` runs only at construction (`struct!`) | MEASURED | `p06_elixir.out` |
| Elixir: private `q` with `is_integer` behind a guarded public `r` has 0 `is_integer` tests after compile, `r` has 1 | MEASURED | `p06_elixir.out` |
| Elixir has no rule that scopes struct-pattern tests by def/defp; the author writes them wherever wanted (not compiler-injected) | MEASURED (pattern is in the head of both) | `p06_elixir.out` |
| corpus: 30 of 188 private functions and 32 of 161 public take a record parameter; 71 private and 36 public take an `int` (regex over `git ls-files '*.bs'`, lower bound for kinds, 160 files incl. prototypes) | SOURCE-approximate | `p08_corpus_count.out` |
| 18 sec 4 is function-local so an edit in one file cannot move another file's emitted guard | RECORDED | `18-boundary-defence.md:815-846` |
| Gleam | not probed | |
| Elm | `elm make` cannot fetch packages here (proxy 403, no cache); nothing claimed | `p07_elm.out` |

## The rule the three options differ on

A guard belongs wherever a value can enter a function without having passed a B# call-site check. Today that is: every exported head,
every private head reached by a fun (F46), and every private head reached by a value that was only *statically* typed (a nested field,
a list element; 46 sec 4 / F24 sec 5 already own "guard below the top of a parameter"). Options differ in how much of that they emit.

## Option 1: Narrow. The tag test follows 18 sec 4 to the letter (exported only)

```csharp
module Shop
record Order { Id: int, Total: int }

int Bill(Order o)                      // private
Bill(o) -> o.Total

public int Pay(Order o)
Pay(o) -> Bill(o)

public list<int> Totals(list<Order> os)
Totals(os) -> List.Map(os, Bill/1)
```

Emitted Erlang (derived by hand from `bs_emit.erl:576-580`, not bsc output):

```erlang
'Pay'(O)    when erlang:map_get('Kind', O) =:= 'Shop.Order' -> 'Bill'(O).
'Bill'(O)   -> erlang:map_get('Total', O).                       %% was: same guard as Pay
'Totals'(Os) -> bs@List@Map@2(Os, fun 'Bill'/1).
```

Compiler delta (SOURCE): in `guard_one/8` add before `bs_emit.erl:263`: `{ok, _} when not Public -> {Pat, []};`. `Public` is already
threaded (`:149 -> :155 -> :181 -> :251 -> :261`), so no signature change. Delete the "asymmetry is deliberate" comment (`:316-319`),
fix the banner (`:238-249`). No existing test flips (see table); add a failing test first, sibling to F3.9 (`records_tests.erl:123`):
`a_private_record_parameter_gets_no_tag_test`. UNVERIFIED: whether any `compiler/bin/check-*.sh` gate encodes a private tag test
(not run; a grep of `private` in the boundary gates found nothing).

Evidence: removes +12 B per clause (about 30 corpus functions, more clauses) and the +7.6 ns/iteration in private record loops.
After it, one rule holds across tag, kind, float and range.

**Strongest counterargument.** It ratifies a leak instead of closing it: `Totals([forged])` returns `[3,7]`, i.e. Bill(Invoice) answers
as if it were an Order (MEASURED `p04_hole.out`, `many`/`escape`/`nested` rows, guard off). The private tag test is currently the only
thing that stops that, and 26 sec 1's reason ("no body checks which record a map claims to be") is still true inside `Bill`. The tag
guard exists *because* a body cannot object; narrowing it removes a defence that F46 made necessary.

## Option 2: Widen. Every boundary guard on every function

```csharp
int Double(int n)                      // private
Double(n) -> n * 2
public list<int> Doubled(list<int> xs)
Doubled(xs) -> List.Map(xs, Double/1)
```

```erlang
'Double'(N) when erlang:is_integer(N) -> N * 2.                  %% new: was unguarded
```

Compiler delta (SOURCE): `bs_emit.erl:270` `none when Public ->` becomes `none ->` and the fallback `none -> {Pat, []}` (`:276-277`) goes;
`Public` disappears from `guard_one/8`, `boundary_guards/6` (`:251`), `clause/4` (`:155`, `:181`) and `function/2` (`:149`). `IntOnly`
(`:168`) stays: it is still what stops a second test after the boundary one. Tests that flip, red first: `boundary_kind_tests.erl:88-98`
(Inner `is_integer` 0 -> 1) and `boundary_range_tests.erl:122-131` (Inner `=< 255` 0 -> 1); comment `guard_kind_tests.erl:14`;
scenario rows F24.6 and F37.5; F24 sec 2-3 and 18 sec 4 amended. Adds a float guard to private `float` params (0 in the corpus).

Evidence: closes every path in finding 2 for tag, kind, float and range. Cost is very uneven, which is the real content of sub-decision (d):

| guard on a private function | Code bytes | per-call/iteration | BEAM takes it back when the caller proved it? |
|---|---|---|---|
| kind (`is_integer`) | +5 | +0.0 to +0.16 ns | yes, entirely (MEASURED p01, p03) |
| range 0..255 | +13 to +18 | not timed | no, comparisons stay on OTP 25 (MEASURED p01) |
| record tag | +12 | **+7.6 to +8.1 ns per loop turn** | no (MEASURED p01, p03) |

**Strongest counterargument.** The tag and range tests are never elided, so widening charges every private record loop about 60% and
every private refined-int helper 13 bytes, permanently, to defend against values that reach a private function only through the
escape, nested and list paths. Widening pays that price on all private call paths to cover a minority of them, and all of it lands on
the private functions where authors put their inner loops (MEASURED `p03_time.out` i_ex_g: an exported recursive function already pays its guard per iteration).
The ticket's "too wide is measurable and loud" is right, and here it is measurable and mostly not loud.

## Option 3: Guard the door, not the room. Exported heads and escape sites

Same B# as Option 1. The rule, stated once: **a boundary guard is emitted where a function becomes enterable from outside the checked
call graph: at an exported head, and at a site that takes a private function's address.** Private heads carry no guard of their own.

```erlang
'Pay'(O)     when erlang:map_get('Kind', O) =:= 'Shop.Order' -> 'Bill'(O).
'Bill'(O)    -> erlang:map_get('Total', O).
'Totals'(Os) -> bs@List@Map@2(Os, fun(A1) when erlang:map_get('Kind', A1) =:= 'Shop.Order' -> 'Bill'(A1) end).
```

Compiler delta (SOURCE): Option 1's one-line change, plus in `expr({e_fname, ...})` at `bs_emit.erl:1036-1040`, when the target is a
private local function with a guardable parameter, emit a `{'fun', L, {clauses, [{clause, L, Vars, [Guard], [call Name Vars]}]}}` instead of
`fun Name/Arity`. New work: a `fn_params` table in `Ctx` keyed `{Name, Arity}` (built beside `validator_table`, `:35-45`, since
`fnames` carries only the arity) and `guard_one/8`'s test-building factored so the head and the escape site share it. Locality
survives: the guard is derived from the callee's declared signature, not its body, so it moves only when someone edits a signature
(UNVERIFIED that 18 sec 4's blast-radius argument agrees; it was about body analysis). Tests, red first: an escaped private record
function and an escaped private `int` function each emit the guard at the site and none in the head; a directly-called private function
stays unguarded.

Evidence (MEASURED-analogue, `p04_hole.out` `wrap` column): the wrapper turns `escape` and `many` from silent `ok:7`/`ok:3.0`/`ok:reserved`
into `function_clause`; `nested` is unchanged from Option 1 (still silent); `top` is unchanged. It costs +25 B (tag) / +18 B (int) per
escape *site* (`p01_shapes.out` C), nothing per direct call, and no per-iteration cost in private loops. Dialyzer draws the same line:
it treats a local function as closed-world *only while its address is not taken* (MEASURED `p05_dialyzer.out` D4).

**Strongest counterargument.** It is new emitter machinery for a channel the corpus barely uses (F46's examples are two escapes), and it
still leaves `nested` open: `Bill(w.Order)` with a forged field is a private *direct* call, and no scope rule reaches it. That path
is closed only by the "guard below the top of a parameter" work already owed by 46 sec 4 / F24 sec 5, at the exported door and at
whatever price that ticket sets. If David judges F46 escapes rare enough, Option 3 is Option 1 plus a maintenance liability.

## Recommendation

**Option 3, built in two steps, and amend 18 sec 4 in the same sentence.** Answers to the four sub-decisions:

- (a) Both are true. The private tag test *is* a defect against 18 sec 4's letter on every direct call (`top`, the only path the
  ticket named, is dead weight, MEASURED). 18 sec 4's "exported" is *also* too narrow, because F46 made private functions
  enterable by address after 18/F24/F37 were written; the private guard is the only defence on `escape` and `many` (MEASURED).
- (b) "Exported" is the right discriminator for a direct call and the wrong one for an address-taken function. The BEAM's own
  discriminator ("exported vs local") is correct as recorded but does not do the elision this ticket credited to it: it elides only
  the kind test (MEASURED).
- (c) One rule: guard at every entry from outside the checked call graph (an exported head, an escape site). Written once, in 18 sec 4.
- (d) Widening is cheap for kind (0 B when proved, +0.0 to +0.16 ns) and expensive for tag and range (never elided, +7.6 to +8.1 ns per
  private record-loop turn). Narrowing saves that and re-opens a hole that is already open for kind and range.

Step 1 (small, this ticket's feature): Option 1's one-line change plus its test, so the two rules finally agree; F24 sec 3 and the
`bs_emit.erl:316-319` comment are corrected. Step 2 (a new feature, red test and gate first per CLAUDE.md): the escape-site guard.
If David prefers no new emitter work now, stop after step 1 and raise the F46 escape channel as its own ticket, so the leak is
recorded and not silently inherited (the same standard F24 held itself to). Nothing here decides `nested`; that belongs to 46 sec 4.

## What I could not verify here

- **bsc itself.** Nothing was compiled by bsc; every emitted-Erlang block above is hand-derived from `bs_emit.erl`, and every MEASURED-analogue
  number assumes the analogue is faithful (guard form and `andalso` join from SOURCE; one guard per clause; `debug_info` on, bsc adds
  `from_abstr`). The `boundary_*` gates and the test suite were not run, so "no existing test flips" is a grep, not a run.
- **OTP 25 vs 28.5.** Tickets 18 and 26 measured OTP 28.5 arm64 (RECORDED). Sizes agree closely (tag +12 vs +14, `is_integer` +5 vs +3-5).
  Whether OTP 28's `beam_ssa_type` elides the range comparisons or tracks `Kind` values is UNVERIFIED; if it does, Option 2's tag and range
  rows get cheaper and the case for Option 3 weakens. The JIT differs too (x86-64 here). Re-run `probes/run.sh` on 28 before deciding on cost alone.
- **Timing noise.** Shared 4-core VM, 25 rounds interleaved, twin-variant noise floors printed. The loop deltas (+7.6 ns) sit far above it; the
  single-call tag delta (+1.5 to +3.1 ns) cleared it in three of four runs and is reported as weakly resolved. Term size is not affected by guards; none was measured.
- **Gleam:** not installed (denied), not probed. **Elm:** `elm make` cannot reach the package server (403), so no Elm claim.
- **Dialyzer** ran on a minimal PLT (erts, kernel, stdlib) built locally; it says nothing about B#, only about how the BEAM ecosystem's checker scopes local vs exported.
- **Corpus counts** (`p08`) are a regex over 160 `.bs` files including prototypes, not bsc's parser; they size the change, they do not prove it.
- **Contradictions with the ticket.** (1) Its "elided entirely" premise is true of `is_integer` only; the tag test is never elided and range
  comparisons survive (`p01_shapes.out` B). (2) Its "passed through an exported function" path is the one where the private guard is dead
  (`p04_hole.out` `top`). (3) Its "18 sec 4 makes private call sites checked" premise is broken by F46 escapes. (4) `boundary_guards/4` and `/5`
  in tickets 46/59 are `/6` in source. (5) Its 26a cost figure (+14 B) is +12 B on OTP 25; the "tag costs nothing measurable" reading of 26 is not
  supported by the loop measurement.
