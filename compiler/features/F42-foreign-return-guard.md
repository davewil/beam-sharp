# F42 — the boundary guard on a foreign return

**Status**      **done 2026-09-11** — 13 tests in `foreign_guard_tests`; four abstract-code
                assertions in `foreign_wrapper_tests` and `ffi_tests` moved off the bare-call
                shape they read "no wrapper" from; 798 in the suite, up from 785. No new gate:
                no gate reads a program's runtime output, so the crash is asserted where
                F19.5's is — at the loaded module and through the CLI — and `check-language.sh`
                compiles the `Guard` block §11 gained. `./bin/verify.sh` green **twice from a
                clean clone**
**Implements**  [ticket 18](../../wayfinder/issues/18-boundary-defence.md) §2's *"so the
                compiler checks it"*, decided 2026-08-13; the guard LANGUAGE.md §10 promised
                and §11 carried as **Owed** since F19, tracked by nothing until
                [ENG-357](https://linear.app/davewil/issue/ENG-357)
**Closes**      [ENG-357](https://linear.app/davewil/issue/ENG-357). Its one open question is
                raised, not answered: [ticket 74](../../wayfinder/issues/74-a-failed-guard-under-a-declared-channel.md)
                / [ENG-362](https://linear.app/davewil/issue/ENG-362)
**Decides**     nothing. The guard is the type, part by part, and every part's test was already
                decided: 18 §1's presence-and-value per field, 26 §1's *no exact-set test where
                nothing consumes the record* (ticket 72's withdrawal names this file), F37's
                comparisons for a refined `int`. That a refused value raises `case_clause` is
                the BEAM's own report for an arm-less `case`, the same choice the switch made
**Depends on**  F40, whose admissibility predicate is what makes the emitter total — every type
                it admits is a fixed guard sequence; F19, whose wrapper this sits opposite to and
                whose per-module variable counter it shares; F37, for the bounds

## What was there

Ticket 18 §2 lets a foreign declaration promise only what one BEAM guard decides in O(1) *"so
the compiler checks it"*, and says that under this rule the emitted `-spec` is a checked claim.
F40 built the refusal that narrows the promise. Nothing checked it. On `f68d0cb`:

```csharp
module Guard

using :erlang {
    int float(int x)
}

public int Widen(int x)

Widen(x) -> :erlang.float(x)
```

```
$ bsc Guard.bs Widen 3
3.0
```

A float from a function declared `int`, printed without complaint — ticket 06's outcome 3 at
every foreign declaration in the language, not only the map ones ENG-351 and ENG-354 were about.
The refusal was a restriction whose benefit never arrived.

## The program

The same one, after:

```
$ bsc Guard.bs Widen 3
crashed: case_clause 3.0
$ echo $?
1
```

## The rule as built

`bs_check:foreign_wrappers/2` now hands the emitter every foreign signature, keyed by the triple
`e_foreign_call` carries, with two facts it never decides: whether the declaration named the
channel (F19's `wraps/2`) and the resolved return type. `bs_emit:expr/2`'s `e_foreign_call`
clause reads it: a channelled call gets the `try` it always did; an unchannelled one becomes

```erlang
case erlang:float(X) of
    'bs@rv0' when erlang:is_integer('bs@rv0') -> 'bs@rv0'
end
```

and a value the guard refuses raises `{case_clause, Value}`. No failure arm is written, for the
reason the switch writes none: the BEAM's report for an unmatched `case` is the crash 18 §1 rule
C asks for, *"not always at the call site, but never silently"*, and inventing a reason term would
have been a spelling decision no ticket made.

**The guard is the type, read part by part**, one alternative per inhabited part and each
alternative one kind test plus what that part still owes:

| declared | emitted |
|---|---|
| `int` | `is_integer(V)` |
| `Octet` (`int where value >= 0 and value <= 255`) | `is_integer(V) andalso V >= 0 andalso V =< 255` |
| `binary` | `is_binary(V)` |
| `:up \| :down` | `V =:= up orelse V =:= down` |
| `atom` | `is_atom(V)` |
| `int \| :undefined` | `is_integer(V) orelse V =:= undefined` |
| `(:ok, int) \| (:error, atom)` | `is_tuple(V) andalso tuple_size(V) =:= 2 andalso element(1, V) =:= ok andalso is_integer(element(2, V))` `orelse` the other product |
| `{ Method: binary, Path: binary }` | `is_map(V) andalso is_binary(map_get('Method', V)) andalso is_binary(map_get('Path', V))` |
| `list<term>` | `V =:= [] orelse (is_list(V) andalso V =/= [])` |
| `map<term, term>` | `is_map(V)` |
| `term` | nothing — no `case` at all |

**The fixed field set emits ticket 26's boundary guard, never the pattern guard.** `is_map` plus
one `map_get` value test per declared field, and no `map_size`: 26 §1 emits the exact-set test
only where a codegen obligation consumes the record, and a wrapper returns the value. So a cowboy
request with a dozen keys beyond `Method` and `Path` passes, which is what ticket 72's withdrawal
recorded ENG-357 would inherit. A field declared `term` owes presence only, asked with
`is_map_key`; any narrower field's `map_get` raises on absence, which in a guard is `false`, so
presence and value are one test.

**Total over F40's admissible set and loud outside it.** A recursive type, a `list` or `map`
narrower than `term`, or a `string` cannot reach the emitter, because F40 refused the declaration.
Each raises in `type_test/3` rather than emitting a guard that would pass the wrong values —
the fault the memory *a new type kind crashes every fun that enumerates kinds* names, taken the
loud way round on purpose.

**A call in guard position is not guarded.** `guard/2` emits under an `in_guard` flag, and the
`e_foreign_call` clause emits the bare call under it: a `case` is not a guard expression, and F41
keeps `:erlang.byte_size(b) > 2` legal in a guard. Nothing escapes a guard unchecked — the
comparison consumes the value — so there is nothing for the return guard to do there (18 §1: a
guard only where the body's own operations would not object).

**The variable is numbered per module.** A `case` with one clause exports its pattern's variable,
so a second `case` binding the same name would match against the first's value rather than bind a
fresh one — F19 §3's hazard one construct over. The names are `bs@rvN` from the wrapper's own
counter, and two guarded calls in one clause plus one nested in another's argument run (F42.11).

## The channelled arm is not built, and that is a raised question

A foreign return declared `result<T, foreign_error>` still gets the `try` and no guard. ENG-357
named this as its one open question, and CLAUDE.md's rule is that a feature raises a ticket
rather than deciding: `foreign_error` is three exception classes, a wrong-typed value is not an
exception, and whether the guard's refusal crashes or arrives through the channel is which of two
nestings the emitter writes. Both nestings are one line. Ticket 74 asks it with
`result<binary, foreign_error>` over `file:read_file/1`, the program §11 measured on 2026-08-22.

No test pins the unguarded arm. A test asserting today's behaviour there would certify the
missing check as intended (the memory *a runtime crash test may certify a missing check*, read
in the other direction).

## Scenarios

| # | Scenario |
|---|---|
| F42.1 | ENG-357's program: `int float(int x)` handed `3` crashes with `{case_clause, 3.0}`; through the CLI, `crashed: case_clause 3.0` and exit 1 |
| F42.2 | `binary` refuses an atom |
| F42.3 | a finite atom union admits only its members — a third atom and an integer are refused |
| F42.4 | a refined `int` carries its bounds: 256 and -1 are integers and still refused |
| F42.5 | `int \| :undefined` is a disjunction of kind tests |
| F42.6 | a tuple union tests arity and every component: `(:ok, 1.5)` and `(:ok, 1, 2)` refused |
| F42.7 | a fixed field set admits extra keys and refuses a missing or wrongly typed field — no `map_size` |
| F42.8 | `list<term>` is one list test, nothing per element |
| F42.9 | `map<term, term>` is one map test, nothing per key |
| F42.10 | `term` passes everything and the emitted code has no `case` |
| F42.11 | two guarded calls in one clause, and one nested in another's argument, all run |
| F42.12 | a throw inside the call is still that throw: `examples/Foreign`'s `Size` dies with `badarg` as before |

## What the building revealed

**Three tests read "no wrapper" off the bare call.** F19.9 and two F23 tests asserted the
outermost node of an unchannelled call's body is `{call}`, which was the only positive shape that
said "no `try`" without asserting an absence. The outermost node is now the guard's `{'case'}`,
and the assertions say so; the fact they pin — that the `try` is not there — is unchanged.
`ffi_tests:a_foreign_call_is_a_remote_call_test` searched the top of the clause body for the
remote call and now walks the whole form, since what it asserts is the call and not where the
emitter put it.

**`list<term>` normalises to two spines**, `[]` and a one-element open prefix, so the guard for it
is `V =:= [] orelse (is_list(V) andalso V =/= [])` rather than a bare `is_list`. Correct and
redundant; the spine walk is general because the algebra's shape is, not because a declaration
can spell a longer prefix.

**The emitter already had a `bounds/3`.** F37's range guard owns the name; this file's is
`int_bounds/3`. The first build failed to compile on the clash, which is the cheapest possible
way to learn that the two guards share a vocabulary and not code.

## Out of scope

- **The channelled arm.** Ticket 74, above.
- **A named crash reason.** `{case_clause, Value}` names the value and the line and not the
  foreign function. A reason such as `{foreign_return, {Mod, Fun, Arity}, Value}` would be a
  spelling decision; if the crash reads badly in practice that is a ticket, not this file.
- **The key walk over `map<K, V>`** — [ENG-356](https://linear.app/davewil/issue/ENG-356), which
  this unblocks. A domain map narrower than `term` is refused at the declaration by F40 and the
  route through is `map<term, term>` then `ValidateAs<T>`, whose walk is that issue's.
- **Guards on exported parameters of kinds other than `int` and a record tag.** F24's "only `int`
  so far" is unchanged; the return guard emits every kind because F40 guarantees the set is
  decidable, and the parameter side has no such predicate yet.

## Done when

- `foreign_guard_tests` green, 13 tests; the four moved assertions green.
- `LANGUAGE.md` §11's *Owed* paragraph names only the channelled arm and ticket 74; §13's row
  reads shipped; the `Guard` block compiles under `check-language.sh`.
- `./bin/verify.sh` green twice from a clean clone.
