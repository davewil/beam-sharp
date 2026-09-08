# Ticket 59 — decision brief (autonomous research, not a decision)

**This is research for David's review. Nothing in ticket 59, F24, or ENG-241 was changed to
produce it.** Every claim below was executed against the real `bsc` compiler, built fresh
twice (from-scratch `erlc` builds, `bs_emit.beam` byte-identical between them — no rebar3 in
this sandbox, so both builds used `erlc -Werror -I src -o <dir> src/*.erl` on the checked-in
`compiler/src/*.erl`, including the already-generated `bs_lexer.erl`/`bs_parser.erl`), and
every runtime result was reproduced on a second, independent rebuild before being written here.

No `Agent`/`Task` tool exists in this environment to spawn a genuinely separate verifier
subagent (only `SendMessage` to an already-listed peer, which needs one to exist first) — this
is recorded rather than papered over. In its place: every probe below was rebuilt from source
a second time in a fresh output directory and every runtime call re-executed; results matched
exactly, and `bs_emit.beam` hashed identically across both builds. This is a weaker substitute
than a second reasoner and is flagged as such.

## 1. The asymmetry, confirmed at the source

`compiler/src/bs_emit.erl`, `guard_one/7` (line 243), the function `boundary_guards/6`
(line 233 — six arguments as currently written, not five) folds over each parameter:

```erlang
guard_one(Pat, {param, TypeExpr, _}, Accept, I, Line, Ctx, Public) ->
    case record_tag(TypeExpr, Ctx) of
        {ok, Tag} ->
            case constrains_kind(Pat) of
                true  -> {Pat, []};
                false ->
                    {Var, Pat1} = ensure_var(Pat, I, Line),
                    {Pat1, [tag_test(Var, Tag, Line)]}   % <- unconditional: Public unread
            end;
        none when Public ->
            int_guard(Pat, TypeExpr, Accept, I, Line, Ctx);  % <- gated on Public
        none ->
            {Pat, []}
    end.
```

