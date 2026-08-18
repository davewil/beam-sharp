# F19 — The compiler-emitted foreign `try` wrapper

**Status**      **done 2026-08-18**
**Implements**  [ticket 15](../../wayfinder/issues/15-error-model.md) §4 and §5, resolved — decides
                nothing; over [ticket 32](../../wayfinder/issues/32-ffi-surface.md)'s `using :mod`
                surface, and [ticket 12](../../wayfinder/issues/12-totality-vs-let-it-crash.md)'s
                asymmetry for the undeclared half
**Unblocks**    the first half of §11's standing **Owed** paragraph in `LANGUAGE.md` — a foreign
                call is no longer only a bare remote call. `foreign_error` becomes the first
                stratum-2 prelude entry that is built rather than decided
**Depends on**  F6 (parametric aliases — `result<T, E>` is one), F9.11 (the foreign return-type
                admissibility site this check sits beside), F11 (the callee environment that keys
                a foreign signature by `{Module, Function, Arity}`)

## Why this one now

Ticket 15 §4 is the only decided codegen obligation whose write site already exists and is one
function long. `bs_emit:expr({e_foreign_call, …})` has carried the comment *"The compiler-emitted
wrapper and boundary guard the design calls for are NOT here yet"* since F1; `LANGUAGE.md` §11 has
carried the matching **Owed** paragraph. This closes the first of the two.

It is also the obligation with the **narrowest** blast radius of the four. `ParseAtom<T>`,
`ValidateAs<T>` and the serialisation encoder all synthesise a structural traversal from a type.
This one synthesises the same four lines of Erlang at every site, whatever the type.

## Measured before this file was written, not assumed

Everything below is `bsc` at `c92df4d`, OTP 28.

**A `result`-typed foreign signature already compiles, and the throw already escapes.** This is the
defect, and it is silent — the author declared a failure channel and the program dies anyway:

```csharp illustrative
module P

using :erlang {
    result<int, atom> binary_to_integer(binary b)
}

public result<int, atom> Port(binary b)
Port(b) -> :erlang.binary_to_integer(b)
```

```
$ bsc --src-root . P Port '<<"12">>'      ->  12
$ bsc --src-root . P Port '<<"abc">>'     ->  crashed: error:badarg      (rc 1)
```

So this feature adds **no** parsing, **no** admissibility rule and **no** type machinery for the
declaration itself. Ticket 18 §2's `admissible_foreign_ret/5` already lets `result<T, E>` through,
because every member of it is decided by one BEAM guard in O(1).

**`foreign_error` does not resolve.** `error: foreign_error is not a builtin type`. It is
PRELUDE.md stratum 2, **decided** and unbuilt, and nothing can be declared over it until it exists.

**A repeated synthesised variable is a compile error, not a silent match.** Measured directly with
`erlc`, because the wrapper binds two names per call site:

```erlang
A = try erlang:binary_to_integer(X) catch C:R -> {error, {C, R}} end,
B = try erlang:binary_to_integer(X) catch C:R -> {error, {C, R}} end.
%% vt.erl:5:47: variable 'C' unsafe in 'try' (line 4)
```

Two wrapped calls in one clause, or one nested in another, need **distinct** names. This is F14's
recorded valve hazard at a second site, and it decides §3 below.

## What is being built

**Declaring a foreign function's return type as `result<T, foreign_error>` makes the compiler emit
the wrapper.** The author writes only the declaration:

```csharp illustrative
using :erlang {
    result<int, foreign_error> binary_to_integer(binary b)
}
```

and the call site emits

```erlang
try erlang:binary_to_integer(B)
catch 'bs@fc0':'bs@fr0' -> {error, {'bs@fc0', 'bs@fr0'}}
end
```

Nothing about this is user-writable. **There is no `try` in the surface**, and there is no way to
ask for the wrapper except by declaring the type — the same codegen-obligation pattern as
`ParseAtom<T>` (ticket 10 §4) and `ValidateAs<T>` (ticket 11): the author declares the type, the
compiler generates the check.

**`foreign_error` ships as a prelude type**, exactly as ticket 15 §5 spells it:

```
type foreign_error = (:error, term) | (:throw, term) | (:exit, term);
```

so the class survives the catch and is then an ordinary clause head:

```csharp illustrative
Report((:error, :badarg))     -> "not a number"
Report((:exit, (:noproc, _))) -> "server is down"
```

**The wrapper catches all three classes**, per 15 §5 and
[`15d`](../../wayfinder/prototypes/15d_which_classes_a_wrapper_catches.erl): a locally raised
`exit/1` is catchable and an exit *signal* is not, so no supervision decision can be swallowed by
one. An error-only wrapper would miss `exit({noproc, …})`, which is the commonest foreign failure
on the platform.

**A foreign signature that does not declare the channel gets no wrapper**, and the caller dies.
That asymmetry is ticket 12's decision, not an omission: fail through the channel your signature
declares, crash where it declares none.

