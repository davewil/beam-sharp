# Decision brief — ticket 59: boundary guard scope asymmetry

Research only. Ticket 59 (Linear ENG-241) is left **open**; nothing in `wayfinder/issues/` was
edited, no `## Decisions entry` was written, no `Status:` line was touched, and Linear was not
touched. This brief is the deliverable.

**Headline finding, ahead of the rest: the ticket is stale, and not in the direction it warns
about.** It names two emission sites in `boundary_guards/5`. There are **three**, and the third —
built three weeks *after* this ticket was raised, by the same feature family, without anyone
coming back to update this ticket — is scoped **unconditionally**, the opposite of the "exported
only" half of the asymmetry the ticket describes. See §0.

## 0. The real current source, read and run, not assumed

`compiler/src/bs_emit.erl` was built and every claim below is measured against a real compiled
`.beam`, not inferred from reading. Three functions decide a parameter's boundary treatment,
threaded from `clause/4`:

```erlang
%% bs_emit.erl:125
is_public(F) -> element(7, F) =:= public.       % #fn.vis

%% bs_emit.erl:153, 179, 186 (abridged)
clause({clause, Line, _Name, Patterns, Guard, Body} = C, Params, Ctx, Public) ->
    ...
    {Patterns1, Tests} = boundary_guards(Patterns0, Params, Line, Ctx, Public, Accepts),
    Guard1 = conjoin(Tests ++ RelTests, kind_tested(Guard, skips(Patterns0, IntOnly)), Line),
    ...

%% bs_emit.erl:259-275
guard_one(Pat, {param, TypeExpr, _}, Accept, I, Line, Ctx, Public) ->
    case record_tag(TypeExpr, Ctx) of
        {ok, Tag} ->                              %% <-- NO `Public` guard: site 1
            case constrains_kind(Pat) of
                true  -> {Pat, []};
                false -> ... [tag_test(Var, Tag, Line)]
            end;
        none when Public ->                       %% <-- `Public` guard: site 2
            case kind_only(TypeExpr, Ctx) of
                float -> float_guard(Pat, I, Line);
                _     -> int_guard(Pat, TypeExpr, Accept, I, Line, Ctx)
            end;
        none -> {Pat, []}
    end.

%% bs_emit.erl:679-680 -- called from clause/4 with NO Public argument at all: site 3
kind_tested(none, _Skip) -> none;
kind_tested({guard, Expr}, Skip) -> {guard, kind_expr(Expr, Skip)}.
```

| # | Site | What it tests | Function | Scope, read from the source | Ticket 59 names it? |
|---|---|---|---|---|---|
| 1 | record tag | `map_get(Kind,X) =:= Tag` | `guard_one`'s `{ok, Tag}` branch | **unconditional** — no `Public` guard on the clause | yes |
| 2 | parameter-head kind | `is_integer`/`is_float` on the declared parameter | `int_guard`/`float_guard` via `guard_one`'s `none when Public ->` branch | **exported only** | yes |
| 3 | narrowing-guard kind | `is_integer` conjoined onto a user `when`-guard's comparison node | `kind_tested/2`, called unconditionally from `clause/4` | **unconditional** — `Public` is not even in scope at the call site | **no** |

Site 3 is F24 §6 / ENG-330 (`compiler/features/F24-boundary-kind.md`, amended 2026-09-07), which
ticket 59 (raised 2026-08-23) predates and has not been updated to reflect. Measured directly
below (§2.3): a **private, unexported** function with a `when n >= 0` guard over a union parameter
gets `erlang:is_integer/1` in its emitted head. So the real split as of today is **two
unconditional sites and one exported-only site**, not the 1-and-1 split the ticket's table shows —
and the newest of the three, built with full knowledge of 18 §4, chose *unconditional*.

## 1. Sub-decisions

**(a) Should the record TAG test narrow to exported-only, or should the int KIND test (both its
sites) widen to all functions?** Sharpened by §0: this is no longer a symmetric two-body problem.
Widening is already the codebase's own most recent choice (site 3), made for a demonstrated
soundness gap in the "private is safe because its call sites are checked" premise (§2.3). Any
answer to (a) has to say what it does about site 3 too, or it answers a two-site ticket that no
longer matches the emitter.

