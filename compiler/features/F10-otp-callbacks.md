# F10 — OTP callbacks: the name they emit, and the contract being satisfied

**Status**      **done 2026-08-15**
**Implements**  [ticket 35](../../wayfinder/issues/35-behaviour-callback-names.md), resolved the
                same day, and [ticket 14](../../wayfinder/issues/14-concurrency-and-otp-model.md)
                §4's presence half — decides nothing
**Unblocks**    **`bin/spec-check.sh`**, red on `master` since CI was added, and the `behaviour`
                half of exemplars 25b and 25c
**Depends on**  F1, F3, F5

## Why this one now

Not the ordering rule — **a red gate**. `spec-check.sh` has failed on `master` since the day CI was
added, and the reason was a decision nobody had taken: `counter.bs` declared `behaviour GenServer`
and emitted `'Init'/1` and `'HandleCall'/3`, while OTP demands `init/1`, `handle_call/3` and
`handle_cast/2`. **The attribute was emitted for a contract the emitted module could never satisfy.**

The AoC report put it on the list too — *"OTP is declared, not checked, so ticket 00's showcase
still has no implementation strategy under it"*.

## What is being built

```csharp
module Counter

behaviour GenServer

(:ok, int) Init(int seed)
Init(seed) -> (:ok, seed)

Reply HandleCall(Request request, term from, int state)
HandleCall(:get, from, state)      -> (:reply, state, state)
HandleCall((:add, n), from, state) -> (:reply, state + n, state + n)

(:noreply, int) HandleCast(term msg, int state)
HandleCast(msg, state) -> (:noreply, state)
```

emits `-behaviour(gen_server)` and exports `init/1`, `handle_call/3`, `handle_cast/2`.

Two capabilities, and the second is what makes the first honest:

1. **A callback lowers to its OTP name**, through a compiler-known table.
2. **A behaviour declared without its mandatory callbacks is an error at the declaration.**

## Scenarios

**F10.1 — a callback is reachable under its OTP name.** `Counter:init(5)` → `{ok, 5}`,
`Counter:handle_call(get, self(), 5)` → `{reply, 5, 5}`. This is the name `gen_server` actually
calls, so without it the process could never start.

**F10.2 — and *not* under the beam-sharp one.** `'HandleCall'/3` is not in the export list. The name
**changes**; no wrapper is emitted. The precedent is one level up — `otp_name/1` renames `GenServer`
to `gen_server` and does not also emit `'GenServer'`.

**F10.3 — the `-spec` follows the name.** Otherwise Dialyzer reads a spec for a function that does
not exist, which is the whole failure this feature exists to end.

**F10.4 — a module declaring no behaviour is untouched.** `HandleCall/3` stays `'HandleCall'/3`.
This is the assertion that makes the table a table and not a naming rule.

**F10.5 — a callback of *another* behaviour is untouched.** `HandleCall/3` in a `Supervisor` module
stays `'HandleCall'/3` — it is a gen_server callback, and this module did not ask for that contract.

**F10.6 — arity is part of the key.** `HandleCall/2` is not the callback. Asserted on the table
directly rather than through source — see the build note; it cannot be reached from `.bs` today.

**F10.7 — a local call uses the lowered name.** A beam-sharp function calling `HandleCall(...)`
inside a `GenServer` module emits `handle_call(...)`. The fourth naming site, and the one that fails
by calling a function the module does not have.

**F10.8 — a missing mandatory callback is an error at the `behaviour` line**, exit 1:

```
counter.bs:11: error: behaviour GenServer is declared and not satisfied
  these callbacks are mandatory and this module does not define them:
    HandleCast/2
```

**F10.9 — the message names them in the author's spelling.** `HandleCast/2`, not `handle_cast/2`.
Ticket 04 makes the residual the missing case and 23 makes it the thing an agent is handed to write,
so it has to be something that lexes — and `handle_cast` does not.

**F10.10 — an optional callback is not demanded.** `handle_info/2` is optional for gen_server.

