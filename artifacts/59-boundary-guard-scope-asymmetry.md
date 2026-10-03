# Ticket 59 (ENG-241) — decision brief: who gets a boundary guard, private functions included?

Status: **evidence brief, nothing resolved, nothing edited outside `artifacts/`.** Compiler HEAD `5133d97`,
OTP 29 / Elixir 1.20.4 / Gleam 1.18.1, x86_64 JIT, 4 shared cores (repo pins OTP 28.5 on arm64: no number
below is comparable to 18a's). Probes: `artifacts/probes/59/` (`run.sh` rebuilds everything; `NN-*.out` captured).
Prototype compilers are patched **copies** of `compiler/src` built in scratch, labelled PROTOTYPE throughout.

## 1. The gating question, alone

> **Is a private function's record parameter safe because every call site is a checked B# call site?**

18 §4 / F24 §2 / 46 §1 all rest on that sentence for the int test. It is the only premise the two sides of the
ticket disagree about, so it is decided first and the scope of the int test follows from it.

**Measured: the premise is true for a handed-on parameter and false for a projected field.**
Program (`b/Forge/forge.bs`, abridged):

```csharp
record Order { Id: int, Total: int }
record Cart  { Item: Order, N: int }

int Amount(Order o)                      // private
Amount(o) -> o.Total

public int Direct(Order o)               // parameter handed on
Direct(o) -> Amount(o)
public int ViaCart(Cart c)               // field projected out
ViaCart(c) -> Amount(c.Item)
public int InlineCart(Cart c)            // same read, no helper
InlineCart(c) ->
    var i = c.Item
    i.Total
```

A foreign Erlang caller (and an Elixir caller, same results, `02-b-forged.out`) passes a map tagged
`Forge.Invoice`, `Total = 999`:

| call | shipped compiler | PROTOTYPE-A (no tag test on private) |
|---|---|---|
| `Direct(invoice)` | `function_clause` (at `Direct`) | `function_clause` (at `Direct`) |
| `ViaCart(Cart{Item=invoice})` | `function_clause` (at `Amount`) | **returns 999** |
| `ViaList([invoice])` | `function_clause` | **returns 999** |
| `InlineCart(Cart{Item=invoice})` | **returns 999** | **returns 999** |
| `ViaCart(Cart{Item=Order-tag, no Total})` | `badkey` | `badkey` |

Three findings fall out, each bearing on the ticket's two paragraphs:

1. **The ticket's "forged record through an exported function" argument conflates two paths.** A *parameter*
   handed on is guarded by the exported function itself (`Direct` row: loud in both builds), which is exactly
   18 §4's "a value handed to another function counts as unchecked, and is guarded". A *field projected out of a
   parameter* is reached by neither guard: `Cart`'s tag test says nothing about `c.Item`. The private callee's
   tag test is the only thing that catches it, and only by accident.
2. **That accidental coverage depends on whether the author extracted a helper.** `ViaCart` (loud) and
   `InlineCart` (silent 999) compute the same thing. Extract-method changes the observable boundary of the
   *exported* function. 18 §4 chose function-local analysis so that "a guard can only move when you edit the
   function it sits on" (`18:842`); the private tag test breaks that property.
3. **The int test has the identical hole today and nobody calls it one.** `ViaOctets(list<Octet>)` calling
   private `Classify(Octet)`: `[100.5]`, `[300]` and `[<<"x">>]` all return `big` on the shipped compiler
   (`<<"x">> >= 9` is true in term order). The wide prototype turns all three into `function_clause`.

So the honest answer to the gating question: **"site 1 already rejected it" holds for values constructed in B#
and for handed-on parameters; it fails for anything nested inside a foreign-supplied container, because the
exported boundary checks the container's tag in O(1) and the checker then trusts the declared field type.**
That is 18's depth limit, not 59's; see §6.

## 2. Sub-decisions, in dependency order

| # | question | answer from evidence |
|---|---|---|
| S1 | Is the private tag test a defect against 18 §4? | **Against its letter, yes** ("exported function's own clause heads and body, and no further", `18:815`). Against its stated reason, no: the reason (call sites are checked) is false at depth >= 1 (§1). It is neither a defect nor "§4 working": §4's guarded-hand-on rule concerns the exported function's *own* parameter, which `Direct` shows is already guarded. |
| S2 | Is "exported" the right discriminator? | **For the int test, yes; for the tag test the BEAM gives no support either way.** `d/Elide`: the BEAM compiler keeps the tag test on a private fn even when its only caller passes a literal record (`OnlyLit`) or a value the caller just tag-tested (`AfterTest`); it tracks `t_map` and integer ranges but not map-key values. It *does* drop a private `is_integer` when the argument is provably integer (`IntFromProven`: `{tr,x0,t_integer}`, test gone in the WIDE build) and keeps it when not (`IntUnproven`). So 18 §1's "un-exported => test elided entirely" is true of the kind test only where the caller proves it, and false for the tag test. |
| S3 | Can a forged record reach a private function through an exported one, and does function-local analysis trace it? | **Yes, by projection or list element; no, it does not trace it** (§1 table). It does trace a handed-on parameter, correctly. |
| S4 | Scope of the int KIND test? | Follows S1. If the private tag test goes, the int test stays exported-only and the rule is one sentence. If the tag test stays, the int test has no principled reason to differ (§1 finding 3). Pinned today by `boundary_kind_tests.erl:88` (F24.6) and `boundary_range_tests.erl:120` (F37.5). |
| S5 | Cost widened vs narrowed | §4 below. |

## 3. Three options, each a program that behaves differently

The delta for every option is in `bs_emit:guard_one/8` (`bs_emit.erl:275`), which already receives `Public`
(`:163`, via `is_public/1`). Nothing else in the emitter changes.

### Option N — both guards exported-only (narrow the tag test)

```csharp
public int ViaCart(Cart c)  ViaCart(c) -> Amount(c.Item)    // forged Item: returns 999, same as InlineCart
```
Delta: `bs_emit.erl:278` `case constrains_kind(Pat) of` becomes `case constrains_kind(Pat) orelse not Public of`
(`prototype-tag-exported-only.patch`, 1 line). The comment at `:332` ("emitted on private functions too; that
asymmetry is deliberate") is deleted; add a test beside F24.6 pinning "private `Inner(Order o)` carries no
`map_get`". `Direct(forged)` is still `function_clause`. Corpus: **0 of 21** compilable example modules change
(`08-h-corpus.out`); the corpus has no private record-parameter function, so no existing test or example pins
the behaviour being removed. (Whether the eunit suite stays green is UNMEASURED: rebar3 is broken here.)

### Option S — keep the asymmetry, say why (status quo)

Rule stated once: *the tag test is emitted everywhere because identity is invisible to bodies and to call-site
types; the kind test exported-only because a body that computes objects.* Delta: comment-only rewrite at
`:332`, a pinning test for the private tag test (none exists; 46 only measured it), and F24 §3 amended. `ViaCart`
stays loud, `InlineCart` stays silent.

### Option W — both guards on every function (widen the int test)

```csharp
Level Classify(Octet n)                       // private; today unguarded
public Level ViaOctets(list<Octet> ns)        // [100.5] / [300] / <<"x">> now function_clause
```
Delta: `bs_emit.erl:284` `none when Public ->` becomes `none ->` (`prototype-kind-everywhere.patch`; the trailing
`none -> {Pat, []}` clause becomes dead). It widens the whole `int_guard/6`, so a private refined `Octet`
also gets its range arms (seen in `02-b-forged.out`). Flips F24.6 and F37.5. Corpus: **5 of 21** modules change,
**+19 `is_integer`** (Fib, Foreign, Frame, Pipeline, Shop.Collections.Ints). `InlineCart` is **still** silent.

## 4. What each costs (all on this machine, OTP 29 x86_64; method and resolution stated)

**Bytes** (`03-c-bytes.out`; `Code` chunk, N private functions per module, base vs prototype):

| guard on a private fn | N=1 | N=20 | per fn |
|---|---|---|---|
| record tag test | +12 B | +267 B | **~13.4 B Code** (stripped file +6.3 B/fn: shared atoms) |
| `is_integer` (plain `int`) | +5 B | +113 B | **~5.7 B Code** (stripped +2.8 B/fn) |

Matches 26a's +14 and 18a's +3-5. Native size (`+JDdump`, `04-d-elision.out`): tag test removes 6-7 JIT
instruction lines from a private fn (`Unproven` 45->39, `AfterTest` 39->32, `OnlyLit` 38->31, `Mid` 24->11), but **0
from `Leaf`** (39->39) because the body's own `map_get` must then check `is_map` itself; `is_integer` adds 9 lines
to `IntUnproven` (28->37) and 0 to `IntFromProven`.

**Call time** (`05-e-calltime.out`, `05b-…first-full-run.out`: 2 full runs, each 15 fresh VMs per variant pinned to
one core, variants rotated per round, 5e7 iterations, ns per loop iteration of a loop that also does 3 `map_get`):

| comparison | run 1 | run 2 | controls (run 1 / run 2) |
|---|---|---|---|
| tag test removed on private callee (proto - base), median | **-3.28** | **-3.22** | same-code `LoopCtl`: -0.78 / -0.43; A/A base vs byte-identical copy: +0.42 / +0.70 |
| same-module A/B, record callee vs structural callee | +2.73 | +7.60 (base `LoopRec` IQR 2.9, run discarded as evidence) | A/A of the structural loop -0.72 / +0.21 |
| `is_integer` added on private callee (wide - base), median | -0.77 | -0.37 | A/A +0.39 / +0.16 |

**Resolution actually achieved: about +/-1 ns per call**, not 18a's +/-0.09: the A/A and same-code controls move by up
to 0.8 ns and IQRs are 0.6-3.9 ns. Reading: the tag test is **detectable and ~3 ns per call** (consistent across two
runs, 3-4x the controls, ~15-18% of that loop), which contradicts 26's "the tag itself costs nothing measurable" as
a statement about *this* test-vs-no-test comparison (26 compared tagged map vs map, both guarded). The `is_integer`
cost is **UNRESOLVED below ~1 ns**, and its wrong sign is noise, not a speed-up. Nothing here generalises beyond
a call-heavy micro-loop; one entry label means an exported function pays the same guard on in-module calls (18, not
re-measured).

## 5. Strongest counterargument to each, and who else guards where

| option | strongest counterargument (against the option) |
|---|---|
| **N** | It removes a guard that, in the shipped compiler, turns a silent `999` into `function_clause` (`ViaCart` row). That is a measured safety regression for anyone relying on it, bought for ~3 ns and 13 B, and it moves *toward* the silent side of the ticket's own "too narrow is a silent hole, too wide is loud" rule. |
| **S** | The rule it states is two rules, and one of them contradicts the section the other cites. Coverage is refactor-dependent (`ViaCart` vs `InlineCart`), partial (tag only: right tag with no `Total` is `badkey`, not `function_clause`), and a stranger implementing B# against the oracle must reproduce an accident to pass conformance. |
| **W** | It makes every private helper pay for a defence that only matters when a foreign-supplied container holds a bad element, and still does not close that hole (`InlineCart`). It also reverses two pinned decisions (F24.6, F37.5) and 18 §4 ("no further") for a guarantee it cannot deliver. |

**Neighbours** (`06-f-…out`, `07-g-…out`; Elixir sources fetched at tag v1.20.4 into `f/src/`, because the install
ships beams only; Elm UNMEASURED, see Limits):

| language | who guards, and where | evidence |
|---|---|---|
| Erlang | Nobody inserts a guard. A record in a head is a hand-written runtime match, public or private: `try_handle_call(#server_data{...}, ...)` is unexported and compiles to `is_tagged_tuple {x0},_,order`. `-spec` is erased: `spec_only(1.5)` returns `2.5`. Dialyzer not run (UNMEASURED). | `gen_server.erl:2468`, `-export` at `:190-216`; `f/run_erlang.sh` |
| Elixir | The author writes `%Order{}` in a head; `def` and `defp` heads are identical (`amount(#{'__struct__' := 'Elixir.Probe.Order', ...})`). `@enforce_keys` is enforced only in the generated `__struct__/1` at construction; a pattern in match context only asserts keys exist. A forged map without the enforced key passes through `via_cart` (returns 7). `defp amount_raw(o)` with no pattern returns the forged 999. | `elixir_map.erl:33-44`, `utils.ex:176-205`; `f/elixir_defp.exs` |
| Gleam | No guard at any visibility; public and private bodies are byte-identical Erlang (`element(3, O)`), both get a `-spec`. Privacy and `opaque` are compile-time: `token_value({token,<<"x">>})` returns `<<120>>`. A destructuring `let Order(..) = o` is a tuple match (`badmatch`) public or private: the *pattern* is the test. | `07-g-gleam.out` |
| Elm | No per-function guards. A decoder is synthesised from the port type and runs on every incoming value, deep and field by field, at the one door. Records carry no tag. | `research/18-elm-port-validation.md:216-250,427-443` (not re-run) |

No neighbour guards at a private function, and none guards by *visibility*: either the author writes the pattern
(Erlang, Elixir, Gleam), or the compiler guards at the one door it owns (Elm). B# is the only one with
compiler-inserted guards at all, so the private-vs-public choice has **no precedent**, only 18's principle that
checking belongs at a door you own.

## 6. Recommendation

**REVISED after verification: Option S now, with Option N only after the depth-hole ticket lands. Confidence: moderate.**

*(The original text below recommended N first. The independent verifier found that the brief's own forged-record table shows the private tag test is the only thing catching forged nested and list records, so N opens a safety window before the real fix; see 'Verifier findings' at the end. The original reasoning is kept for the record.)*

~~Option N, sequenced with a new ticket for the depth hole.~~ (superseded)

Reasons, in order of weight: (a) N is the only option under which an exported function's observable boundary does
not change when the author extracts a helper, which is the property 18 §4 chose function-local analysis to
protect; (b) it makes the spec one sentence ("boundary guards live on exported functions"), which is what the
clean-room handoff needs; (c) the private tag test never was the guarantee: it catches depth-1 tag forgery only
when a helper happens to exist, and misses right-tag-wrong-shape, so deleting it deletes an accident, not a
defence; (d) cost is real but small (13 B, ~3 ns) and corpus churn is zero.

**What N concedes, stated plainly:** `ViaCart` goes from loud to silent for forged nested records. That is the
strongest objection and I do not think the numbers answer it. It is answered only by closing the hole at the door.

**New finding to raise as a ticket, not decide here:** 18's sentence *"a foreign term that breaks your types will
crash, never silently"* is **false at depth >= 1 in the shipped compiler** (`InlineCart`: silent 999; `ViaOctets`:
silent `big` for a binary). 18 §2 gave foreign declarations `ValidateAs<T>` for this; exported B# functions with
`Cart`/`list<Octet>` parameters get nothing. The question for David is whether the guarantee is meant to be shallow
(then 18's wording needs a clause) or deep (then the exported guard must walk the type, and both the private tag
test and W become dead weight). If David will not accept the window between N and that ticket, **S** is the safe
interim, with the comment at `bs_emit.erl:332` rewritten to state the rule above.

**What would change this recommendation:** a measured case of a private record helper being the *only* thing
between a forged term and a corrupting side effect in a real program (none in the corpus); or a decision that
18's guarantee is deep, which makes the question moot.

## 7. Evidence index (`artifacts/probes/59/`)

| file | establishes |
|---|---|
| `01-a-emitted.out` | tag test on `PrivAmount` and `PubAmount`; `is_integer` on `PubInt` only; BEAM folds `PrivInt` to a constant when its sole caller passes `1` |
| `02-b-forged.out` | §1 table, shipped vs PROTOTYPE-A vs PROTOTYPE-W; Erlang and Elixir callers |
| `03-c-bytes.out` | byte deltas, N=1 and N=20 |
| `04-d-elision.out` | BEAM asm with `{tr,…}` type annotations and JIT listing; elision of `is_integer` but not the tag test |
| `05-e-calltime.out`, `05b-…` | two full call-time runs, min/median/IQR, A/A and same-code controls |
| `06-f-elixir-erlang.out`, `07-g-gleam.out` | neighbours; `f/src/PROVENANCE.txt` for fetched Elixir sources |
| `08-h-corpus.out` | 0 / 21 modules change under N; 5 / 21 and +19 `is_integer` under W |
| `prototype-*.patch`, `build-bsc.sh`, `run.sh`, `00-env.out` | how the PROTOTYPE compilers were made; versions |
| `failed/NOTES.txt` | every superseded or refused probe and why it changed |

## 8. Limits

- **Elm: UNMEASURED this session.** `elm make` needs `package.elm-lang.org`; the egress proxy returned 403 and I did
  not route around it. The Elm row cites 18's own research file, which was `local` on 2026-08-13.
- **Dialyzer: UNMEASURED** (no PLT built). Erlang `-spec` erasure is shown at runtime only.
- **Whole eunit suite and gates: not run** (rebar3 broken on OTP 29). "No existing test pins the private tag test" comes
  from grep of `compiler/test/`, not execution. `verify.sh` twice-from-clean is owed to whoever lands a change.
- **Call time is +/-1 ns resolution on a shared 4-core x86 VM**; run 2's same-module figure (+7.60) is inflated by
  base noise and not relied on. The `is_integer` cost is unresolved, not zero. Not measured: OTP 28.5, arm64, cold or
  megamorphic call sites, in-module calls to an exported guarded function.
- **7 exemplar directories** (`examples/exemplars/25*`) produced no `.abstr` under my invocation (not investigated, may
  need other flags); the 0/21 and 5/21 corpus counts cover the 21 that did.
- Forged-term probes call exported functions from Erlang/Elixir; they show what the compiled code does, not how likely
  such a caller is. The Elixir/Gleam sources read are tag `v1.20.4` upstream and the generated `.erl` respectively.
- Prototypes alter one guard site each and were not run against the eunit suite; "N changes 0 modules" is about
  emitted `.abstr` over the corpus only.
- Nothing was tuned until it passed; the three probe fixes and two checker refusals are in `failed/NOTES.txt`.

## Verifier findings (independent re-run, see probes/59/VERIFY.md)

Measurements REPRODUCED (all three compilers rebuilt from a fresh `compiler/src`; every row of the
forged-record table matches); no circular probe: prototype patches differ from shipped by the guard
line plus a comment, fixtures are plain maps, `InlineCart`/`ViaCart` differ only in extraction, BEAM
elision claims hold in the disassembly.

- **The recommendation was NOT SUPPORTED by the evidence** and is revised above: the private tag test
  is the only thing that catches a forged nested or list record, so narrowing first (N) leaves a window
  of silent wrong answers before the depth fix the brief itself calls the real one. S as interim fits the
  evidence at least as well.
- **Timing resolution:** removing the tag test saves 2.9-3.4 ns, but the same-code control reads about
  -0.8, so the effect is nearer 2.5 ns. The `is_integer` cost flips sign across runs (+0.07, -0.21,
  -0.29): unresolved. The same-module A/B is unstable (+3.2, +2.5, -1.0) and must not be cited.
- **Corpus claim** "no private record function" covers the 21 modules only; the 7 skipped exemplars are
  not modules.
- Elm unmeasured (registry 403), as stated.