The record arm never inspects `Public`. The int arm is reached only `when Public`. The
comments at lines 220-231 and 277-280 name this as deliberate ("that asymmetry is deliberate
(ticket 46)"), not an oversight — matching what ticket 46 and F24 already record.

## 2. Real probe — the compiled output, both functions, private and public, side by side

`Probe.bs` (full source in the session's scratchpad; a private `Inner(Order o)`, a private
`ClassifyPriv(Octet n)`, and public wrappers `Outer`/`ClassifyPub` that call them):

```erlang
'Inner'(O) when map_get('Kind', O) =:= 'Probe.Order' ->
    map_get('Total', O).

'ClassifyPriv'(Bs@r1) when Bs@r1 >= 9 ->
    reserved;
'ClassifyPriv'(_N) ->
    method.

'Outer'(O) when map_get('Kind', O) =:= 'Probe.Order' ->
    'Inner'(O).

'ClassifyPub'(N)
    when is_integer(N) andalso N >= 0 andalso N =< 255 ->
    'ClassifyPriv'(N).
```

This is `erl_pp:form/1` printing the real forms read back from `bsc`'s own `.abstr` output
(`bs_emit:forms/1`, written to disk per `compiler/README.md`'s pipeline) — not a hand
transcription. `Inner` (private) carries the tag test; `ClassifyPriv` (private) carries no
`is_integer` at all, only the bare comparison `Bs@r1 >= 9`. `Outer`/`ClassifyPub` (public,
wrapping the same private functions) show the guard each rule adds at the public boundary for
comparison.

Confirmed separately: `Erlang:module_info(exports)` on the compiled module lists only the
`public` functions (`Outer`, `ClassifyPub`, …) — `Inner`/`ClassifyPriv` are genuinely absent
from the export table, and `erlang:apply('Probe', 'Inner', [...])` from outside the module
raises `undef`. Privacy is a real BEAM export-table boundary, not a lint-only label — so the
*only* way a value reaches a private function is through the module's own code, exactly as
ticket 18 §4 assumes.

## 3. Real probe — a value that lies about its type, reaching the private function

Because privacy is a hard boundary and B#'s own type checker rejects a badly-typed literal at
a checked call site, the only way to *observe* what a forged value does at a private function
is to bring it in through a channel ticket 18 §1 already treats as untrusted: an FFI import
that **declares** a type the real Erlang side does not honor — the same shape ticket 18 §2
measured for Gleam.

`Forge.bs`:

```csharp
record Order { Id: binary, Total: int }
type Octet = int where value >= 0 and value <= 255

using :probe_ffi {
    Order make_bad_order()      // real Erlang side returns Kind = 'Forge.NotAnOrder'
    Octet make_bad_octet()      // real Erlang side returns the atom forged_not_an_int
    Order make_wrong_payload()  // right tag, Total is the atom not_an_int
}

int Inner(Order o)
Inner(o) -> o.Total

:method | :reserved ClassifyPriv(Octet n)
ClassifyPriv(>= 9) -> :reserved
ClassifyPriv(n)     -> :method

public int OuterForgedOrder()
OuterForgedOrder() -> Inner(:probe_ffi.make_bad_order())

public :method | :reserved OuterForgedOctet()
OuterForgedOctet() -> ClassifyPriv(:probe_ffi.make_bad_octet())

public int OuterWrongPayload()
OuterWrongPayload() -> Inner(:probe_ffi.make_wrong_payload())
```

Emitted (again, `.abstr` read back and pretty-printed):

```erlang
'OuterForgedOrder'()  -> 'Inner'(probe_ffi:make_bad_order()).
'OuterForgedOctet'()  -> 'ClassifyPriv'(probe_ffi:make_bad_octet()).
'OuterWrongPayload'() -> 'Inner'(probe_ffi:make_wrong_payload()).
```

**No check is inserted at the FFI call itself** — `bsc` trusts the `using` declaration exactly
the way Gleam's `@external` does (ticket 18 §2's own finding, reconfirmed here at a different
call shape). Whatever defends the forged value is whatever guard sits on the function the
forged value is handed to next.

Real runtime results, `erlang:apply/3` from outside the module (reproduced identically on a
second, independent build):

| call | result |
|---|---|
| `OuterForgedOrder()` — wrong record tag reaches private `Inner` | **`error:function_clause`** |
| `OuterForgedOctet()` — wrong-kind atom reaches private `ClassifyPriv` | **`reserved`** — no crash |
| `OuterWrongPayload()` — right tag, `Total` field is an atom, reaches private `Inner` | **`not_an_int`** — no crash |

Row 1 is ticket 26 §1's argument, observed rather than argued: the private tag test is the
*only* thing that stood between a lying FFI declaration and `Inner` returning garbage, and it
worked. Row 2 is ticket 18's outcome 3 — "the only outcome that makes the type system a
lie" — happening live, on a private function, because F24 stopped at the exported boundary:
`forged_not_an_int >= 9` is `true` by BEAM term order (atom > number), so `ClassifyPriv`
silently takes the wrong clause and returns a value. This is the exact shape of ticket 58's
defect (`Classify(100.5)` returning `:reserved`), reopened one function-call deeper because the
private function never got F24's fix. Row 3 is ticket 10's tag/payload asymmetry, restated:
the tag test that saved row 1 tests only `Kind`, never a field's own value kind, so a
correctly-tagged, wrong-payload record still passes silently — consistent with row 3 being
*out of scope* for ticket 59 (it's ticket 46 §4's "one projection deep", already an owed edge)
but useful context for how much the tag test does and does not buy.

## 4. Cost, measured fresh (independent of, but consistent with, tickets 18/26's own numbers)

Isolated Erlang modules, single clause/two clauses, `erlc`, `beam_lib:chunks(F, ["Code"])`:

| guard added to a **private**-shaped function | Code chunk | whole `.beam` |
|---|---|---|
| `is_integer/1` on `ClassifyPriv`'s two clauses (widening the int guard) | 80 B → 85 B (**+5 B**) | 820 B → 852 B (**+32 B**) |
| record tag test on `Inner`'s one clause (this is the cost ticket 59 could *remove* by narrowing) | 73 B → 85 B (**+12 B**) | 816 B → 872 B (**+56 B**) |

These land in the same range as ticket 18a's own `is_integer` figure (+3–5 B) and ticket 26a's
tagged-map figure (+14 B) — independent confirmation, not a new number to trust instead of
theirs. **The cost of either answer is small and roughly symmetric**: widening the int guard to
private functions costs about what narrowing the record guard would save.

## 5. Precedent survey

**Erlang/Elixir — real Dialyzer run, this sandbox (OTP 25, Elixir 1.14).** A plain Erlang
module with an **unexported** function carrying its own `-spec`:

```erlang
-spec private_octet(0..255) -> method | reserved.
private_octet(N) when N >= 9 -> reserved;
private_octet(_N) -> method.
direct_private_call_literal() -> private_octet(not_an_int).
```

`dialyzer` **does** flag the literal, statically: *"the call spec_probe:private_octet('not_an_int')
breaks the contract (0..255) -> 'method' | 'reserved'"* — Dialyzer can see through an unexported
function's own `-spec` when the violation is visible in source. But **at runtime**,
`private_octet(not_an_int)` called directly returns `reserved` — no enforcement of any kind,
export status irrelevant, exactly like `ClassifyPriv` above. And `private_octet(300)` — a bare
out-of-range **integer**, not even a kind violation — also returns `reserved`; Erlang's `-spec`
is never runtime-checked, on any function, and Dialyzer is not part of `bsc`'s build (ticket 13
already established this: a `-spec` is emitted, Dialyzer is not invoked automatically).

