# Brief for ticket 59 (ENG-241): does a private function get a boundary guard?

Decision brief only. Nothing under `wayfinder/` or `compiler/` was edited, Linear was not touched, nothing committed.
Probes: `artifacts/probes/59/` (`bash artifacts/probes/59/run.sh`, ~1 min, exits non-zero on a failed expectation).
`bsc` cannot be built here, so every statement about what `bsc` emits is **read from `compiler/src/bs_emit.erl` at
`8d56f53`** or **cited from a ticket's own measurement**, and labelled so. B# snippets below are not run.

## 1. Question and the gating sub-decision

The ticket asks: is the record tag test on a private function a defect against 18 §4, or is 18 §4's "exported" too narrow?
Its two sides both rest on one unstated premise, which is the gating question and the only one asked here:

> **Does a value reaching a private function always arrive through a checked B# call site whose argument the exported
> boundary already examined?**

If yes, every private guard is dead weight and the ticket's "defect" side wins (Option A). If no, "private" is not a
reason to skip a guard (Option B). The premise is false in three ways, each probed below (section 2): a **sub-term** the
exported guard never looked at, a **list element**, and an **escaped function value** (F46). This is *not* the argument
the ticket gives for the "not a defect" side. The ticket reads 18 §4 as "the callee guards because the caller's analysis
stopped at its boundary". 18 §4's sentence says the opposite place: a value handed on whole makes the *exported* function
carry the guard (probe row `w1`). What the private test catches is the part of the value the exported guard cannot see.

Follows from it, not asked separately: whether `is_integer`, `is_float` and the range test widen too (F24, F37 say
exported-only; they rest on the same premise); the F3.9 wording; and which of 18 §4, 46 §1, 58, F24 §2-3, F37.5 are amended.

## 2. Evidence

All probes OTP 25.3 (`erlang:system_info(emu_flavor)` = `jit`), not the repo's pinned 28.5.

