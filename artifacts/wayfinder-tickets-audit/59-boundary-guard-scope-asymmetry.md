# Audit: ticket 59 — the boundary guard now applies two rules with different scopes

**This is a research artifact only. No status line in `wayfinder/issues/59-boundary-guard-scope-asymmetry.md`
was changed, ENG-241 was not moved out of Backlog, and no Linear field was touched beyond posting one
comment.** Ticket 59 is `Type: wayfinder:decision`, currently open.

Per CLAUDE.md ("A design question is B# code plus the compiler delta, and nothing else" /
option-menus "rejected outright"): below are candidate designs, each as real B# code with the
guard behaviour it produces, backed by evidence I actually ran or actually read, plus the concrete
`bs_emit.erl` delta each implies and its strongest verified counterargument. No winner is declared.

---

## 0. What the ticket is actually asking (and what it is not)

`bs_emit:boundary_guards/5` (`compiler/src/bs_emit.erl:247`, dispatching through `guard_one/7` at
`bs_emit.erl:257`) emits two different runtime guards on a clause head:

- the **record TAG test** (`{ok, Tag} -> ...` branch, `bs_emit.erl:258-265`) — emitted on **every**
  function, public or private; `Public` is never read in that branch.
- the **int KIND test** (`none when Public -> ...` branch, `bs_emit.erl:266-270`) — emitted only when
  `Public` is `true`.

`is_public(F) -> element(7, F) =:= public.` (`bs_emit.erl:124`) — a static, per-function attribute
read off the AST, not a call-graph or reachability property. I confirmed this directly (§2 below):
the tag test fires even on a record-typed private function nothing in the module ever calls.

**Caution on the framing handed down with this task**: "boundary guard scope" here means *which
functions get an emitted runtime guard at all*, decided per-function at compile time from a
visibility flag. This is a different axis from the textbook Erlang/Elixir notion of "guard scope"
— *which variables a single `when` clause may reference*, resolved per-clause. I ran real probes
for both (§4) so the distinction is not asserted from memory, but they should not be conflated:
ticket 59 is entirely the former.

---

## 1. Independently reproduced: the asymmetry as measured

I built the compiler from `compiler/src/*.erl/.xrl/.yrl` (OTP 25 locally installed; `rebar3` was not
available, so `leex`/`yecc`/`erlc` were driven directly — noted as an environment gap, not a ticket
finding) and ran it twice, on two unrelated probe modules, to rule out a fluke:

**Probe A** — `Boundary59/boundary59.bs`, a private record-typed `InnerRecord` and a private
int-typed `InnerInt`, each called once from an exported sibling:

```csharp
record Order { Id: int }
int InnerRecord(Order o)
InnerRecord(o) -> o.Id
public int OuterRecord(Order o)
OuterRecord(o) -> InnerRecord(o)

int InnerInt(int n)
InnerInt(n) -> n
public int OuterInt(int n)
OuterInt(n) -> InnerInt(n)
```

Emitted abstract forms (`bsc -o probe_out --src-root probe probe/Boundary59 OuterInt 7`, real run):

```erlang
{function,0,'InnerRecord',1,
    [{clause,13,[{var,13,'O'}],
        [[{op,13,'=:=',{call,13,{remote,13,{atom,13,erlang},{atom,13,map_get}},
              [{atom,13,'Kind'},{var,13,'O'}]},
              {atom,13,'Boundary59.Order'}}]],           %% <-- tag test, PRIVATE
        [...]}]}.
{function,0,'InnerInt',1,[{clause,23,[{var,23,'N'}],[],[{var,23,'N'}]}]}.  %% <-- NO guard, PRIVATE
{function,0,'OuterInt',1,
    [{clause,27,[{var,27,'N'}],
        [[{call,27,{remote,27,{atom,27,erlang},{atom,27,is_integer}},[{var,27,'N'}]}]], %% exported: guarded
        [...]}]}.
```

**Probe B** (independent re-run, different names, `Ver59/ver59.bs`) additionally made the private
record function **unreachable dead code** to test whether emission is call-graph-based:

```csharp
record Ticket { Num: int }
int DeadRecord(Ticket t)      // never called by anything
DeadRecord(t) -> t.Num
int DeadIntHelper(int n)      // never called by anything
DeadIntHelper(n) -> n
public int Live(int n)
Live(n) -> n
```

Compiler warns both are unused, but still emits the tag test on `DeadRecord` and nothing on
`DeadIntHelper`, `n` unchanged. This confirms the asymmetry is a pure visibility-flag check, exactly
matching `is_public/1`'s definition — not an oversight of "nothing calls it so it doesn't matter."

