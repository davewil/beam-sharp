# Brief — ticket 59 (ENG-241): the boundary guard applies two rules with different scopes

Status of the ticket: **open, left open.** This brief is evidence for David's decision; it decides nothing.
Written 2026-10-21 against the tree at this branch's HEAD. Probe ids (`59-p1` …) are in
`artifacts/probes/59/`; outputs in `artifacts/probes/results/`.

## What is true today (measured, not read from the ticket)

`59-p1`, emitted Erlang for the same body written exported and private:

```erlang
'PubTotal'(O) when map_get('Kind', O) =:= 'Scope.Order' -> map_get('Total', O).
'PrivTotal'(O) when map_get('Kind', O) =:= 'Scope.Order' -> map_get('Total', O).   % tag test: private too
'PubOctet'(N) when is_integer(N) andalso N >= 0 andalso N =< 255 -> N.
'PrivOctet'(N) -> N.                                                               % int test: exported only
```

So the ticket's table holds on the current compiler. Two things in it changed since it was written
(2026-08-23): F37 added the **range** half to the int guard, so the int test is now
`is_integer andalso >= andalso =<` (not the bare `is_integer` that 18 priced); and the corpus has
**no private function with a record parameter at all** (`59-p3`: of 31 modules bsc builds from
`compiler/examples`, 14 exported functions carry the tag test, **0** private ones do). The status quo costs
nothing measurable on shipped code, so no option below is justified by corpus bytes.

## The finding the ticket does not have: both guards leak through a nested value, and the private tag test is what catches half of it

`59-p2`, one module, forged inputs (`{Kind = :'Other.Order', …}` — wrong tag), run through `bsc`:

```csharp
record Order { Id: int, Total: int }
type Octet = int where value >= 0 and value <= 255

int PrivTotal(Order o)         PrivTotal(o) -> o.Total
public int Direct(Order o)     Direct(o)    -> PrivTotal(o)
public int ViaTuple((Order, int) p)   ViaTuple((o, n)) -> PrivTotal(o)
public int Inline((Order, int) p)     Inline((o, n))   -> o.Total          // no private function at all
```

```
Direct  : crashed: error:function_clause     (exported head has the tag test)
ViaTuple: crashed: error:function_clause     (exported head has NO test; the PRIVATE callee's tag test fires)
ViaList : crashed: error:function_clause     (same)
Inline  : 999                                (no test anywhere: the forged record is projected silently)
```

and the same path for the int test, where the private function has no guard:

```
OctetDirect(100.5)        : crashed: error:function_clause
OctetViaTuple((100.5, 1)) : 100.5     // an `Octet` that is not an integer, returned as Octet
OctetViaTuple((300, 1))   : 300       // an `Octet` out of range
```

The exported guard only looks at top-level parameters (`ViaTuple({O,_N}) -> 'PrivTotal'(O)` has no test). So
today the private tag test is the **only** check a forged record meets on a nested path into a private
function. This is the ticket's own "too narrow is a silent hole" direction, already live for the int
test and already half-covered by accident for the record. It also shows `Inline` is a hole under *every*
option below; closing it is a different change (guards on nested positions), not this ticket.

## Costs (what each scope pays)

`59-p4`, hand-written Erlang in exactly the emitted shape, compiled with `debug_info` as `bsc.erl:843` does, OTP 28 (the first draft of this probe omitted `debug_info` and roughly halved the byte figures; the verifier caught it):

| guard on a private function | bytes | per call (50M calls, best of 7) |
|---|---|---|
| tag test `map_get('Kind',O) =:= Tag` | **26.4 B** (100 functions: 2644 B) | ≈ 1.6–1.7 ns |
| int kind+range `is_integer(O) andalso O>=0 andalso O=<255` | **48.1 B** (100 functions: 4812 B) | ≈ 0.6 ns (0.58–0.67 in three runs; verifier 0.42–0.69) |