| claim | probe / citation | result | status |
|---|---|---|---|
| bsc emits the tag test with no visibility check | `bs_emit.erl:267-275` (`guard_one`: `record_tag` branch never reads `Public`); `Public` is read only at 276 | confirmed; same as 46's measurement | read from source, not run |
| bsc has **three** scopes, not two | `bs_emit.erl:276-280` int + float kinds + range: `none when Public`; tag 268-275: all; | the asymmetry is wider than the ticket's table: `kind_tested/2` (def 693) and `strip_rels/2` (def 616; call sites 194, 175) never consult `Public`, but take `IntOnly`/`skips` from the declared type, so a private int-only parameter is skipped: the narrowing `is_integer` lands on private functions only for union parameters (F24 §6's `T = int | atom`) | read, not run |
| "private: every call site is a checked B# call site" is the stated premise | `bs_emit.erl:170-173`, 321-325; F24 §2; F37.5; 46 §1 | premise is about static types | read |
| one entry label serves local and remote calls | `p1_elision.sh` E1/E1b: `caller/1`'s `call_only,1,{f,2}` jumps to the label holding `is_integer` | **reproduces 18a §4(a)** | measured here |
| "a non-exported function has the guard elided entirely" | P1 E2 (caller tests it), E4 (literal arg), E5 (arg is a guarded call's result), E6, E7 (private recursive loop): `is_integer=0` | true **only when an in-module caller's own test is visible to erlc** | measured here |
| ... and when no test is visible | P1 E3 (caller passes an untested arg): `is_integer=1` in the local function | guard kept | measured here |
| ... for the **tag test** | P1 T2: local `f` with `map_get(kind,M) == order`, caller tests the same thing: `tagtest=1`; `#{kind := order}` pattern form T4 also kept | **contradicts the ticket's reading of 18**: erlc does not elide a map tag test in a local function even when the caller just did it | measured here |
| ... for the **range test** | P1 R1: local `f` with `X >= 0, X =< 255`, caller tests it: `cmp=2`, is_integer=0 | I predicted 0 and was wrong; assertion changed after seeing it. Kind elided, range kept | measured here |
| a forged value reaches a private function through an exported one | P3 `p3_forge.sh`, table in section 4 | rows c2, l2, f1, f2: silent under A, `function_clause` under B | measured here (hand-written model of bsc's shape) |
| a forged **whole** value passed on is caught at the export, private test is dead | P3 row w1 | `function_clause` under both | measured here |
| tag test is +14 B flat (26a) | P2 sizes, N=1/5/20 | **+12 B Code, +2 instrs, identical at N=1,5,20** (26a: +14 B on OTP 28.5; body differs) | measured here |
| `is_integer` is +3-5 B (18a) | P2 | +5 B, +1 instr | measured here |
| call cost "below ±0.09 ns resolution" (18a) | P2 timing, min of 15 x 10^7 | **not reproducible here**: byte-identical-code modules differ by 0.25 to 3.97 ns between runs (several runs, two sessions). Observed spread of the tag-test delta: N=5 -0.63..+4.0 (sign flips: UNRESOLVED); N=20 +1.95..+8.09, positive in every run (direction holds, magnitude does not). `is_integer`: -1.1..+2.2, UNRESOLVED | measured here, VM noisy |
| the tag test is flat in cost | P2 | flat in **bytes**; in **time** it grows with fields as a direction at N=20 only: `map_get` scans a flat map's keys (OTP flat map up to 32 keys), and `Kind` sorts last among these atoms (worst case) | measured here, position caveat |
| Elixir `defp` heads checked like `def` | `p4_elixir.sh` | `FunctionClauseError` for a forged `%Vendor{}` reaching a `defp %Customer{}` head, and for 1.5 at a `defp ... when is_integer` | measured here |
| Gleam emits no guard for pub or private | `p5_gleam.sh` (Gleam 1.12.0): 0 `when` in generated `.erl`; both get `-spec` | forged `{vendor,...}` through `ship/1` returns `<<"v">>`; `add(1.5, 2.5)` returns `5.0` | measured here |
| Erlang authors guard exported functions ~2x as often | `p6_erlang_practice.escript`: stdlib+kernel abstract code | exported 19.8% (760/3845), local 9.9% (768/7729) with a type test in some clause | measured here; counts guards only; "private callers already validated" (the premise in dispute) explains the 2x equally well, so it cannot arbitrate A vs B |

## 3. Neighbour survey

**Erlang.** Emits nothing the author did not write; `-spec` is Dialyzer-only. Authors type-guard exported functions about
twice as often as local ones (P6: 19.8% vs 9.9%, OTP 25 stdlib+kernel, from abstract code since the `.erl` sources are not
installed here). erlc then removes a local guard only when it can see the caller prove it (P1 E2-E7), never for a map
tag test or an integer range. Precedent for "private guards are rarer", none for "private guards are wrong"; the count cannot tell convention from "callers already validated".

**Elixir 1.14.** No boundary concept. `defp` and `def` heads are the same clause machinery (P4): a `%Struct{}` pattern or
`is_integer` guard in a `defp` raises `FunctionClauseError` exactly as in a `def`. The author chooses per function; the
language does not scope by visibility. Not a precedent for any compiler-emitted guard.

**Gleam 1.12.** Emits no guard for either `pub` or private functions and a `-spec` for both (P5). A forged
`{vendor, <<"v">>}` passed as the `customer` field of an `Order` reaches the private `notify` and returns silently, and
`add(1.5, 2.5)` returns `5.0`. This is ticket 18's measured Gleam outcome (18 §2) reproduced on this version. Gleam is the
"A for everything, and for exported too" end, which is the position 18 rejected.

**Elm.** N/A for this question. Elm has no runtime guards inside the program; it checks only at the port door
(`research/18-elm-port-validation.md`, Elm 0.19.1 source, cited from ticket 18, not re-run). With one door there is no
exported/private distinction to scope a guard by, which is exactly what the BEAM lacks.

## 4. Measurements

**P3, the semantic crux** (`forge_b.erl` = Option B, private guarded; `forge_a.erl` = Option A, private unguarded; the
only differences are four deleted `when` clauses). Output of `p3_forge.sh`:

```
case                                                 B: private guarded         A: private unguarded
c1 right shape                                       {ok,<<"a@x">>}             {ok,<<"a@x">>}
w1 WHOLE value forged (Invoice-tagged), passed on    {error,function_clause}    {error,function_clause}
c2 sub-term: Vendor-tagged, same fields (DDD)        {error,function_clause}    {ok,<<"v@x">>}          <- silent
c3 sub-term: right tag, payload Email=42             {ok,42}                    {ok,42}                 <- neither
c4 sub-term: Customer is a binary                    {error,function_clause}    {error,badmap}
c5 sub-term: Customer map without Email              {error,badkey}             {error,badkey}
l2 list element Invoice-tagged, same fields          {error,function_clause}    {ok,12}                 <- silent
l3 list element not a map                            {error,function_clause}    {error,badmap}
f1 escaped fun (private Notify) <- Vendor-tagged     {error,function_clause}    {ok,<<"v@x">>}          <- silent
f2 escaped fun (private Dbl) <- 1.5                  {error,function_clause}    {ok,3.0}                <- silent
```

Reading it: the private test changes the outcome from silent to a crash exactly in the DDD case 26 §1 minted the tag for
(same fields, different identity: c2, l2, f1). Where the wrong term is not a map or lacks the field the body already
crashes (c4, c5, l3: outcome 2, the class changes from `badmap` to `function_clause` and nothing else). It does **not**
catch payload forgery (c3), which 18 §3 already names as the limit of a tag test. Row f2 is the **int** guard: a private
`int Dbl(int n)` handed out as a value (`Rule(:staff) -> Free` is F46's own example, `F46-function-as-a-value.md` lines
56 (`Rule(:staff) -> Free`), 65 (`private int Free`), `Doubled(xs) -> List.Map(xs, Double/1)` at 72, `private int Double` at 77) accepts `1.5` from a foreign caller today.

Why the exported boundary cannot cover rows c2/l2: `boundary_guards/6` zips over the **parameters** only
(`bs_emit.erl:257-262`), so `o.Customer` is never tested; 46 §4 decided "a fixed number of projections" and F24 §5 lists it
as unbuilt; and 46 §4 refuses a collection outright (O(n) in a length the caller chooses), so list elements will never be
tested at the boundary under any decided rule.

**P2, cost** (one function projecting the last of N fields; `p2_cost.sh`): Code-chunk delta vs unguarded.

| guard | N=1 | N=5 | N=20 | instrs |
|---|---|---|---|---|
| tag, `map_get(kind,M) == order` guard (bsc's form, 582-586) | +12 B | +12 B | +12 B | +2 |
| tag, `#{kind := order}` head pattern | +18 B | +18 B | +18 B | +3 |
| exact field set (control, grows) | +24 B | +28 B | +55 B | +4 |
| `is_integer` | +5 B | | | +1 |

Term size: the `Kind` key adds **2 words** at N=1, 5 and 20 (flat). Time, observed spread over the runs (noise between identical modules up to 3.97 ns): tag guard N=5 -0.63..+4.0 ns
(unresolved); N=20 +1.95..+8.09 ns (positive every run: "costs more with more fields" holds as a direction only).
`is_integer` -1.1..+2.2 ns (unresolved). The head-pattern form ranged -4.5..+4.5 ns: no claim about it.

**Dead-weight cost of the private tag test when the caller already tested** (the ticket's "defect" side): real and
unremovable by erlc (P1 T2). Per private call on a record parameter: the +12 B and one extra `map_get` lookup.

## 5. Options

The compiled program that decides it (one B# program, two outcomes):

```csharp
record Customer { Email: string }
record Order    { Id: int, Customer: Customer, Amount: int }

public string Ship(Order o)         // exported: tag test on `o` only
Ship(o) -> Notify(o.Customer)

private string Notify(Customer c)
Notify(c) -> c.Email

public int Total(list<Order> os)    // list parameter: no boundary guard
Total([]) -> 0
Total([o, ..t]) -> Price(o) + Total(t)

private int Price(Order o)
Price(o) -> o.Amount

public fn(Customer) -> string Rule()  // F46: a private function leaves as a value
Rule() -> Notify
```

`Ship(%{Kind: :'Shop.Order', Customer: %{Kind: :'Shop.Vendor', Email: "v@x"}})` from Erlang, Elixir or a decoded term returns
`"v@x"` under A and raises `function_clause` under B. Same for a `Vendor`-tagged element of `Total`'s list and for `Rule()`
applied to a Vendor. `Ship` and `Total` compile in both worlds; the checker accepted every call site.

### Option A: private functions carry no boundary guard of any kind

Compiles to (the shape in `forge_a.erl`): `notify(C) -> map_get('Email', C).`, `price(O) -> map_get('Amount', O).`
Compiler delta, concrete: `bs_emit.erl:268` becomes `{ok, Tag} when Public ->`, with a `{ok, _} -> {Pat, []}` private
clause; the `none when Public` branch at 276 stays. Update `records_tests` (F3.9 text already says "exported record
parameter", so the code is brought to the text), add a private-record test beside `boundary_kind_tests` F24.6 (line 88),
rewrite F37.5's and F24 §3's "asymmetry" paragraphs. One line of code. The texts that scope guards to exported (18 §4, 46 §1, 58, F24 §2, F37.5, F3.9 wording) agree with it. Two decided texts cut the other way: ticket 18 lines 194-195, *"Restricting omission to non-exported functions is not an alternative — a foreign value entering through an exported function reaches private ones unchallenged"* (said of the failure-arm saving; it states B's premise, so it cuts against A), and F24 §6 (lines 187-211), which documents a silent private-`Tag` hole in the int channel, patched at the narrowing site (a second instance of the same failure, against A). On A's side, 18 line 615 ("interior functions already pay nothing — the shape C wanted") rests on the conditional elision of section 2. The erlc cost it removes is real (P1 T2: not elided; +12 B, one lookup per private call).
Evidence against: rows c2, l2, f1, f2 above are silent outcome 3 under A, which is the one outcome 18 exists to prevent
(`18 "never silently"`), and A also leaves today's *int* hole (f2) open.
**Strongest counterargument:** A follows the scoping texts above, and the holes it leaves are narrower
than they look: they need a sub-term the exported guard skips, and those were already owed by 46 §4's projection guard.
If projection guards are built, c2 closes; only collections (l2) and escaped funs (f1, f2) stay open, both rarer. That
argues A *plus* the owed work, not the status quo.

### Option B: every function carries the guards its own body would not object to, visibility is not a scope

The rule stated once: a guard is emitted wherever the clause's own pattern and body would not object (18 §1's rule C,
applied function-locally exactly as 18 §4 already says), on every function. Compiles to: `notify(C) when map_get('Kind', C)
== 'Shop.Customer' -> ...` (as today), and for `private int Dbl(int n)`: `dbl(N) when erlang:is_integer(N) -> N * 2.`
Compiler delta: delete the `Public` argument threaded through `clause/4` (161), `function/2` (155), the call at 187,
`boundary_guards/6` (257, 259) and `guard_one/7` (267); `none when Public` (276) becomes `none`; `float_guard/3` and
`int_guard/6` (range included, F37) then run on private functions. Invert `boundary_kind_tests` F24.6 (88-97) and
`boundary_range_tests` F37.5 (120-); amend 18 §4, 46 §1, F24 §2-3, F37.5 and F3.9's wording. Net new emitted code is the
int/float/range tests on private parameters only; the tag test is unchanged.
Cost, measured: the private `is_integer` is removed by erlc only when **every** in-module caller proves it (P1 E2, E4-E7, including a
private tail-recursive loop; the verifier's k1 probe: one proving and one untested caller keeps the test), and not when the
function escapes as `fun f/N` (an unknown caller exists), which is exactly row f2, the case where B's int test matters. Otherwise
+5 B and one instruction (time unresolved). The
**range** comparisons are *not* removed (P1 R1: `cmp=2`), so a private refined-int parameter pays two comparisons per call.
The tag test is +12 B and a lookup per private call, flat in bytes, growing in time with field count (direction only at 20 fields; unresolved at 5).
The corpus count of added tests (F24 §4 counted 34 `is_integer` insertions on exported-only) cannot be run here.
**Strongest counterargument:** B reverses a rule five artefacts cite as settled (two others, 18:194-195 and F24 §6, point the other way) and each of F24, F37 and 46 argued the
guard "dead weight" on private functions; it adds a visible cost to exactly the functions the author wrote as internal
hot-path helpers (range comparisons are not elided), and it still does not close the payload channel (c3), so it
claims no more than "the tag", and 18 §3 already refused to claim a defence one level deep.

Not offered as options: tracing which private functions are actually reached with unexamined values (a guard that appears
or disappears when another file of the module changes) is what 18 §4's "function-local" and "one function per file"
reasoning already rejected. A guard emitted only on private functions that are referenced `fun f/N` has the same blast
radius for the same reason.

## 6. Recommendation

**Option B.** The premise A needs ("private values were already examined") is false in three runnable ways (c2/l2, f1/f2),
and the only rule that can be stated once and come closer to 18's "never silently" is the one that does not scope by
visibility. B reduces the holes; it does not close them (verifier's k2 probe: a forged float sub-term used inline, `o.Amount + 1`,
stays silent under B and is caught only if handed to a private int function, so B's int coverage depends on how the author
factored the code; closing it is 46 §4's owed projection guard). B's tag half is already today's behaviour: rows c2/l2/f1
argue against *changing* the tag to A, and what B newly buys is the int/float/range tests (f2 and its sub-term analogue). The cost evidence favours it for kinds (erlc erases an `is_integer` only when every caller proves it, as in the private
recursive loop E7; otherwise +5 B, time unresolved) and it merely stops the tag test being the odd one out; the range test is the one
real new cost, and it is two comparisons. The ticket's own two arguments both fall short: "dead weight" is true only for a
whole value passed on, and "caller analysis stops at its boundary" misreads 18 §4, which puts that guard on the exported
function (row w1).

What would change my mind: (1) a corpus run of B on `bsc` + OTP 28 showing the private range/tag tests land on hot
paths (OTP 26+ improved `beam_ssa_type` map handling, so my T2 non-elision could be different on 28.5); (2) the 46 §4
projection guard being built *and* David deciding that collection elements and escaped funs stay outside "never
silently", which makes A sound for what it promises; (3) David preferring the 5-artefact consistency of A over closing
c2/l2/f1/f2 now. The owed projection guard is the stronger long-term fix for c2 and is independent of this decision.

## 7. Not verified here / limits

- `bsc` cannot be built (lexer needs OTP 26+ leex, no rebar3). Every "bsc emits" is read from `bs_emit.erl` or cited
  from 46 ("measured, a private `Inner(Order o)` receives the tag test", cited, not re-run). `forge_a/b.erl` are
  hand-written models of that shape, not compiler output; they prove what the BEAM does with the shape, not what bsc emits.
- OTP 25.3.2.8 here, not 28.5. erlc's type-based elision (P1) and the timing may differ on 28.5; 26a (+14 B) and 18a
  (+3..5 B, ±0.09 ns) were OTP 28.5 arm64; mine are 12 B / 5 B on this x86 JIT VM.
- Timing is noisy (identical-code spread 0.25 to 3.55 ns between runs); only the tag test at 20 fields is consistently
  resolved. 18a's ±0.09 ns resolution did not reproduce here, so it is not confirmed or refuted.
- Not checked: F46's escape was shown in an Erlang model with `fun f/1`; I did not run a B# program (can't) so the
  claim that a foreign caller can apply the returned fun rests on F46's emitted `fun 'Free'/1` (cited) plus P3 f1/f2.
- Erlang stdlib `.erl` sources are not installed; P6 reads abstract code (debug_info) of 183 stdlib and kernel beams.
- Elm: not probed; cited from `research/18-elm-port-validation.md` and marked N/A for this question.
- Corpus effect of Option B (how many private parameters gain a test) and a Dialyzer pass on the new guards: not run.
- Probe prediction miss, recorded: R1 expected `cmp=0`, observed `cmp=2`; the assertion was changed after seeing the result.