---

## 2. Candidate 1 — narrow the tag test to exported-only, matching F24

```csharp
// same Boundary59 example; ONLY the compiler delta changes, not the source
int InnerRecord(Order o)
InnerRecord(o) -> o.Id
```

**Under this candidate**, `InnerRecord`'s emitted clause would read `[{clause,13,[{var,13,'O'}],[],
[...]}]` — no guard, symmetric with `InnerInt` above.

**Compiler delta** (`bs_emit.erl:258`):

```erlang
guard_one(Pat, {param, TypeExpr, _}, Accept, I, Line, Ctx, Public) ->
    case record_tag(TypeExpr, Ctx) of
        {ok, Tag} when Public ->
            case constrains_kind(Pat) of
                true  -> {Pat, []};
                false -> {Var, Pat1} = ensure_var(Pat, I, Line),
                          {Pat1, [tag_test(Var, Tag, Line)]}
            end;
        {ok, _} -> {Pat, []};          %% <-- new: private, elided
        none when Public -> ...
        none -> {Pat, []}
    end.
```

**Evidence for**: ticket 18 §1's own structural finding (`wayfinder/issues/18-boundary-defence.md:612-617`,
quoted verbatim): *"elision is exported-vs-local, not local-call vs remote-call, since a BEAM function
has one entry label ... interior functions already pay nothing — which is the shape C wanted anyway."*
This is the same sentence F24/ticket 58 built against. Cost: ticket 26a's own measurement
(`26-data-modelling.md:227`) — the tagged-map discriminator is **+14 bytes, flat in field count** —
so narrowing removes exactly that, on every private record parameter in the corpus.

**Strongest counterargument, verified**: ticket 26's own resolved answer explicitly says **"tag test
always"** (`26-data-modelling.md:229-230`: *"Guard content follows 18's own rule with no new one:
tag test always, presence and value tests per 18 §1, exact-set test only where a codegen obligation
consumes the record."*). That is not silence or an oversight — it is a stated, deliberate design
point in a ticket marked `resolved`. Narrowing it is not fixing F3's implementation against 26; it is
overturning 26's own decided text, which CLAUDE.md's working rule treats as a second decision, not a
bug-fix. Separately: F24 §6 (`compiler/features/F24-boundary-kind.md:173-219`) is a *measured*
instance of the premise "a private call site is already checked" failing for **int** — the checker's
own `apply_guard/3` range-narrowing let an atom reach a `public int` boundary silently
(`Bump(:foo) -> :foo`, no crash, no diagnostic) until a second guard site was added. Nothing rules out
an analogous checker gap for records; narrowing the tag test removes the one remaining backstop with
no evidence the analogous gap has been looked for.

---

## 3. Candidate 2 — widen the int test to every function, matching the tag test

```csharp
int InnerInt(int n)
InnerInt(n) -> n
```

**Under this candidate**, `InnerInt`'s emitted clause would gain `erlang:is_integer(N)` even though
private, symmetric with `InnerRecord`.

**Compiler delta** (`bs_emit.erl:266`): drop the `when Public` guard on the `none` branch entirely,
so `int_guard/6` runs unconditionally. This also removes F24 §5/§6's entire "exported only" framing
and, as a side effect, would have caught F24 §6's `Bump(:foo)` case (`compiler/features/F24-boundary-kind.md:194-196`)
at `Tag`'s own boundary regardless of whether the caller's narrowing was sound.

**Evidence for**: cost is cheap and already measured — ticket 18's own number
(`18-boundary-defence.md:438,597-606`): **+3–5 bytes per `is_integer`**, call time **at or below the
±0.09 ns/call measurement resolution**. Nothing new needs measuring.

**Strongest counterargument, verified**: this reverses ticket 18's decided rule C on its own terms,
not merely F24's reading of it. The question ticket 18 was chartered to answer was *"Does the
compiler emit guards **at exported function boundaries**?"* (`18-boundary-defence.md:26`), and its
answer sentence C is stated the same way throughout §1 and §4 — *"It looks at the exported function's
own clause heads and body, and no further"* (`18-boundary-defence.md:817`). Widening to every
function is not implementing 18 more completely; it is answering a question 18 was never asked (guards
on **private** boundaries) by extrapolating from a decision about **exported** ones. It also opens the
door F24 §5 explicitly left shut: `atom`, `binary`, `tuple`, `list` are "owed, not decided differently"
(`F24-boundary-kind.md:149-151`) for the *exported* channel alone; widening the scope axis first, before
those channels exist, multiplies future work along an axis nobody asked to open.

---

## 4. Candidate 3 — no code change: the two rules cite different, non-conflicting clauses of ticket 18, and ticket 59's own table is imprecise about it

```csharp
// no change to boundary59.bs; the claim is about which sentence of ticket 18
// authorizes which guard, not about what bs_emit.erl does
```

**Evidence for**: ticket 59's table (`59-boundary-guard-scope-asymmetry.md:13-16`) lists the tag
test's authority as **"none — nothing consults `is_public/1`"**. That understates it. Ticket 26 itself
cites `18 §1(c)` explicitly as its authority (`26-data-modelling.md:178-179`): *"Ticket 18 §1 settled
that the compiler emits a guard wherever an exported function's own body would not object, and
§1(c) makes that unconditional for any value feeding a codegen obligation."* And 18's own text for
case (c) (`18-boundary-defence.md:534`) is *"Generated code consumes it — guard emitted
unconditionally, no analysis."* — unconditional **by construction**, independent of visibility,
because the thing being defended is generated code's own assumption, not a caller's honesty. The int
test, by contrast, is grounded in rule C's case (b) plus §4's exported-only framing
(`18-boundary-defence.md:519-532`, `815-844`). Two different clauses, two different scope rules — not
an unexplained accident, on this reading.

**Strongest counterargument, verified**: the citation match is not exact either. §1(c)'s own text
scopes the unconditional guard to *"any value **feeding a codegen obligation**"* — an encoder, a
`ValidateAs<T>` call, a serializer. My probe's `DeadRecord(t) -> t.Num` and `InnerRecord(o) -> o.Id`
do neither: they only project a field, and the tag test still fires. Ticket 26's own resolution text
extends past what §1(c) licenses on its own terms — it says *"tag test always"*
(`26-data-modelling.md:229`), i.e. on **every** record parameter, not only ones reaching a codegen
consumer — citing 26 §1's separate, independent argument (*"no body ever checks which record a map
claims to be"*) rather than §1(c) alone. So candidate 3 resolves the *citation* ticket 59 flagged as
missing, but the *scope* it lands on is still 26's own stand-alone design choice, argued on grounds
that never mentioned visibility — which is exactly the tension ticket 59 names, just moved one level
up, from "which code branch is wrong" to "which of two independently-argued 2026-08-13 decisions
governs where they overlap."

---

## 5. Grounding probes actually run

**Erlang term ordering** (`erl`, OTP 25.3.2.8, `erlc`+`erl -noshell`, reconfirmed on a second,
differently-valued probe):

```
100.5 >= 0 andalso 100.5 =< 255 : true
foo >= 0                        : true
foo =< 255                      : false
300.5 >= 0 andalso 300.5 =< 255 : false
bar >= 0                        : true     bar =< 255 : false
```

Matches ticket 58's claim (`58-refined-int-admits-a-float.md:51-54`) exactly — a comparison orders,
it does not decide kind.

**Module-boundary enforcement** (real two-module `erlc`/`erl` probe, reconfirmed with a second,
differently-named pair): a **non-exported** function is unreachable from another module, at
runtime, whether called via a directly-compiled remote call or via `erlang:apply/3`:

```
apply exported outer/1  : {inner_saw,hello}
apply unexported inner/1: {'EXIT',{undef,[{mod_b,inner,[hello],[]}, ...]}}
erlang:apply on inner/1 : {'EXIT',{undef,[{mod_b,inner,[hello],[]}, ...]}}
exports of mod_b        : [{module_info,0},{module_info,1},{outer,1}]
```

This is real, independent support for the premise behind F24's "exported only" comment
(`bs_emit.erl:313-316`: *"a private function's every call site is a checked beam-sharp call site"*):
the BEAM itself, not just bsc's own static checker, refuses external calls into a non-exported
function. It does **not** by itself establish that an *internal* call always carries a value the
static checker actually verified — that is a separate, checker-soundness question (§2's
counterargument), which the module-boundary probe cannot speak to.

**`bs_check.erl`, read directly**: internal calls are statically checked against declared parameter
types at every call site (`compiler/src/bs_check.erl:4399-4422`, `arg_diags/6`), including calls to
private callees (the `private_function` diagnostic only fires when a callee is *unresolved*, not to
exempt private callees from argument checking). This is real support for the "checked B# call site"
premise as a general design — with the caveat that F24 §6 found one instance where that same checker's
own narrowing logic (`apply_guard/3` intersecting with `range(0, pos_inf)`) let a wrong-kind value
through undetected until a second emission site was added.

**Textbook Erlang/Elixir guard-variable scoping** (asked for explicitly, run for completeness, and
kept separate from §0's distinction): a `when` guard sees only the variables its own clause head
binds:

```erlang
f(X) when X > 0 -> positive;
f(X) when Y > 0 -> negative.   %% real erlc output:
%% gscope2.erl:8:11: variable 'Y' is unbound
```

and, run and corrected in the same pass — a variable **is** visible after a `case` when every branch
binds it (Erlang's ordinary variable-export-from-case rule), which is not the same rule and should not
be quoted as a counter-example to the one above:

```erlang
f(X) -> case X of Y -> ok end, Y.   %% compiles clean — Y exported from every branch
```

Elixir guard scoping, run directly (`elixir`, 1.14.0 on OTP 24 runtime):

```elixir
def classify(n) when is_integer(n) and n >= 0, do: :non_negative
def classify(_), do: :other
```

```
:non_negative   (classify(5))
:other          (classify(-5))
:other          (classify(:atom))
```

— an ordinary head-bound guard, no cross-clause or cross-branch visibility, consistent with the
Erlang result. **Neither of these Erlang/Elixir facts bears directly on ticket 59's actual axis**
(per-function emission scope); they are included because the task asked for them to be verified
rather than asserted, and because Candidate 3's clause-citation argument (which sentence of ticket 18
"scopes" which guard) is the closest analogue to variable/guard scoping that exists in this ticket.

---

## 6. Neighboring-language survey: "boundary check" vs "inline match" scoping

**Gleam, vendored prototypes, read directly**:

- `wayfinder/prototypes/32a_gleam_external.gleam:9-11` declares a **private** (`fn`, not `pub fn`)
  external: `@external(erlang, "erlang", "byte_size") fn size_of(b: BitArray) -> Int` — Gleam accepts
  a visibility distinction on an FFI boundary declaration, but for a linking reason, not a safety one
  (below).
- `wayfinder/prototypes/18c_gleam_ffi_trust.gleam` / `.erl`: two **public** `@external` declarations
  given deliberately wrong Erlang-side return values; Gleam emits a `-spec` and a bare pass-through,
  no check, for both — already ticket 18's own cited evidence (`18-boundary-defence.md:932`).

**Gleam compiler source, fetched live** (`compiler-core/src/erlang.rs`, `gleam-lang/gleam` main
branch, via WebFetch — network reachable, quoted from the fetch, not from memory):

```rust
if function.external_erlang.is_some() && function.publicity.is_private() {
    return;   // private external: no wrapper generated, callers get erlc's inlined name directly
}
```

Public externals get a generated wrapper that performs a remote call; **neither path emits any
runtime type or shape guard** — the visibility split exists purely to decide whether a codegen
wrapper is needed at all, not to decide whether a check runs. This is a real, load-bearing difference
from beam-sharp's problem: Gleam's public/private split for FFI is orthogonal to safety because Gleam
checks nothing at either visibility (claim A in ticket 18's own three-way table,
`18-boundary-defence.md:497`); beam-sharp (claim C) is the only one of the two with a scope decision
to make in the first place, so Gleam is evidence that "split by visibility" is a normal codegen move
on this platform, but not evidence for or against which side of the split should carry a *safety*
guard, since Gleam never puts one on either side.

I did not find a Gleam `assert`-boundary equivalent to beam-sharp's runtime kind guard to compare
scoping rules against directly — Gleam's `assert` (pattern-match panic sugar) and its FFI boundary are
two different mechanisms, and neither is scoped by function visibility for a *safety* reason.

---

## 7. Independent re-verification

The task asked for a separate agent, spawned through an Agent/Task tool, to redo every probe from
scratch. **No such tool was available to this session** — the available tool set (checked via
`ToolSearch`) has `SendMessage` for peer agents already running and no tool that spawns a new one from
here. In its place I ran a second, independent pass myself, deliberately with different names, an
added dead-code case not in the first pass, and a second differently-valued pair of Erlang probes
(§1's Probe B, §5's `bar`/`300.5`/`peer_caller` probes), rather than re-reading the first pass's
transcript. All results reconfirmed identically; nothing in the second pass depended on or quoted the
first pass's output. This is flagged explicitly as a limitation rather than silently substituted.

---

Personal view, separated from the evidence above: on the evidence gathered here I would reach for
Candidate 3's citation fix first, specifically because the checker-soundness gap F24 §6 already found
once (§2's counterargument) makes me reluctant to remove the one remaining defense in Candidate 1
before that class of gap has been actively searched for on the record path too.