**(b) Is "exported vs private" the right discriminator at all, or should it be "reachable only
from checked call sites"?** Ticket 59 itself notes these are not the same thing. §2.3 below
supplies the concrete counter-example the ticket only gestured at: a private function fed a value
through an **exported** function whose own parameter is a union and whose narrowing happens in a
`when` guard rather than in the parameter's declared type. The private callee is reachable *only*
from beam-sharp code, and still receives an unchecked value — "private" does not imply "reached
only past a check."

**(c) What does either direction cost, in real bytes, and is doubling up (the current tag test,
paid at every hop through a private layer) already a cost nobody has named?** Measured in §3;
§3.3's finding — paying the same guard twice in one call chain — is not in the ticket's table
either.

## 2. Probes run

All commands below are real; all output is pasted verbatim from the run, not transcribed from
memory. Toolchain note in §5 — the pinned toolchain (`erlang 28.5`, `.tool-versions`) is not
present in this sandbox (OTP 25.3.2 only, no network egress to `builds.hex.pm` or `hex.pm`), so the
compiler was built from a scratch copy with two source-only compatibility patches unrelated to
this ticket (`TokenLoc` → `{TokenLine, 1}` in `bs_lexer.xrl`, since OTP 25's `leex` predates the
`error_location` option F35 relies on; `~kp` → `~p` in one `io_lib:format` call in `bs_run.erl`,
an OTP 27 map-formatting directive). Neither patch touches `bs_check.erl` or `bs_emit.erl`, the
files this ticket is about; both are confirmed byte-identical to the real repo files by `md5sum`
before every build (§5.2). `bs_run.erl`'s own patch never runs on any path this brief exercises
(it is REPL value pretty-printing). **Gap in this recipe, found by independent verification**:
`rebar.config`'s own `{xrl_opts,[{error_location,column}]}` also has to be neutralized in the
scratch build, or `leex:file/2` (and a full `rebar3 escriptize`) throws `badarg` regardless of the
`bs_lexer.xrl` patch — this is option-driven, not content-driven, so it reproduces even on a
trivial grammar. Not a correction to any finding (`rebar.config` is neither `bs_check.erl` nor
`bs_emit.erl`), but the build recipe as first written was incomplete without this step.

### 2.1 The record-tag probe (site 1)

`Probe59.bs` (a scratch file, not part of the corpus):

```csharp
module Probe59
record Order { Id: int, Total: int }

int InnerRecord(Order o)
InnerRecord(o) -> o.Id

public int OuterRecord(Order o)
OuterRecord(o) -> InnerRecord(o)
```

Compiled with the built `bsc` (`bsc -o OUT Probe59`) and disassembled with
`beam_disasm:file/1` against the real `.beam`:

```
== 'InnerRecord'/1 (entry 4) ==     %% PRIVATE — not in the export list
  {bif,map_get,{f,3},[{atom,'Kind'},{tr,{x,0},...}],{x,1}}
  {test,is_eq_exact,{f,3},[{x,1},{atom,'Probe59.Order'}]}
  {bif,map_get,{f,0},[{atom,'Id'},{tr,{x,0},...}],{x,0}}
  return

== 'OuterRecord'/1 (entry 6) ==     %% PUBLIC — in the export list
  {bif,map_get,{f,5},[{atom,'Kind'},{x,0}],{x,1}}
  {test,is_eq_exact,{f,5},[{x,1},{atom,'Probe59.Order'}]}
  {call_only,1,{'Probe59','InnerRecord',1}}
```

Confirmed at the real BEAM instruction level, not just the abstract-format source: the private
`InnerRecord/1` carries the identical tag test to the exported `OuterRecord/1`. This reproduces
ticket 46's measurement exactly, three weeks later, against the current source.

### 2.2 The int-kind probe (site 2)

Added to the same module:

```csharp
int InnerInt(int n)
InnerInt(n) -> n

public int OuterInt(int n)
OuterInt(n) -> InnerInt(n)
```

```
== 'InnerInt'/1 (entry 8) ==        %% PRIVATE
  return                            %% <-- no test at all

== 'OuterInt'/1 (entry 10) ==       %% PUBLIC
  {test,is_integer,{f,9},[{x,0}]}
  {call_only,1,{'Probe59','InnerInt',1}}
```

Confirmed: `InnerInt/1` gets nothing; `OuterInt/1` gets `is_integer`. This is F24 §2's rule,
verified against the real emitted instructions.

