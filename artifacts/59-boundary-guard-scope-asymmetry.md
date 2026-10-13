# Decision brief — ticket 59 (ENG-241): the boundary guard applies two rules with different scopes

**Status: OPEN. Nothing is resolved.** Prepared autonomously 2026-10-13. Probes are in
[`probes/59/`](probes/59/); the verifier section at the end records which a second agent re-ran.

## The one question

**Is a private function's parameter a boundary — for the record tag test, for the int kind test, or
for both?** Today the tag test says yes and the int test says no, and the ticket asks which of those
two is the error.

Measured, neither guard is a free-standing rule: both exist to stop a forged value from reaching a
body that would not notice it. So the single question is *can a forged value reach a private
function?* If it can, both guards belong there. The ticket's "defect" argument rests on "a private
function's every call site is a checked B# call site"; that premise is false, and the first probe
shows how.

## Evidence

**P1 — where the guards land today** (abstract code of the emitted beam, `probes/59/run.sh`):

| function | exported | param | guard emitted |
|---|---|---|---|
| `Direct(Inner i)` | yes | record | tag test |
| `ViaPrivate(Outer o)` | yes | record | tag test |
| `Helper(Inner i)`, called as `Helper(o.In)` | no | record | **tag test** |
| `Helper2(Inner i)`, called only as `Helper2(Inner{ N = n })` | no | record | **tag test** (provably redundant — the caller built the record one line above) |
| `Built(int n)` | yes | int | `is_integer` |

**P2 — the tag test on a private function is the only thing that catches a forged nested record.**
Erlang caller passes `#{'Kind' => 'P59.Outer', 'Id' => 1, 'In' => #{'Kind' => 'Other.Inner', 'N' => 666}}`
to `ViaPrivate`. The exported guard checks `Outer`'s tag and not `In`'s.

| build | `ViaPrivate(forged inner)` |
|---|---|
| HEAD | `function_clause` raised in `Helper` |
| tag test restricted to exported (`variant-vN.diff`, 11 diff lines) | **returns `666`, silently** |

**P2b — the int test has the same hole today.** Record `Gauge { Level: Byte }`; exported
`Read(Gauge g) -> Next(g.Level)`; private `Next(Byte b) -> b + 1`. Erlang caller forges `Level`.

| `Level` | HEAD | int test also on private (`variant-vW.diff`, 11 diff lines) |
|---|---|---|
| `7` | `8` | `8` |
| `999` (outside `0..255`) | **`1000`** | `function_clause` |
| `1.5` | **`2.5`** | `function_clause` |
| `not_a_number` | `badarith` | `function_clause` |

**This is a live case of exactly what ticket 18 §1 says C refuses**: a wrong term from outside
producing a wrong answer "silently". `0..255` is the declared domain of `Next`'s parameter and
`Next` returned `1000`.

**The limit, stated up front.** Neither widening closes the shape where the exported body reads the
field itself: `Inline(Gauge g) -> g.Level + 1` returns `1000` for `Level = 999` under HEAD *and*
under the widened build (P2b, last line). Guards are shallow and per-parameter by 18 §4's design.
Option 1 below closes the **call-boundary** route to a forged nested value, not every route.

**P3 — cost** (`measure.sh`, `corpus_cost.sh`, `absdump.sh`; OTP 28.5, one machine, two runs each):

| | HEAD | tag test exported-only | int test on private too |
|---|---|---|---|
| Code chunk, 1 private record fn (`measure.sh`) | 270 B | **256 B (−14)** | 270 B |
| file size | 1772 B | 1720 B | 1808 B |
| ns per loop iteration calling a private record fn | 12.21, 12.23 | 11.52, 11.81 | — |
| ns per loop iteration calling a private `Byte` fn | 10.10, 10.17 | 10.11, 10.24 | 10.25, 10.15 |
| Code chunk, 19 example modules (sum) | 8872 B | 8872 B | 8872 B |

Reading it honestly: the tag test costs **14 bytes and roughly 0.4–0.7 ns per call**; the BEAM
compiler (`beam_ssa_type`) removes the widened int guard from the `Code` chunk when the only caller
already proved it (`absdump.sh` shows the guard present in the abstract code and the Code chunk
unchanged at 119 B), so widening it measured **zero where the caller proves the type**. The verifier built the other case — a list element passed into a private `Byte` function — and the Code chunk grew **183 → 201 B (+18)** under the widened build, with no per-call slowdown visible in 3 runs. So widening is free only when proven redundant, and costs about 18 B per unprovable site. Two caveats against over-reading the zero:
the 19-module corpus contains no private function whose caller *cannot* prove the type (a value
from `Dictionary`, a list element), which is the case where widening would cost; and a
file-size difference of +36 B appears with the widened build that I did not trace (probably debug
or line metadata). `Fib(20000)` timed 14.3–15.1 ms across the three builds, which is bignum
addition and not guard cost.

