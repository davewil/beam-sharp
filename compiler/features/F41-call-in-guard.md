# F41 — a call in a guard is refused in B#'s voice, never in Erlang's

**Status**      **done 2026-09-11** — 13 tests in `guard_call_tests`; six existing tests moved
                off a call-in-guard as their "unreadable guard" (it was never a legal program);
                785 in the suite, up from 772. New gate `check-guard-calls.sh`, seen red on the
                tree before the build on all six leaks with both controls running; one
                `diagnoses:` block in `LANGUAGE.md` §2, and §5's `arg_not_accepted` example
                corrected (its own guard called a function — WRONG DIAG at `LANGUAGE.md:898`
                before the edit), and the audition's c09 and held-out h08 with it — the first
                clean pair went red at stage 10 on exactly those two. `./bin/verify.sh` green
                **twice from a clean clone**
**Implements**  nothing on the map. This is a compiler defect,
                [ENG-256](https://linear.app/davewil/issue/ENG-256), and the precedent is
                ENG-249 / F21's correction: found by a probe written for another ticket
**Closes**      [ENG-256](https://linear.app/davewil/issue/ENG-256). Its three owed items are
                discharged below. One leak the class count found is filed for its own decision:
                [ENG-359](https://linear.app/davewil/issue/ENG-359)
**Decides**     nothing new. That a guard cannot call a user function is inherited from the BEAM
                and [ticket 63](../../wayfinder/issues/63-negation-has-no-spelling.md) Q4 left it
                so, with no ticket. That a foreign call to a BEAM **guard BIF** stays legal is the
                same inheritance read the other way. The *boundary* — refuse in `bs_check` rather
                than translate Erlang's report on the way out — follows the three refusals already
                in `guard_diags/2` (F5 `_`, F7 `switch`, 12 §5 `raise`), each put there for this
                exact reason: "reaches the author as `illegal guard expression` from `erlc` against
                a file they did not write"
**Depends on**  F16, the diagnostic as a term; F17, `--api`; F35, the column

## The defect

Probe 63b (ticket 63) put `Check(u) when IsAdmin(u) == :yes` through `bsc`. The refusal was
right — Erlang admits only its guard BIFs in a guard — and the author was shown this:

```
compile: .../guardprobe.bs:21:15: call to local/imported function 'IsAdmin'/1 is illegal in guard
%   21| Check(u) when IsAdmin(u) == :yes -> :admin
```

Four faults in two lines (ENG-256): it is in no diagnostic term and has no tag, so `--diagnostics
term` and `--api` never see it; it spells the function as `'IsAdmin'/1` where B# writes
`IsAdmin(int)`; it leaks the Erlang Abstract Format target; and the `%   21|` gutter is Erlang's
excerpt format around B# source. The `compile:` prefix is `bsc.erl`'s relay of the Erlang
compiler's own report text — the relay is the last resort for forms the checker has not refused,
and a program reaching it is a checker defect by definition.

## Owed item 1 — the class, counted

`wayfinder/prototypes/63d_erlc_leak_sweep/` compiles one module per candidate and records whether
a `compile:` line reached stderr. On the tree before this feature (`30da2ee`):

| Probe | Form in the guard | Before F41 | After F41 |
|---|---|---|---|
| G01 | local call `IsAdmin(u)` | **leak** — `'IsAdmin'/1 is illegal in guard` | `call_in_guard` |
| A01 | the same, in a **switch-arm** guard | **leak** | `call_in_guard` |
| G02 | qualified call `Helper.IsAdmin(u)` | **leak** — `illegal guard expression` | `call_in_guard` |
| G04 | foreign call, not a guard BIF: `:string.length(s)` | **leak** — `illegal guard expression` | `foreign_call_in_guard` |
| G06 | pipe `u \|> IsAdmin()` | **leak** (a local call after lowering) | `call_in_guard` |
| G05 | valve `u \|?> Half()` | `switch_in_guard` — never a leak; the valve lowers to a switch before the checker | `switch_in_guard`, and **one** error: the call inside the refused switch is not a second mistake |
| G10 | `ValidateAs<int>(t)` | **leak** — names `bs@validate@1@r/1`, the emitter's own symbol | `call_in_guard` |
| G03 | foreign call to a guard BIF: `:erlang.byte_size(b)` | clean | clean, and runs |
| G07–G09 | projection, record update, record construction | clean (maps are guard-legal) | clean |
| G11–G14 | string literal, tuple/list, `/` and `%`, comparison | clean | clean |
| B03 | an uncalled `private` function | **warning leak** at line 0 | **still leaks** — ENG-359 |
| B01, B02, B04 | arm-bound name, unused binding, re-bound parameter | unreachable / refused in B# | unchanged |

The shipped `compiler/examples` corpus produces no `compile:` line before or after. The class is
author-reachable, not shipped.

## Owed item 2 — the boundary

`bs_check:guard_diags/2` refuses, with two tags. The walk that found `_`, `switch` and `raise` is
generalised to return nodes rather than positions (`subtrees_of/2`), so the call refusal is a
fourth caller of one walk and not a second copy of it. The call walk stops at a `switch` or a
`raise` as well as at a call, so a guard already refused for its switch is not refused again
for the call inside it — the valve is that shape, and reported two errors until the stop. It runs
on clause heads and on switch arms
because both already called `guard_diags/2` — the `half` stub in the gate is the version that
would not have.

| Term | Descriptor | Prose |
|---|---|---|
| `{call_in_guard, Callee}` | `tag => call_in_guard, callee => Callee` | *`Check` calls `IsAdmin` in a guard; a guard asks a question about the values a clause already matched, it cannot call a function. Move the call into the body and switch on its answer.* |
| `{foreign_call_in_guard, Callee}` | `tag => foreign_call_in_guard, callee => Callee` | *`Check` calls `:string.length` in a guard; only the BEAM's own guard functions may run in a guard, and `:string.length` is not one of them. …* |

`Callee` is the spelling the author wrote — `IsAdmin`, `Helper.IsAdmin`, `ValidateAs`,
`:string.length` — the same `callee` key and atom form `unknown_callee` and `private_function`
already use, never `'F'/N`. A foreign call to `erlang` is asked of `erl_internal:guard_bif/2`
rather than checked against a copied list, so the set is OTP's own for whichever OTP built `bsc`.

The repair line names the body and a switch because that is the shape the guard was reaching for:
`when IsAdmin(u) == :yes` is a branch on an answer, and a switch on `IsAdmin(u)` in the body is
that branch, typed and checked for exhaustiveness. Nothing promises a named-guard form; ticket 08's
`guard` modifier is decided and awaits a feature, and a diagnostic may not recommend what it cannot yet offer.

## Owed item 3 — the gate

`compiler/bin/check-guard-calls.sh`. Eight probes: the six leaks above, refused in B#'s voice
with the callee named, plus two controls that must compile **and run** with their value asserted
exactly — `:erlang.byte_size` in a guard (the plausible-but-wrong fix refuses every foreign call,
and this is the program it breaks) and the comparison guard 63b used. `--self-test` builds six
defects: `leak` (today's raw text), `silent`, `wrong` (a different B# diagnostic), `half` (clause
refused, arm still leaking), `bif_refused`, `cry_wolf`. Seen red live before the build: all six
probes carried the `compile:` relay.

## What the rule reached that its examples never listed

Six tests in four suites had used a user function call as their canonical "guard the checker
cannot read": `body_check_tests` (two), `generics_tests`, `switch_tests` (two), `types_tests`.
Every one held a program the BEAM would have refused after the checker passed it — the tests
never reached emission, so nothing noticed. The unreadable guard is now `n % 2 == 0`, which is
legal on the BEAM and credited nothing (probed: the residual stays `int`). The two tests whose
point was the *call* — `a_guard_calling_a_function_is_not_an_unbound_name` and ticket 08's own
example in `generics_tests` — now assert the refusal, which still proves what they were for.
`LANGUAGE.md` §5's `arg_not_accepted` example had the same guard and is corrected; the audition
packet is rebuilt from it. The audition's visible case c09 and held-out case h08 were the same example
again — `m when Big(m)` and `d when Hot(d)` — and the first clean pair went red at stage 10
because the oracle now publishes `arg_not_accepted call_in_guard` for both. Their guards are
comparisons now; their answer keys were already right.

## Scenarios

| # | Scenario |
|---|---|
| F41.1 | a local call in a clause guard is `call_in_guard`, callee named as written |
| F41.2 | the same call in a **switch-arm** guard is refused — a different walk |
| F41.3 | a foreign call to a function that is not a guard BIF is `foreign_call_in_guard` |
| F41.4 | a pipe in a guard is refused as the local call it lowers to |
| F41.5 | `ValidateAs<T>(x)` in a guard is refused, naming `ValidateAs` and never the mangled symbol |
| F41.6 | the refusal is the only error — no cascade |
| F41.7 | `:erlang.byte_size(b) > 2` in a guard compiles and **runs** |
| F41.8 | a comparison guard still compiles and runs |
| F41.9 | the CLI prints B#'s sentence and none of `compile:`, `'IsAdmin'/1`, `illegal in guard` |
| F41.10 | a qualified call to a sibling module is refused, naming `Helper.IsAdmin` |
| F41.11 | the foreign refusal names the BEAM's guard-function set |
| F41.12 | `--diagnostics term` carries `tag`, `callee`, `function`, `line`, `column` |
| F41.13 | a valve in a guard is one error, `switch_in_guard` — the call inside the refused switch is not a second |