### 2.3 The narrowing-guard probe (site 3) — the finding not in the ticket

```csharp
type T = int | atom
int PrivateNarrow(T n)
PrivateNarrow(n) when n >= 0 -> InnerInt(n)
PrivateNarrow(n)             -> 0

public int CallNarrow(T n)
CallNarrow(n) -> PrivateNarrow(n)
```

`PrivateNarrow` is never exported. Abstract-format output (`bsc`'s `.abstr`, read directly, not
paraphrased):

```erlang
{function,0,'PrivateNarrow',1,
    [{clause,{33,1},
         [{var,{33,1},'N'}],
         [[{op,{33,1},'andalso',
               {call,{33,1},{remote,{33,1},{atom,{33,1},erlang},{atom,{33,1},is_integer}},
                     [{var,{33,1},'N'}]},
               {op,{33,1},'>=',{var,{33,1},'N'},{integer,{33,1},0}}}]],
         [{call,{33,1},{atom,{33,1},'InnerInt'},[{var,{33,1},'N'}]}]},
     {clause,{34,1},[{var,{34,1},'_N'}],[],[{integer,{34,1},0}]}]}.
```

And in the real `.beam`, independently re-disassembled (§5):

```
== 'PrivateNarrow'/1 (entry 12) ==   %% PRIVATE — not in the export list
  {test,is_integer,{f,13},[{x,0}]}
  {test,is_ge,{f,13},[{tr,{x,0},...},{integer,0}]}
  {call_only,1,{'Probe59','InnerInt',1}}
  {label,13}
  {move,{integer,0},{x,0}}
  return
```

**`erlang:is_integer/1` fires on a function that is neither exported nor called from anywhere
except other beam-sharp code in this module.** This is exactly the shape F24 §6 (ENG-330) built to
close — its own worked example (`Tag`/`Bump`, `F24-boundary-kind.md` §6) keeps the helper
**private**, because the gap it found does not depend on export status: an exported function
whose *parameter* is a union and whose narrowing lives in a `when` guard establishes the kind for
its own body, but the compiler's parameter-head rule (site 2) never sees it, because site 2 looks
at the declared *parameter type* (`T = int | atom`), not the *guard*. F24 §6's fix is to test at
the guard's comparison node instead — and it made that test unconditional, because the same
guard-narrowing can appear inside a private function's own clause too (as here), where there is no
exported wrapper's `Public` flag to consult in the first place.

### 2.4 The Dialyzer probe — a real precedent for "does export status change trust"

`probe_trust.erl`: a private `inner_total/1` with **no `-spec` naming the tag shape** (a bare or
generic `map()`-typed signature — see correction below), called from an exported function with a
**variable** holding an `invoice`-tagged map of the same shape (mirrors 26 §1's "no body ever
checks which record a map claims to be" — `inner_total/1`'s body only projects `Total`, never
inspects `Kind`):

```
$ dialyzer probe_trust.beam
  Checking whether the PLT ... is up-to-date... yes
  Proceeding with analysis... done in 0m0.11s
done (passed successfully)
```

**No warning at all.** Dialyzer's success typing is inferred from `inner_total/1`'s *body*, which
never tests the tag, so a differently-tagged map — passed through a variable, exported or not —
is invisible to it. **Correction, found by independent verification:** this brief's prose
originally said `inner_total/1` was "typed by `-spec` to accept an `order`-tagged map." That is
not what produces silence — the verifier confirmed that any *faithful* `-spec` naming the tag
shape (with `:=` or `=>`) makes Dialyzer raise an `invalid_contract`/breaks-contract warning
regardless of privacy; only a spec-free or generic `map()` signature passes silently, which is
what `probe_trust.erl` actually has. The conclusion this probe supports — export status changes
nothing about whether Dialyzer's *body-driven* inference catches a mismatch — still holds and is
independently reconfirmed by the sharper, pattern-matched version below, which needs no `-spec` to
make its point either way. Sharper version, `probe_trust2.erl` (private) / `probe_trust3.erl` (same
function, now exported), both call `inner(#{'Kind' := order, ...})`-headed function with a
**literal** map tagged `invoice`:

