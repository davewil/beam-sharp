# F24 — An `int` parameter is an integer, at the exported boundary

**Status**      **done 2026-08-23** · [ENG-240](https://linear.app/davewil/issue/ENG-240) —
                492 tests, nineteen gate scripts. The first feature whose ticket was a
                **defect** rather than a question: nothing here was decided by this work
**Implements**  [ticket 58](../../wayfinder/issues/58-refined-int-admits-a-float.md), and through
                it [ticket 18](../../wayfinder/issues/18-boundary-defence.md) §1 rule C case (b),
                §4 (exported only, function-local) and §5 (no opt-out) — decided 2026-08-13 and
                never in the emitter
**Unblocks**    nothing. It closes ticket 18's **outcome 3**, *"the only outcome that makes the
                type system a lie"*, on the one type the corpus publishes a refinement of. It is
                also the first half of the guard [ticket 46](../../wayfinder/issues/46-refined-parameter-at-the-boundary.md)
                specified, whose second half is still unbuilt
**Depends on**  F2 (interval refinements, which is what made a lying `-spec` visible), F3's
                `boundary_guards/4` (the machinery, written for the record tag), F12 (`is_public/1`)

## Why this one now

Ticket 46 resolved on 2026-08-23 and raised 58 beside it. 58 is a defect with a decision already
attached, which is the cheapest possible shape: no survey, no options, one rule read onto an
emitter that had never had it.

## The measurement

Before, on `examples/Wire`, whose `Classify` publishes `-spec 'Classify'(0..255)`:

```
$ bsc --src-root examples examples/Wire Classify 100.5
:reserved
$ bsc --src-root examples examples/Wire Band 100.5
:mid
```

After:

```
$ bsc --src-root examples examples/Wire Classify 100.5
crashed: error:function_clause
$ bsc --src-root examples examples/Wire Classify 100
:reserved
```

## The premise this feature had to correct before it could start

**Ticket 58 says ticket 46's guard is emitted. It is not.** 58's argument runs *"46's emitted
`Bs@r1 >= 0 andalso Bs@r1 =< 255` narrows within the numeric tower and does not close it"*, which
reads as though the range half were already in the compiler and this feature were adding the other
half beside it.

Measured at `2b97180`, the emitted `Wire` module contains **no range guard anywhere**. The
`Bs@r1 >= 4 andalso Bs@r1 =< 7` in its heads is F2's **relational pattern** — ticket 42's lowering
of `Classify(>= 4 and <= 7)`, which has been there since 2026-08-15 — and not a boundary guard.
Ticket 46 is a `wayfinder:decision`, resolved the same morning, with no feature file and nothing
built. So both halves of the guard were unbuilt, and this one is being built first.

The correction is recorded in ticket 58 and in ENG-240 rather than only here, because a false
premise inside a defect report is the kind of thing a later session reads as established.

## 1. Why this could not be derived from ticket 46's subtraction — the trap

Ticket 46's answer is a **subtraction**: given the declared type `D` and the type `P` the clause
head accepts, emit comparisons for `P \ D`. It is a good answer and this feature does not touch it.
It is also the obvious thing to reach for here, and reaching for it would have produced a green
suite over an unfixed defect.

`Classify(100.5)` reaches the **`Classify(>= 9)`** clause, because `100.5 >= 9` is true. In the
integer algebra that clause accepts `int >= 9`, so 46's subtraction against `0..255` yields
`int >= 256` and emits `=< 255`. And `100.5 =< 255` is true.

So a range-only fix produces this:

| call | before | range-only "fix" | F24 |
|---|---|---|---|
| `Classify(300.5)` | `:reserved` | **crashes** | crashes |
| `Classify(100.5)` | `:reserved` | **`:reserved`** | crashes |

The reported defect survives, asymmetrically, and only the *easier* half of it moves. A gate built
around `300.5` — the value that reads like the natural probe, being outside the range — goes green
over it. **`check-boundary-kind.sh`'s probe 1 is therefore `100.5`, and its self-test carries a
RANGE stub** that implements 46's answer exactly and must be caught.

The root of it is one sentence: **a comparison proves ordering, not kind.** `100.5 >= 0` and
`foo >= 0` are both true, the second by BEAM term order. Where a wrong-kind term is excluded today
it is the ordering doing it by accident, and 18 §1 already refuses to rest on that.

## 2. What is emitted, and where

`erlang:is_integer/1`, in the clause head, **before** the clause's own comparisons —
`is_integer(X) andalso X >= 4 andalso X =< 7`. Ticket 58 states that order (*"`is_integer/1`
first, then the residual comparisons"*). It is not a correctness requirement, since a comparison in
a guard cannot crash and `andalso` reaches the type test either way; it is the order the two halves
compose in once 46's residual lands, and it short-circuits a wrong-kind term on one test.

**On a parameter whose declared type is int-only** — every part of the resolved type empty but the
integer part. A refinement is a subset of `int` rather than a type beside it (20 §5), so `Octet`
and `int` arrive as the same shape with different ranges and neither is special-cased. A union such
as `int | :none` gets nothing: its atom part is a second admissible kind. That refusal is 18(d)'s
conservative direction rather than a gap, and it is the one case where 18(d) is read as *do not
emit* — because there the parameter genuinely has two kinds, and no single test decides it.

**Unless the clause's own pattern pins the kind.** An integer literal is 18 §1(a)'s *the body
already objects*: `Only(1)` does not match `1.0`, which the suite asserts rather than assumes. A
disjunction needs both arms pinned, a conjunction needs one.

**A RELATIONAL PATTERN DOES NOT PIN THE KIND**, and this is the case the feature turns on.
`strip_rels/1` runs before the boundary guard, so `Classify(>= 9)` arrives as a bare variable and
is correctly found to pin nothing. Had it still been a `p_rel` the temptation would have been to
call it constrained.

**Exported only**, by 18 §4. A private function's every call site is a checked beam-sharp call site,
so site 1 has already rejected the out-of-domain argument.

## 3. The asymmetry with the record tag guard, inherited on purpose

The tag test beside this one is emitted on **private** functions too. Ticket 46 measured that and
called it *"the record guard's business against 18 §4, not this ticket's"*. F24 does not fix it and
does not copy it: the new test is exported-only per 18 §4, and the record guard is left as it was.
So `boundary_guards/5` now applies two rules with different scopes, which is a known inconsistency
with a named owner rather than an oversight. **It is worth a ticket and does not have one.**

## 4. Cost, measured on the corpus

**9 of 15 modules changed; 34 type tests added.** Every one is a guard insertion — the diff contains
no other change. Ticket 18 measured the bytecode cost of `is_integer` at **+3–5 bytes** and the call
time at or below its ±0.09 ns/call resolution, so nothing here needed re-measuring.

Two shapes in that diff are worth naming:

- **`_Head` became `Head`.** A parameter the body never mentions lowered to `_`-prefixed, and a
  guard referencing an underscored variable is a compile error in the emitted Erlang. The existing
  comment predicted this exactly and the ordering that prevents it was already in place.
- **OTP callbacks are guarded.** `init(Seed) when erlang:is_integer(Seed)` in `Counter`, and
  `handle_call(get, _From, State) when erlang:is_integer(State)`. These are genuine foreign
  boundaries — OTP calls them with whatever `start_link` was handed — so the rule applies by its own
  terms. Dialyzer accepts every one.

## 5. Out of scope, and what each owes

**The other kind channels.** `atom`, `binary`, `tuple` and `list` parameters are the same rule with
a different test and are **owed, not decided differently**. `int` is built first because it is
18 §1(b)'s own worked example and the type the corpus publishes a refinement of.
`a_non_int_parameter_is_untouched_test` pins the boundary as a measurement so it cannot drift from
this sentence.

**Ticket 46's range half.** Still unbuilt. `Classify(300)` — an out-of-range *integer* — is still
accepted and returns `:reserved`. F24 closes the kind channel only, and 46's answer is a complete
specification of the other one.

**A refined `int` below the top of a parameter.** `handle_call({add, N}, _From, State)` guards
`State` and not `N`, so a float still reaches `State + N` one projection deep. Ticket 46 §4 already
decided this should be reached — *"a fixed number of projections, not a depth limit"* — so this is
a known open edge with a decision attached, exactly like the range half. Ticket 58 measured whole
parameters and this feature built what it measured.

**Inspectability.** A `function_clause` on `Classify/1` does not say *"100.5 is not an `Octet`"*.
18 §7 handed that to ticket 23 and 46 §3 added an instance; this adds a third rather than inventing
an error channel beside it.

## Scenarios

| id | scenario | expected |
|---|---|---|
| F24.1 | `Classify(100.5)` where `Classify(Octet)` and the matching clause is `>= 9` | `function_clause` — no value returned |
| F24.2 | `Classify(100)`, a valid `Octet` | `:reserved` — the domain is unaffected |
| F24.3 | the emitted head of a relational clause and of a bare-variable clause | both carry `erlang:is_integer/1` |
| F24.4 | the emitted head of `Only(0)` / `Only(1)` over a two-value domain | no type test — the literal already objects |
| F24.5 | `Add(1.5, 2.5)` where `int Add(int a, int b)` | `function_clause`, and one test per int parameter |
| F24.6 | a private `Inner(int n)` beside an exported `Outer(int n)` | `Inner` unguarded, `Outer` guarded |
| F24.7 | `Echo(atom a)` | untouched — the kind channel for `atom` is owed |

## Done when

- [x] `bsc examples/Wire Classify 100.5` returns no value, and `Classify 100` still answers
- [x] `boundary_kind_tests` covers all seven scenarios; 492 tests pass
- [x] `check-boundary-kind.sh` exists, has been **seen to go red** on the real defect, and its
      self-test catches a SILENT, a CRY-WOLF and a RANGE stub on different probes, passes the
      decided behaviour, and refuses a run that never compiled
- [x] the gate is wired into `ci.yml` **and** `.claude/end-session.md` — three edits, not two
- [x] Dialyzer accepts every emitted spec; the corpus diff is guard insertions and nothing else
- [x] ticket 58's false premise about ticket 46's emitted guard corrected in place, in the repo
      file and in ENG-240
