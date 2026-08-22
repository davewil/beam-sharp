# F22 — A record pattern names its type, and any pattern takes a trailing binder

**Status**      **done 2026-08-22** · [ENG-237](https://linear.app/davewil/issue/ENG-237) —
                twelve scenarios, 483 tests, eighteen gates. **25c's wall moved**: `consume.bs`
                compiles past the line it was stuck on and the exemplar's front wall is now
                `encode.bs` on binary construction, a different file entirely
**Implements**  [ticket 55](../../wayfinder/issues/55-destructure-and-bind.md), resolved
                2026-08-22 — the type prefix and the trailing binder, which the ticket requires to
                land **together**
**Unblocks**    exemplar **25c**'s front wall (`consume.bs:20`), the last of ticket 25's three
                walls that is a language gap rather than a decision still open
**Depends on**  F3 (records — `record_surface/4` and the single minting point `qualified/2`),
                F8 (`var` binds / `=` matches, which is why the binder cannot be `=`),
                F5 (the body check site that reads a pattern's bindings)

## Why this one now

Because the mechanism already ships and only the surface is missing. `p_alias` — Erlang's
`Var = Pattern` — is live in `bs_emit.erl` and every tag-dispatching clause emits one, via
`ensure_var/3`. Nothing a user can type reaches it.

And because the alternative costs a **compiler-minted** atom in source:

```csharp
Area({ Kind: :'Shapes.Circle' })
```

`Kind` is minted by `record_surface/4` and the qualified name by `qualified/2`. Asking an author to
write it is the one place the surface makes an erasure detail load-bearing.

## The five forms

Only the last compiles before this feature.

| Form | Means |
|---|---|
| `Frame { Type: :method } f` | a Frame whose `Type` is `:method`, whole value bound to `f` |
| `Frame { Type: :method }` | a Frame whose `Type` is `:method` |
| `Frame f` | any Frame, bound to `f` |
| `{ Type: :method } f` | any map with that field, bound to `f` |
| `{ Type: :method }` | **unchanged** — today's property pattern |

## Scenarios

Each is a command, an input and an exact expected result.

| id | input | command | expect |
|---|---|---|---|
| **F22.1** | a record pattern naming its type | `bsc frame.bs Dispatch` | dispatches, same as the `Kind` spelling |
| **F22.2** | `Frame { Type: :method } f`, body uses `f.Channel` | `bsc` + run | the binder is the **whole record**, not the field |
| **F22.3** | `Frame f` with no fields named | `bsc` + run | matches any Frame, binds it |
| **F22.4** | `{ Type: :method } f` — bare pattern, binder | `bsc` + run | still legal; binder binds the map |
| **F22.5** | `Nope { X: 1 }` — undeclared type | `bsc` | error: unknown type `Nope` |
| **F22.6** | `Frame { Nope: 1 }` — field the record has not got | `bsc` | error naming the field and the record |
| **F22.7** | `Frame { Type: :method }` beside `Frame { Type: :header }` over a two-member union | `bsc` | **exhaustive**, exactly as the `Kind` spelling is |
| **F22.8** | a type-prefixed clause that leaves a member uncovered | `bsc` | inexhaustive, and the residual names the missing member |
| **F22.9** | binder nested in a tuple — `(Frame { Type: :method } f, rest)` | `bsc` + run | 25c's actual shape |
| **F22.10** | `Frame { Type: :method } f` where the body never uses `f` | `bsc` | no `variable unused` warning from the emitted Erlang |

## The exhaustiveness obligation, which is the one that can go quietly wrong

`Frame { … }` must subtract **exactly** what `{ Kind: :'Mod.Frame', … }` subtracts today. Too little
and a covered union reports inexhaustive — loud, and someone fixes it. **Too much and a program the
compiler proves exhaustive crashes**, which is ticket 54's shape and is silent.

So F22.7 and F22.8 are the load-bearing scenarios, and the gate below asserts the two spellings
produce the **same** verdict rather than asserting either verdict directly. Comparing them is
stronger than pinning either: it cannot pass by both being wrong in the same direction, because the
`Kind` spelling is the one that already shipped and is exercised by the existing suite.

## What the compiler gains

- **Grammar** — four productions. Measured at **zero yecc conflicts** by
  [`55f`](../../wayfinder/prototypes/55f_yecc_conflicts.sh) before any of this was written, over a
  baseline that is itself zero.
- **AST** — two nodes. `{p_rec, Line, Name, Fields}` and `{p_bind, Line, Var, Pattern}`.
- **Checker** — `pattern_type/3` clauses for both, plus the traversals every pattern node owes
  (`pattern_vars/1`, `pattern_matched_vars/1`, `has_rel/1`, `bin_diags/2`). Two new diagnostics.
- **Emitter** — **no new `pattern/2` clause.** A pre-pass rewrites `p_rec` into the `p_map` the
  emitter already lowers and `p_bind` into the `p_alias` it already lowers. The pre-pass is where
  the tag is resolved, because that is where `Ctx` carries `env` — the same place `record_tag/2`
  already reads it for the boundary guard.

## Not in this feature

`Frame { }` — empty braces. `Frame f` says it better and the ticket left the empty form to here;
this feature does **not** add it, so it stays a syntax error and can be added without changing
anything decided.

Nested binders — `Frame { Payload: p } f`, binding a field *and* the whole — fall out of the
grammar for free and are **not** refused, but no scenario asserts them and no exemplar asks.

## What the build found that the decision did not say

**A SWITCH ARM IS NOT A CLAUSE HEAD, AND THE FEATURE WAS BRIEFLY DONE WITHOUT WORKING.**
`bs_emit:arm/2` does not travel through `clause/3`, so the desugar placed there never reached a
switch arm: a `p_rec` would have arrived at `pattern/2`, which has no clause for one, and crashed
rather than diagnosed. Every scenario F22.1–F22.10 passed at that point.

`consume.bs:20` — the line this whole feature exists to compile — **is a switch arm.** So the
feature would have shipped green, with a moved test count and an unmoved wall. F22.11 is that
scenario, and it was written from the exemplar rather than from the decision, because the decision
never mentions `switch`.

**An unused binder warned, and the test that should have caught it only checked the module built.**
`Which(Method { Channel: 7 } f) -> :seven` emitted Erlang that warned `variable 'F' is unused` —
harmless in isolation, and every clause in 25c's file has that shape. The first F22.10 asserted only
that the module compiled and ran, which it did, warnings and all. It is now asserted on the emitted
forms in **both** directions: an unused binder must underscore, and a used one must not, because a
fix that underscored unconditionally would emit Erlang referencing an unbound variable.

The fix was to stop building the variable in the `p_alias` clause and route it through `pattern/2`'s
own `p_var` clause, which already knew the rule. **The bug was a copy of logic, not a missing rule.**