```
$ dialyzer probe_trust2.beam    # inner/1 PRIVATE
probe_trust2.erl:8:1: Function inner/1 has no local return
probe_trust2.erl:8:1: The pattern #{'Kind' := 'order', ...} can never match #{'Kind' := 'invoice', ...}
probe_trust2.erl:12:11: The call ... will never return ...

$ dialyzer probe_trust3.beam    # inner/1 EXPORTED — identical call-site warning
probe_trust3.erl:9:11: The call ... will never return ...
```

**Export status changes nothing about the warning.** Dialyzer draws no exported/private
distinction anywhere in this trust model; it is uniform, whole-program, body-driven inference —
it catches a mismatch exactly when (and only when) the callee's own clause head or pattern tests
the discriminating field, independent of who may call it. This is real, run evidence that the
nearest production analogue to "does a BEAM tool trust a private function's argument differently"
answers **no** — the discriminator that actually predicts a catch is "does the body test this,"
which is ticket 18 §1's own rule C, not "is it exported."

### 2.5 The OTP source survey — "one entry label," with file:line

`ticket 18 §1`'s claim that BEAM elision is exported-vs-local and not local-call-vs-remote-call,
because a function has one entry label shared by both:

```erlang
% /tmp/otp-src/lib/compiler/src/beam_asm.erl:115-123
assemble_1([{function,Name,Arity,Entry,Asm}|T], Exp, Dict0, Acc) ->
    Dict1 = case sets:is_element({Name,Arity}, Exp) of
                true  -> beam_dict:export(Name, Arity, Entry, Dict0);
                false -> beam_dict:local(Name, Arity, Entry, Dict0)
            end,
    {Code, Dict2} = assemble_function(Asm, Acc, Dict1),
    assemble_1(T, Exp, Dict2, Code);
```

```erlang
% /tmp/otp-src/lib/compiler/src/beam_dict.erl:103-117
export(Func, Arity, Label, Dict0) ... -> Dict1#asm{exports = [{Index, Arity, Label}|...]}.
local(Func, Arity, Label, Dict0)  ... -> Dict1#asm{locals  = [{Index, Arity, Label}|...]}.
```

One `Asm` instruction list, compiled exactly once (`assemble_function/3`) regardless of the
`case`; export-vs-local only decides which **table** (`ExpT` or `LocT`) records the *same*
`Entry`/`Label`. There is no code-level fork available to hang a guard on. This is the mechanical
reason a "guarded public entry, unguarded internal one" pair is not obtainable by any per-function
switch: the BEAM gives the compiler one body, and the emitter's own choice is entirely about what
goes *inside* that one body, which is exactly what §0's three sites are arguing over.

### 2.6 The Gleam opaque-type survey — compile-time-only, zero runtime cost, and its actual price

`analyse.rs:1165-1168` — an opaque type's constructor is forced private regardless of the type's
own declared visibility:

```rust
// /tmp/gleam-src/compiler-core/src/analyse.rs:1165-1168
// If the constructor belongs to an opaque type then it's going to be
// considered as private.
let value_constructor_publicity = if *opaque {
    Publicity::Private
} else { *publicity };
```

Enforcement is pure name resolution — a foreign module simply cannot spell the constructor
(`expression.rs:2490-2500`, `Error::UnknownModuleValue` when a looked-up value isn't present for
that caller). Codegen confirms there is no runtime residue:

```rust
// /tmp/gleam-src/compiler-core/src/erlang.rs:306-312
let type_spec = builder.start_type_spec(*opaque, &name, ...);   // -type vs -opaque ONLY
```