## Neighbours

| | what a private function takes on trust | evidence |
|---|---|---|
| Gleam 1.19.0 | everything; no guard anywhere, even on a `pub fn` called from Erlang | `add(1.5, 2.5)` from Erlang → `4.0`; `via_private({outer,1,{wrong,666}})` → `666` (`neighbours/gl`) |
| Elixir 1.18.5 | what its own patterns say | `defp helper(%Inner{} = i)` → `FunctionClauseError` on a forged struct; `defp helper_nomatch(i)` → `666` (`neighbours/ex.exs`) |

Elixir's two rows are 18 §1's cases (a) and (b) in miniature: a pattern that names the type is a
guard, a bare variable is not. B# is already ahead of both neighbours by emitting the guard for the
author; the question is only how far that reaches.

## Options

### 1 — one scope for both: every function guards its own parameters (recommended)

```erlang
%% bs_emit.erl guard_one/7: delete `when Public` from the int/float arm
        none ->
            case kind_only(TypeExpr, Ctx) of ...
```

Compiler delta: remove one guard and the `Public` parameter that becomes unused (the build refuses
an unused variable — `variant-vW.diff`). No new analysis; the rule stays function-local as 18 §4
requires.

Program that changes: `Next(g.Level)` with a forged `Level` stops answering `1000` and raises at
`Next`.

**Strongest counterargument.** It reverses the sentence in the emitter and in 18 §4 that the
asymmetry is "deliberate" and that eliding private-function guards "is the shape C wanted anyway".
The savings that sentence prized measured zero for the int test here, but only on code whose callers
prove their arguments; in a private helper fed from a list element the guard will cost a test per
call that nothing proves redundant, and the verifier built it (+18 B, see P3). If David's priority is "a tight
private loop pays nothing", this is the option that can lose it.

### 2 — keep the tag test private-wide and the int test exported-only, and write the rule down

The status quo plus an amendment to 18 §4: *the tag test is unconditional because a record is only
checked one level deep; the int test is exported-only because a private function's callers are
checked.* No compiler change.

**Strongest counterargument.** The second clause is false, and P2b is the program that shows it: a
private function's caller is checked, but the *value* the caller passes was read out of an
unvalidated nested field. The rule would be written down with a counterexample in the same ticket.

### 3 — narrow the tag test to exported functions

Compiler delta: `constrains_kind(Pat) orelse not Public` (`variant-vN.diff`, 11 diff lines). Matches
18 §4's text, saves 14 B per private record function, and costs the P2 result: `666` returned
silently for a forged nested record.

**Strongest counterargument.** To make it safe the exported record guard has to look one level
further down (the second-tier exact-field test, which F3/26 §1 currently emit only where a codegen
obligation consumes the record). That is O(fields) on every exported record parameter, which is a
larger price than the 14 bytes it saves, and I did not measure it.

## Recommendation

**Option 1**, with the limit above copied into 18 §4 so the guarantee is stated as what it is:
*every function checks its own parameters at entry; a forged value read out of a field and used
inline is not covered.* It is the only option under which the two guards follow one rule and the
only one whose hole is describable in a sentence. Option 3 is the one that most contradicts the
program the ticket's own "defect" side wants to ship, per P2.

If David wants the tight-loop guarantee, the follow-up measurement to run first is one private
helper called with a list element and a value from a map, built and timed under HEAD and Option 1.

## Corrections to the ticket's text

- It cites `bs_emit:boundary_guards/4`; the function is `/6` today (`bs_emit.erl:265`) and the
  comment above the kind guard (`bs_emit.erl:330-333`) already records the asymmetry as deliberate.
- "A private function's every call site is a checked beam-sharp call site" is the premise of the
  defect argument and of F24's scoping. It holds for the *call*, not for the *values* — P2 and P2b.

## Reproduce

```
export BSC=compiler/_build/default/bin/bsc
artifacts/probes/59/run.sh           # P1 guard placement, P2 forged nested tag
artifacts/probes/59/nested_int.sh    # P2b, run once per BSC (HEAD, then a build with variant-vW.diff)
artifacts/probes/59/measure.sh       # P3 bytes and ns
artifacts/probes/59/corpus_cost.sh   # P3 corpus
artifacts/probes/59/absdump.sh       # guard present in abstract code, absent from Code chunk
# variants: variant-vN.diff (tag test exported-only), variant-vW.diff (int test on private too)
#   apply to a COPY of compiler/ with src/bs_parser.erl and src/bs_lexer.erl deleted first
```

## Verifier result

(filled in below by the independent re-run)

**Verifier addenda.** Exported *list* parameters are not checked per element either: a forged 999 inside a `list<Byte>` reached a private `Bump` under HEAD and was refused only under the widened build — the same shallow-guard limit as `Inline`.