The literal Elixir version (`defp private_octet(n)` with a matching `@spec`) was compiled and
run directly — same runtime result (`reserved` for both a bad kind and an out-of-range
integer) — but `dialyzer` against the compiled `.beam` failed in this sandbox with a real,
reported tool-version conflict (`elixir_erl:debug_info/4` `undef`, from Elixir 1.14's compiler
metadata format meeting this box's OTP 25 `dialyzer`), not a fabricated result. The plain-Erlang
run above is the equivalent probe with a tool that actually completed, since Elixir's `@spec`
lowers to the same `-spec` attribute Dialyzer reads. Flagged rather than silently substituted.

**Conclusion for Erlang/Elixir**: neither has *any* runtime boundary check, public or private —
so neither is a precedent for symmetry OR asymmetry; B#'s "guard some functions and not others"
question doesn't arise for a language that guards nothing. What *is* comparable is: a
static tool (Dialyzer) can catch a private-function contract violation when it's visible in
source, exactly as `bsc`'s own type checker already does inside B# (ticket 18 §4's "site 1").
Neither buys anything against a value arriving from *outside* what the tool analysed.

**Gleam — cited from this repo's own prior, real probes** (`wayfinder/prototypes/10c_gleam_forge.erl`,
`18c_gleam_ffi_trust.gleam`/`.erl`; Gleam is not installable in this sandbox — network blocked —
so these are read, not re-run, exactly as instructed). Gleam has **no boundary-guard mechanism
at all**, public or private: `describe(purple)` crashing was a `case_clause` from the function's
own pattern match (18 §1's "the body already objects"), not a compiler-inserted guard, and
`@external(erlang, ...)` trusts its declared type unconditionally and publishes it as a `-spec`
regardless of visibility (measured: `-> Int` returned `41.5`). **Gleam therefore has nothing to
be asymmetric about** — CLAUDE.md's framing ("all-public-or-private-with-no-runtime-check") is
accurate and is now doubly grounded, in this session's own re-reading of the cited prototypes.

## 6. Options

### Option A — widen the int-kind guard to every function (private included)

```erlang
%% none when Public -> int_guard(...);   %% delete the `when Public` guard
none -> int_guard(Pat, TypeExpr, Accept, I, Line, Ctx);
```

One line in `guard_one/7` (`compiler/src/bs_emit.erl:252`); `int_guard/6` (line 286) is
unchanged. `Public` becomes dead in this function (still read by the record arm's comment
context — actually no, the record arm never reads it either; `Public` would need to stay a
parameter only because `function/2` (line 131) already computes it for other reasons — check
before deleting the parameter entirely). Every private function whose parameter is int-only
gets `is_integer` (and F37's range residual) unconditionally.

**Evidence for**: row 2/3 above are real, on a real forged value, through a real (if adversarial)
channel — a lying FFI declaration is exactly one of ticket 18's eight violation channels
(#5/#6/#8, "what did a foreign declaration promise"), and 18 §2 already concedes those channels
aren't closed by the FFI wrapper itself. Symmetric with what F3/26 §1 already does for records.
Cost is small and measured (+5 B / two clauses here; ticket 18a's own ±0.09 ns/call floor).

**Strongest counterargument**: this is the one option that visibly contradicts 18 §4's own
stated rule ("the exported function's own clause heads... and no further" — deliberately
function-local so an edit to a private function's *caller* can't silently move its guard) and
reopens 18 §4's own closed argument that "a private function's every call site is a checked
beam-sharp call site." Every genuinely-B#-typed call path into a private int-taking function
*is* already defended — by the type checker's own narrowing, not by a runtime guard — and this
option pays the cost on every such call too, not only the FFI-forged one. It also has no natural
stopping point: if a private function needs the guard because *a caller might have lied*, so
does every function two, three, N calls deep, and 18 §4 rejected exactly this whole-aggregate
reasoning for the record guard's own sibling question (§4, "whole-aggregate analysis would
reintroduce the blast radius one-function-per-file removed").

### Option B — narrow the record tag guard to exported-only, matching int

```erlang
{ok, Tag} when Public ->
    case constrains_kind(Pat) of ... end;
{ok, _Tag} -> {Pat, []};   %% no tag test, unexported
```

One clause added at `compiler/src/bs_emit.erl:244-251`. F3/26a's own measured `Inner`-shaped
cost (+12-14 B) disappears from every private function taking a record.

**Evidence for**: literal reading of 18 §4 — "the exported function's own clause heads... and no
further" governs case C uniformly, and F3's comment already claims this scope ("emitted on a
private function too" was ticket 46's own finding *against* what the comment at
`bs_emit.erl:220-225` had said before F24 corrected it in code but not in text — the comment
at line 227-230 still just says "the tag test is emitted... and not where the clause's own
pattern already constrains Kind," silent on Public exactly like the code).

**Strongest counterargument**: this option is refuted by this session's own row 1. Removing the
tag test on `Inner` makes `OuterForgedOrder()` **not crash** — it makes `map_get('Total', O)`
on a map tagged `'Forge.NotAnOrder'` succeed silently (the key exists on any map with a `Total`
field, tag or no tag), converting a `function_clause` into exactly ticket 06's outcome 3. Unlike
the int case, there is no compensating guard anywhere else in this program: `OuterForgedOrder`
is 0-arity and takes nothing from the caller to guard *at* — the forged value is manufactured
inside the function, so there is no exported clause head for a guard to sit on upstream of
`Inner`. Narrowing is not merely "leaves a comparable hole" here; on the concrete probe it opens
one where none existed. 26 §1's "no body ever checks which record a map claims to be" is not a
rhetorical claim — `Inner`'s own body (`o.Total`) is the demonstration.

### Option C — keep the asymmetry, write down why, in both places

No code change to `bs_emit.erl`. Amend the record-guard comment block
(`compiler/src/bs_emit.erl:220-231`) and the int-guard comment block (`:269-284`) to state the
distinguishing fact this session measured rather than assumed: **a record parameter's tag test
defends a caller who supplies the value from *outside* the function currently being read (an FFI
return, a decoded external term) even when the function is private, because nothing else in the
program necessarily re-validates that exact value before it reaches the field projection — while
an int-only parameter's kind is, on the corpus built so far, always re-validated by an upstream
exported guard or by the type checker's own narrowing before it can reach a private consumer,
*except* through the same FFI-lying channel measured in row 2, which is real and currently
open.** That "except" is the honest remainder: Option C is not "prove there's no hole," it's
"the two guards differ in how *exposed* their private form is today, and F24 explicitly deferred
row 2's channel as future work, not as closed."

**Evidence for**: cheapest option, and it is the only one that survives this session's own
counter-probes for *both* guards without changing behaviour anyone has come to depend on
(492+646 tests currently green over the two guards' current scopes). It also matches the
project's working rule against "a matrix of coupled options" — it asks nothing further and
changes no `.beam` output.

**Strongest counterargument**: row 2 above is a real, reproduced silent-unsoundness result on
today's compiler, on a probe shaped exactly like ticket 06's canonical outcome-3 example. "Write
down why" does not make `OuterForgedOctet()` stop returning `reserved`. If the FFI-lying channel
is judged in-scope for ticket 18's guarantee ("a foreign term that breaks your types will crash —
not always where it entered, but never silently"), Option C is documentation over an open
violation of that guarantee's own sentence, not a resolution of it — indistinguishable in effect
from declining to fix ticket 58's shape a second time.

## 7. Recommendation

**Option A**, with the counterargument taken seriously rather than dismissed: widen the
int-kind guard to every function whose parameter is int-only, matching the record guard's
existing scope — not because 18 §4's function-local reasoning is wrong for the ordinary,
all-B#-typed call graph (it isn't; that's most of the corpus and the guard there really is
redundant with the type checker), but because **this session measured a real, reproducible
channel — a lying FFI declaration — that reaches a private function with neither the type
checker's narrowing nor any runtime guard standing in the way, and the record guard already
closes the identical channel for records.** Ticket 59's own framing asks "which scope is right,
stated once, for both guards" (§What this owes, item 1) — row 2 is the concrete case that
answers it: the record guard's current scope is not accidental generosity, it is what closes
row 1, and the int guard's current scope leaves row 2 open on the same compiler, today, on a
program that already compiles.

The cost objection (18 §4's blast-radius argument) is real but narrower than it looks: it
argues against *whole-aggregate* analysis re-deriving whether a guard is needed by reading
other files, which this is not — Option A adds a guard **unconditionally on the int-only shape**
with no analysis of callers at all, exactly as the record guard already does. It is the same
"emit always, and let it be occasionally redundant" trade the record guard already made and
that ticket 26a priced. The redundant case (a purely-internal call, no FFI involved) pays a
measured, small, flat cost (+5 B here, +3-5 B on ticket 18a's own numbers) for a guarantee that
currently has a hole.

Recommend **against** Option B outright — row 1 is a direct, reproduced counter-example on this
session's own probe, not a theoretical one.