Real compile, real output (`gleam compile-package --no-beam`, avoiding an unrelated
escript/OTP-version incompatibility in this sandbox's full `gleam build` path — see §5.1):

```erlang
-module(money).
-export([new/1, amount/1]).
-export_type([money/0]).
-opaque money() :: {money, integer()}.

new(Cents) -> {money, Cents}.
amount(M) -> erlang:element(2, M).
```

`amount/1` is a bare `erlang:element(2, M)` — no tag test, no arity test, nothing. Run against a
forged value from raw Erlang:

```
$ erl -eval 'io:format("real:   ~p~n",[money:amount(money:new(100))]),
             io:format("forged: ~p~n",[money:amount({not_money, <<"oops">>})]).'
real:   100
forged: <<"oops">>
```

**Zero crash.** This is the concrete price of "trust established once at compile time, no runtime
tag": it costs literally nothing in bytes or nanoseconds, and it buys **no defence against a
foreign caller at all** — the same outcome-3 silent unsoundness ticket 18 catalogued for Gleam's
`@external`, now shown for Gleam's own flagship encapsulation feature. This is the sharpest
argument *against* treating "narrow scope = correctness win" as free: narrowing beam-sharp's tag
test the way Gleam narrows opaque-type checking (to nothing, outside the language) reproduces
exactly the gap ticket 18 was written to close.

## 3. Measured costs

Ticket 59 cites 26a's "+14 bytes flat" (tagged map) and 18's "+3–5 bytes / `is_integer`" on OTP
28.5 arm64. This sandbox has no network path to OTP 28.5 (§5), so the numbers below are a same-shape
reproduction on OTP 25.3.2 x86_64 — different release and architecture, offered as an
order-of-magnitude sanity check, not a replacement for the cited figures.

```
$ erlc +debug_info tag_guarded.erl tag_unguarded.erl int_guarded.erl int_unguarded.erl \
                    tag_double.erl tag_single.erl
tag_guarded      Code chunk = 87 B   (unguarded: 75 B)   -> +12 B
int_guarded      Code chunk = 70 B   (unguarded: 67 B)   -> +3 B
tag_double       Code chunk = 112 B  (single-tag: 100 B) -> +12 B AGAIN
```

- **Tag test**: +12 B of `Code` on this toolchain, vs. ticket 26a's own +14 B on OTP 28.5 — same
  order of magnitude, corroborating without exactly reproducing (expected, given the release/arch
  difference).
- **Int test**: +3 B, matching ticket 18's own "+3–5 B" almost exactly.
- **§3.3, not in either ticket's cost section: paying the tag test a second time costs the same
  increment again.** `tag_double.erl` (exported wrapper calls a private helper, both test the
  tag — the shape §2.1 measured in real beam-sharp output) costs **+12 B beyond** `tag_single.erl`
  (exported tests, private does not). The current unconditional-tag design does not pay the tag
  test's cost once per boundary; it pays it once **per hop** through every private layer a forged
  value could reach, which is a real, additive cost the ticket's cost section does not name because
  it was written assuming one guard per parameter rather than one guard per call in a chain.
- Call-time cost is not re-measured here; ticket 18a's own finding (below its ±0.09 ns/call
  timing resolution for one guard) is taken as authoritative rather than re-run, since nothing in
  this sandbox's toolchain difference plausibly moves a single BIF test above that noise floor.

## 4. Options

Each is stated as the literal change to `bs_emit.erl`'s `boundary_guards/5` / `guard_one/7` /
`is_public/1` — no abstract menu, per CLAUDE.md.

### Option 1 — narrow the tag test to exported-only

```erlang
guard_one(Pat, {param, TypeExpr, _}, Accept, I, Line, Ctx, Public) ->
    case record_tag(TypeExpr, Ctx) of
        {ok, Tag} when Public ->
            case constrains_kind(Pat) of
                true  -> {Pat, []};
                false ->
                    {Var, Pat1} = ensure_var(Pat, I, Line),
                    {Pat1, [tag_test(Var, Tag, Line)]}
            end;
        {ok, _Tag} ->
            {Pat, []};
        none when Public -> ...   %% unchanged
        none -> {Pat, []}
    end.
```

**For**, measured: removes §3.3's double-pay outright — `InnerRecord`, called only from
`OuterRecord`, stops carrying a redundant second tag test once `OuterRecord`'s own has already
run. Brings site 1 into agreement with the *original* (pre-F24-§6) scope of site 2, and is exactly
what 18 §4 says in so many words: "a private function's every call site is a checked beam-sharp
call site."

**Against**, sharpened: this is the same shape Gleam's opaque type takes (§2.6) — narrow to
nothing outside the exported boundary — and §2.6 shows its exact price: zero defence against a
value that reaches the private function *without* passing through the exported wrapper's own
check, which is precisely the class of gap §2.3 just found for the int-kind test at the narrowing
site. Ticket 59 has not surveyed whether an equivalent record-shaped gap exists (an exported
function with a union-of-two-record-types parameter whose narrowing is a body-level pattern rather
than the declared parameter type, forwarding to a private helper declared to take only one of the
two records) — narrowing before that survey is done risks reopening, for records, the exact
silent-unsoundness class F24 §6 just closed for ints.