## The four things this feature decides, all mechanism

### 1. The trigger is the TYPE, not the spelling `result<…>`

Ticket 09 §4 fixed that a name never enters the algebra — `option<int>` and a hand-written
`int | :nothing` are the *same type*, and F6.3 is the test that pins it. So the obligation cannot
key on the token `result`. It keys on the resolved return type carrying a **2-tuple member whose
first component is the literal atom `:error`**, which is what `result<T, E>` *is*.

The consequence is that the hand-written union gets the wrapper too, and that is the point:

```
result<int, foreign_error> f(binary)      // wrapped
int | (:error, foreign_error) g(binary)   // wrapped — the same type
```

### 2. `E` is fixed at `foreign_error`, and anything else is refused at the declaration

15 §5 states the cost plainly: *"`E` is fixed for foreign calls rather than freely chosen, so an
author writes `result<int, foreign_error>` and adds a mapping step if they want a domain reason."*
A declared `(:error, E)` member whose payload is not `foreign_error` is therefore an **error at the
declaration**, beside `opaque_ret_at_boundary` and for the same reason ticket 09 §4 and 15 §1 give:
the diagnostic lands where the fix is, and it is an error rather than a warning.

**This refuses a shape Erlang writes constantly, and that is a gap rather than a decision** — see
Out of scope. Refusing loudly is the reversible direction; emitting no wrapper silently would ship
a program that dies where its author declared a value.

### 3. The synthesised names are numbered per module, in the emitter

The measurement above makes uniqueness a correctness requirement rather than hygiene. F14 solved
the same problem in `bs_lower` with a numbering walk, and `bs_lower` is not this feature's ground —
the wrapper is invisible to the checker, so there is nothing for a lowering pass to mark.

So the counter lives in `bs_emit`, reset once per `forms/1` call, and the names are `bs@fcN` and
`bs@frN`. `bs@` keeps them out of the source's variable grammar, which is lowercase alphanumerics —
the convention `ensure_var/3`, the relational lowering and the valve already share.

Numbered per **module** rather than per clause: uniqueness within a clause is what Erlang requires,
and a monotonic counter over one deterministic emission walk delivers it with no scope tracking. The
reset is what keeps the emitted forms identical across runs.

### 4. The wrapper is invisible to `bs_check`

The checker sees `result<int, foreign_error>` and nothing else — no marker node, no second pass,
and no rule about generated code. This is the opposite of F14's valve, which had to stay marked all
the way to emission so the checker would not advise the author about arms it did not write. Here
there is nothing to advise about: the type the author declared is the type the call site has, before
and after the wrapper, because the wrapper is *how* that type becomes true.

## Scenarios

| id | input | command | expected | exit |
|---|---|---|---|---|
| F19.1 | `result<int, foreign_error> binary_to_integer(binary)` | `bsc … Port '<<"12">>'` | `12` — the happy path is unchanged | 0 |
| F19.2 | the same, on a value that throws | `bsc … Port '<<"abc">>'` | `(:error, (:error, :badarg))` — the error arrives as a **value** | 0 |
| F19.3 | `result<term, foreign_error> throw(term)` | `bsc … Thrown` | `(:error, (:throw, :boom))` — the `throw` class | 0 |
| F19.4 | `result<term, foreign_error> exit(term)` | `bsc … Exited` | `(:error, (:exit, :boom))` — the `exit` class, locally raised | 0 |
| F19.5 | `int binary_to_integer(binary)` — **no** declared channel | run it on `<<"abc">>` | the caller **dies**, `error:badarg`. Ticket 12's asymmetry | 1 |
| F19.6 | `foreign_error` in a clause head, all three members | `bsc …` | each class dispatches; exhaustive with no catch-all | 0 |
| F19.7 | `result<int, atom>` on a foreign signature | `bsc` it | refused **at the declaration**: `E` is fixed at `foreign_error` | 1 |
| F19.8 | `try` written in the surface | `bsc` it | a syntax error — there is no `try` | 1 |
| F19.9 | a wrapped call and an unwrapped one in one module | read the abstract code | a `try` form for the first and none for the second | 0 |
| F19.10 | two wrapped calls in one clause, and one nested in another | `bsc` it | compiles and runs — the names are distinct | 0 |
| F19.11 | `examples/Interop` gains the declaration; a probe row names it | `rebar3 eunit`, `bin/spec-check.sh` | green; the emitted `-spec` survives Dialyzer over a `try` | 0 |

## Out of scope

- **A foreign function that returns `{ok, V} | {error, Reason}` as ordinary values.** `file:read_file`
  is the canonical case and §2 above makes it **undeclarable**: its `(:error, atom)` member is not
  `foreign_error`, and it is not a throw either. Ticket 15 §5 fixed `E` for foreign calls without
  considering the shape, and §4's *"adds a mapping step"* does not reach it — a mapping step needs a
  declared type to map *from*. **This is a ticket, not a feature**, and F19 refuses the case loudly
  rather than inventing a resolution for it.