18's "+3–5 bytes, below ±0.09 ns" was `is_integer` alone; with F37's range it is larger. 26a's "+14 bytes" was measured without `debug_info`; I could not reproduce it as a figure for what bsc ships. Timings are wall clock on a shared 4-core container: treat the ns figures as ±0.3.

How neighbours place the same test (`59-p5`, Elixir 1.18.4, `Code.compile_string` then the debug-info
forms): a `defp` whose head says `%Probe{}` keeps `#{'__struct__' := 'Elixir.Probe'}` in the private
function's head. Elixir has no private/public distinction for *patterns*: the author writes the test where they
want it, and the compiler adds none. Gleam and Erlang add no runtime type test to any function (Gleam trusts its
types and its `@external` declarations — the repo's prototype `18c_gleam_ffi_trust`, which I did not re-run). So neither neighbour is a precedent for a
compiler-inserted guard at all; the question is B#'s alone.

## The options, as programs

**A — Narrow the tag test to exported functions** (18 §4 read literally).

```csharp
int PrivTotal(Order o)   // emitted with NO tag test
```
Compiler delta: `boundary_guards/6` already receives `Public` (`bs_emit.erl:195,265`); gate the record clause
on it, as the int clause already is. Saves ≈26 B and ≈1.6 ns per private record-taking function (zero
such functions in the corpus). Under A, `ViaTuple`/`ViaList` above go from **crash to silent 999**, i.e. they
become `Inline`.
*Strongest counterargument:* it turns a loud crash into silent wrong data on a path the ticket's own
author called out ("a forged record can reach a private function by being passed through an exported
one") — measured above, the path is real.

**B — Widen the int test to private functions** (one rule: every function guards every parameter whose
type it cannot prove from its own head).

```csharp
int PrivOctet(Octet n)   // emitted WITH is_integer/range
```
Compiler delta: delete the `Public` condition from the int clause and from `is_public/1`'s use there; F24's
tests and `check-boundary-kind.sh` change polarity for private functions. Costs ≈48 B and ≈0.6 ns per
private refined-int function. Under B, `OctetViaTuple((300,1))` becomes a `function_clause` crash.
*Strongest counterargument:* it reopens a decision 18 §4 and §5 took explicitly (guards are
exported-only; a private function is "the shape C wanted anyway"), and it taxes hot private helpers
(a numeric inner loop pays the range check on every iteration) to defend against a path that needs a
nested forged value to exist at all. It still does not touch `Inline`.

**C — Keep the asymmetry; write down why; file nested-position guards separately.**
Text, not code: the tag test is unconditional because 26 §1 says no body checks the tag, and it doubles as the
only net for nested forged records; the int test is exported-only because 18 §4 says so; the nested hole
(`Inline`, `OctetViaTuple`) is a named defect with its own ticket.
*Strongest counterargument:* the int test's nested hole stays open and nothing makes the asymmetry
principled — a reader who sees `PrivTotal` guarded and `PrivOctet` not will still ask this ticket's question.

## Recommendation

**B**, as the single stated rule — "a guard is emitted wherever a parameter's type is not proved by that
function's own head, exported or not" — because the cost is priced (≈48 B / 0.6 ns for the int test, ≈26 B / 1.6 ns for the tag test) and the failure mode it removes is the silent one, and the ticket itself says "too narrow is a silent
hole, too wide is measurable and loud." It also deletes a rule instead of adding one: the emitter would stop
consulting `is_public/1` for guards. Pair it with a separate ticket for guards on nested positions
(`Inline`), which no scope choice here fixes. If David prefers 18 §4 as written, **C** is the honest
fallback; **A** is the only option that makes a measured behaviour strictly worse and I would not take it.

## What I could not measure

- Any corpus-level cost of B: no shipped module has a private refined-int parameter whose guard would
  matter (`59-p3` counts one private clause that mentions `is_integer`, which may be the author's own `when`).
- Whether a hot-path private helper in a real program is slowed visibly; the ns figures are a micro-loop.