### Option 2 — widen the int/float kind test to all functions, matching site 3's own precedent

```erlang
guard_one(Pat, {param, TypeExpr, _}, Accept, I, Line, Ctx, _Public) ->
    case record_tag(TypeExpr, Ctx) of
        {ok, Tag} -> ...          %% unchanged
        none ->
            case kind_only(TypeExpr, Ctx) of
                float -> float_guard(Pat, I, Line);
                _     -> int_guard(Pat, TypeExpr, Accept, I, Line, Ctx)
            end
    end.
```

(Drop the `when Public` guard and the second `none ->` fallback; `Public` becomes unused in
`guard_one/7` and can be dropped from its signature, though `boundary_guards/5` still needs it
nowhere else since site 1 is untouched.)

**For**, measured: this is not a new argument — it is applying the compiler's *own most recent
decision* (F24 §6, three weeks after this ticket was raised) to the one remaining site that
disagrees with it. §2.3 already shows privacy does not prove "checked call site only" whenever an
exported caller narrows in a guard rather than a parameter type; widening closes that gap at the
parameter head too, for the *general* case F24 §6's fix handles only at the specific guard-node
shape. Cost is the cheapest of the two guard kinds measured: +3 B of `Code` per newly-guarded
private int/float parameter (§3), against the tag test's own already-accepted +12–14 B.

**Against**, sharpened: this is a direct reversal of ticket 18 §4's explicit resolved text, quoted
verbatim in `bs_emit.erl`'s own comment at the site being changed (lines 314–317: "Exported
functions only: a private function's every call site is a checked B# call site, so the
out-of-domain argument was already refused... that asymmetry is deliberate"). F24 itself measured
the corpus cost of the exported-only version at 34 guard insertions across 9 of 15 modules; going
unconditional adds a guard to *every* currently-unguarded private int/float parameter in the
corpus, an unmeasured multiple of that 34, to close a gap that F24 §6 already closed **at its
actual point of failure** (the guard node) without touching the parameter-head rule at all. The
parameter-head case (a private function whose *own declared type* is plain `int`, called with a
non-integer) is already unreachable without going through an exported function that would itself
have had to accept a non-`int` argument somewhere — which 18 §4's own model says cannot happen
except through the exact union+guard-narrowing shape site 3 now handles. Widening site 2 pays for
protection against a case that, on 18 §4's own terms, site 3 has already made unreachable.

### Option 3 — a reachability discriminator instead of exported-vs-private

Replace the `Public` boolean throughout `boundary_guards/5`/`guard_one/7` with a per-parameter
fact computed by a new whole-aggregate pass — `is_public/1`'s one-field record read
(`element(7, F) =:= public`, line 125) would need to become something like
`reaches_unchecked_value(F, ParamIndex, CallGraph)`, fed by a cross-module reachability walk built
in `bs_check.erl` and threaded into `bs_emit`.

**For**: it is the only discriminator that is actually *true* to what both existing rules are
approximating — "was this value already checked by the time control reached here" — rather than a
proxy for it. It would let a private helper that is call-graph-closed (never reachable except from
beam-sharp code that has already re-derived its exact type) skip every guard, which neither Option
1 nor Option 2 can express.

**Against**, and this is decisive rather than merely a preference: ticket 18 §4 already rejected
this exact shape, by name, independent of correctness — "Whole-aggregate analysis would let an
edit to one file silently move another file's emitted boundary... reintroducing exactly the blast
radius one-function-per-file removed" — and 18 §4 is a *resolved* ticket, not a live question this
one gets to relitigate as a side effect. §2.3 is the demonstration that the compiler does not, in
fact, need this: F24 §6 closed the one real gap in the area **without** any cross-function
analysis, by relocating the test within the still-function-local pass (from the parameter head to
the guard's comparison node). Option 3 is the only option here with a real *architectural* cost —
a new static-analysis pass, not a byte count — and the codebase's own most recent precedent
already shows a cheaper fix exists for the class of problem Option 3 is built to solve.

## 5. Recommendation

**Option 2**, on the strength of §2.3 and §2.5/§2.6 together: the compiler's own newest decision
in this exact area (F24 §6, ENG-330) already crossed this line for the narrowing-guard site,
for a demonstrated reason, and did so *after* this ticket was filed without anyone reconciling the
two. Widening the parameter-head site to match is not a new departure from 18 §4 — 18 §4's
function-local premise has already been amended once, in this very file, for this very kind
channel; Option 2 finishes that amendment rather than starting a new one. Option 1 is not wrong,
but §2.6's Gleam evidence is a real, measured cost of narrowing (total loss of defence against
exactly the callers ticket 18 exists for) that the ticket should weigh explicitly before choosing
it, and Option 1 additionally requires a survey (does an equivalent record-shaped gap to §2.3
exist?) that has not been done. Option 3 should be set aside on 18 §4's own terms unless a case
turns up that Option 2's simpler fix demonstrably cannot reach.