- **The boundary guard.** §11's **Owed** paragraph has two halves and this is the other one — an
  emitted check that a foreign value inhabits its declared type. That is ticket 18's, over all eight
  channels, and it is `ValidateAs<T>`'s traversal rather than four lines of `try`.
- **Remote failure.** `monitor` + `receive` already handles a callee crash, with a *better* reason
  than `try` gets ([`15c`](../../wayfinder/prototypes/15c_surviving_a_callee_crash.erl), case 3 vs
  case 2). Nothing here is for a crash in another process, and 15d cases 5–7 measured that an exit
  **signal** is not catchable at all.
- **A general `try`/`catch` in the surface.** Refused by 15 §4 — a general escape hatch (ticket 21)
  that invites exceptions-as-control-flow. Chosen partly for reversibility: adding one later is
  purely additive.
- **`raise`.** Ticket 12 §5 decided the spelling and it is still unbuilt. It is the *producing* half
  of the error model and this is the *recognising* half.
- **A mapping from `foreign_error` to a domain reason.** 15 §5 states the cost — the author writes
  the mapping function themselves — and an ordinary clause head is already enough to write it.
- **The per-call-site cost number.** The map's fog records the wrapper as the fourth codegen
  obligation and the first whose cost is per *call site*, stacking with `ValidateAs<T>`. It also
  owes confirmation that the emitted `try` **survives the abstract-format path across the pinned OTP
  range**. F19 confirms it on the OTP this repo builds with, by compiling through that path and
  running the result; the *range* is still owed, and a matrix is not this feature's job.

## What the building revealed

**THE PRELUDE COULD NOT HOLD A GROUND ENTRY, AND THE REPAIR NEEDED TWO CLAUSES RATHER THAN ONE.**
`prelude/0` has carried a comment since F6 saying its entries are *"spelled in the language's own
alias mechanism rather than as a special case in `resolve/2`"*, and that was true of the two
parametric ones and impossible for anything else: every lowercase name fell straight through
`resolve({t_builtin, B}, …)` to `builtin/1`, so `foreign_error` arrived there as `unknown_builtin`.

The obvious fix — return the entry when the environment already holds a reduced type — **works in a
signature and fails inside a user's own `type` alias**, because `type_env/1` resolves its entries
with `maps:map` over the *surface* map: during that pass a prelude entry is still a `{t_union, …}`
tuple and only afterwards a map. So a `foreign_error` written in a signature resolved and the same
name written in `type Parsed = int | (:error, foreign_error)` did not, which is one of the two
places it is most likely to appear.

**It was found by a test rather than by reading**, and only because the test existed to prove §1's
claim that the *type* triggers the wrapper — the union had to be hand-written to make that point,
and hand-writing it needs an alias, because `foreign_sig` takes a `type_prim` and a bare union is
not one. A test aimed at one rule caught a defect in another.

**HALF THE FOG ITEM IS CONFIRMED, BY THE ORDINARY BUILD PATH.** The map's fog asks whether the
emitted `try` *"survives the abstract-format path unchanged"*. It does, and confirming it cost
nothing: `bsc` has no in-memory route to a `.beam` at all — every module is serialised to `.abstr`
with `~p` and rebuilt by `erlc +from_abstr`, which is ticket 13's contract. So every passing test
here is that round trip. **OTP 28 / erts 16.4.** The *range* across the pinned OTP versions is still
owed and a matrix is not this feature's job.

**AND THE NESTED CASE SUCCEEDS WHERE IT LOOKS LIKE IT SHOULD FAIL.** A wrapped call inside another
wrapped call type-checks only when the outer parameter accepts the inner's *whole* union — so
`:erlang.term_to_binary(:erlang.binary_to_integer(b))` compiles, because `term_to_binary` was
declared over `term`, and the outer call happily serialises `(:error, (:error, :badarg))`. Feeding a
`result` to something declared over `int` is a type error, reported against the argument position,
which is the checker doing its job rather than a limit of the wrapper. Worth writing down because
the first shape looks like a hole and the second looks like a bug, and neither is.

## Done when

- A compiled program calling a wrapped foreign function returns the error as a **value** on the
  throwing path and the ordinary value on the happy path — seen running, not only asserted. ✓
- All three exception classes arrive tagged. ✓
- A foreign signature without the declared channel still lets the caller die. ✓
- Every scenario above is a test, and the twelve CI gates are green. ✓ — 348 tests, up from 334.

**One thing is owed and is not a scenario.** F19.7's refusal is raised as
`{foreign_error_channel, Line, Mod, Fun, Payload}` and `bs_diag` has no `descriptor/2` clause for
it, so what an author sees is the escript stack trace F16 exists to abolish rather than the sentence
`opaque_ret_at_boundary` gets. The term is right, the tests assert on it, and only the prose is
missing — `bs_diag.erl` was outside this feature's write scope while a sibling feature held it.