**F10.11 — `Supervisor` needs only `Init`.** A complete behaviour in four lines, and a second row of
the table exercised.

**F10.12 — an unknown behaviour is named**, listing the five the compiler knows.

## The decisions this implements, all ticket 35's

**Sub-question 1 answered itself on mechanism.** The alternative — the author spells the OTP name —
**cannot be written down**: `signature -> type_prim uident '(' params ')'` and `uident` is
`[A-Z]{ALNUM}*`, so a beam-sharp function name is PascalCase by construction and `handle_call` is
not a spellable function name. Not a preference; a grammar fact, and it is what made the ticket
small.

**The table is contract-scoped**, which is what answers 35's own *"a naming rule by another route"*
objection. A row fires only for a name **and arity** that is a callback of a behaviour **this module
declares**. F10.4, F10.5 and F10.6 are that sentence, asserted three ways.

**Both tables live in `bs_otp`.** A behaviour whose name the compiler knows and whose callbacks it
does not is exactly the state that produced ticket 35, so the pairing is the thing that would rot if
they were apart. One table, two readers — F5's rule for `resolve/2`.

## Out of scope

**Ticket 14 §4's type containment**, and it is declined on measurement rather than deferred by
default. Dialyzer already checks a callback's spec against OTP's own `-callback` at the boundary,
and both directions were probed before any of this was written: a **narrowed** callback spec is
**accepted** — so 14 §4's promise survives contact with the platform — and a **wrong** one is still
reported `Invalid type specification`, so the behaviour attribute does not soften the gate. Doing it
in the compiler as well buys a better diagnostic and no additional safety.

**`gen_statem`'s state functions.** OTP lists `{'StateName', 3}` as a callback; it is deliberately
absent from the table. Those names are the *user's*, so they are ordinary functions and must not
lower. A table of known names cannot hold a name nobody knows yet, and inventing one is ticket 32's
derivation rule coming through the one door left open.

**Arity overloading.** See below — it does not exist, and this feature does not add it.

**`uses` rather than `using`.** `LANGUAGE.md` §12 records the spelling as decided and the lexer has
`behaviour`; changing it is ticket 22's surface question, not this.

## What building it found

**Arity overloading does not exist, and F10.6 is how that surfaced.** The scenario was first written
as *"a `HandleCall/2` helper alongside the callback"* and it failed — because `bs_check:collect/1`
gathers a signature's clauses by **name alone**:

```erlang
[F#fn{clauses = [C || C = {clause, _, Name, _, _, _} <- Decls, Name =:= F#fn.name]} || F <- Sigs]
```

so two signatures sharing a name each collect the other's clauses. Pre-existing, unrelated to ticket
35, and not fixed here — but worth knowing, because the language reads as though it should work.
The arity key is still right: `FormatStatus` is a real gen_server callback at **both** `/1` and `/2`,
so the table needs arity to tell its own rows apart.

**The mandatory sets were read off the runtime, not from memory** —
`M:behaviour_info(callbacks) -- M:behaviour_info(optional_callbacks)` on OTP 28. Writing them by
hand would have been the third place in this session where a plausible-looking list was wrong.

**Four naming sites had to agree**: the export list, the `-spec`, the function definition and every
local call. They now go through one function, because the failure mode when they disagree is a
module that compiles and exports a name nothing defines.

**And a gate found a doc the same hour.** `check-language.sh` failed on `LANGUAGE.md:522` the moment
`counter.bs` was completed — §12 showed the same incomplete gen_server and claimed **shipped**. The
bidirectional gate catching a *must-compile* block that stopped compiling is the half that usually
goes unmentioned; F9 exercised the other half the day before.

## Done when

- All twelve scenarios assert. **208 tests**, up from 197.
- **`bin/spec-check.sh` passes**, including both negative controls — which is the point of the
  feature and the thing that had never been true.
- It is removed from CI's `NOT RUN HERE` block and runs on every push.
- `examples/Counter/counter.bs` and `LANGUAGE.md` §12 both show a complete gen_server.