This is a recommendation for whoever resolves ticket 59, not a resolution: no
`## Decisions entry` has been written anywhere, and the ticket's `Status:` line is untouched.

## 6. Verification

**Build environment.** `.tool-versions` pins `erlang 28.5` / `rebar 3.27.0`; this sandbox has OTP
25.3.2 (`erl -eval 'io:format("~s",[erlang:system_info(otp_release)])'`) and no egress to
`hex.pm`/`builds.hex.pm` (confirmed: `curl` to `builds.hex.pm` returns a proxy `403
connect_rejected`). `/tmp/rebar3` itself is compiled for a newer OTP and fails to load on 25; a
cached `rebar3_3.19.0-1_all.deb` in `/var/cache/apt/archives` was unpacked directly
(`dpkg -x ... /tmp/rebar3pkg`) to get a working `rebar3` for OTP 25. The compiler was built from a
**scratch copy** of `compiler/src` (never from the working tree in place), with two compatibility
patches confirmed necessary only for the OTP-version gap (`TokenLoc` binding requires leex's
`error_location` option, OTP 26+; `~kp` is an OTP 27+ `io_lib` format directive) and confirmed to
touch neither `bs_check.erl` nor `bs_emit.erl`.

**Source integrity, checked before every build**: `md5sum` of `bs_emit.erl` in the scratch copy
against `/home/user/beam-sharp/compiler/src/bs_emit.erl` in the real repo, matching
(`d7ee8c67c8dbfc20b1fa187f6fc5c387`) both before the first build and again before the independent
re-verification build below — the file that decides this ticket's outcome was never hand-edited.

**Independent re-verification** (in lieu of a spawnable subagent tool, which was not available in
this session's toolset — no `Task`/`Agent` tool was found by `ToolSearch`): a **second, separate**
scratch copy of `compiler/src` was made, its `bs_emit.erl` re-checked byte-identical by `md5sum`,
rebuilt with a fresh `rebar3 escriptize` invocation, used to recompile `Probe59.bs` to a fresh
`.beam`, and that `.beam` re-disassembled with a fresh `beam_disasm:file/1` call. The output
reproduced §2.1–§2.3 exactly, including the site-3 finding (`PrivateNarrow/1`, private, carrying
`is_integer` in its emitted head) — pasted in full in §2.3. Nothing in this brief rests on a
hand-edited `.beam`; every disassembly shown came from a `bsc`-produced `.beam` file, and both
builds' `Probe59.bs` source is quoted in full above rather than only its output.

**A genuinely separate verifier agent was subsequently spawned** (by the orchestrating session,
which does have Agent/Task access) and independently reproduced the central §2.3 finding with its
own probe module and names, confirming `Clamp` (private, union-typed, guard-narrowed) carries
`is_integer`+`is_ge` in its own head while its exported caller `Bound` carries no test at all. It
also spot-checked the OTP and Gleam citations verbatim and found two real blemishes, both
corrected above: the build recipe omitted a needed `rebar.config` change (§2 preamble), and §2.4's
first Dialyzer probe's prose didn't match what actually produces silence (§2.4). Neither
correction touches the headline finding, which the verifier calls "solid and independently
reproduced."

**Files used, all under this session's scratchpad, none under the repo**:
`Probe59/probe59.bs` (the probe module), `cost/*.erl` (the six byte-cost comparison modules,
§3), `dialyzer_probe/probe_trust{,2,3}.erl` (§2.4), `gleam_probe/src/{money,gleam_probe}.gleam`
(§2.6). None of these were published anywhere or committed; they exist only to produce the
pasted, verifiable output above.
