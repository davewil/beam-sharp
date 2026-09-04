# 35 — What name does a behaviour callback emit?

Type: grilling
Status: resolved 2026-08-15

Raised 2026-08-14 while wiring up CI. `compiler/bin/spec-check.sh` fails on `master`, and the cause is a
decision nobody has taken rather than a defect in the script.

## Question

`examples/counter.bs` writes `behaviour GenServer` and defines `Init/1` and `HandleCall/3`. The
compiler emits `-behaviour(gen_server)` and functions named `'Init'/1` and `'HandleCall'/3`. OTP's
`gen_server` demands `init/1`, `handle_call/3` and `handle_cast/2`, so `erlc` reports three
undefined callbacks and Dialyzer agrees.

**The behaviour attribute is emitted for a contract the emitted module can never satisfy.**

So: **what name does a callback lower to?**

## Why it is not obvious

[Ticket 32](32-ffi-surface.md) settled that **there is no snake_case⇄PascalCase rule anywhere in
the language**, and settled it on evidence — [`32b`](../prototypes/32b_name_census.md) measured
that a mapping reaches 1,920 of 1,924 stdlib+kernel names and cannot spell `'PKCS-1'`,
`'OTP-PKIX'` or a quarter of Elixir's function names. So the obvious answer, *derive the OTP name
from the B# one*, is closed.

But 32 also left the door the answer probably goes through: the behaviour name itself already
lowers through **a fixed, compiler-known table of five** (`'GenServer' → gen_server`), explicitly
*"not a derivation rule… these are names the compiler knows, the way it knows `ValidateAs`"*. A
callback table is the same construct one level down, and [ticket 14](14-concurrency-and-otp-model.md)
already makes the compiler know each behaviour's contract as a type — so it knows the callback set
and could know the names with it.

## The sub-questions

**1. A compiler-known table, or something the user writes?** A table keeps the surface clean and
scales badly: five behaviours × their callbacks, and nothing for a *user-declared* contract, which
14 left as purely additive and [ticket 21](21-escape-hatch-precedents.md) named Roc's `requires`
for.

**2. Does the exported name change, or is a wrapper emitted?** If `HandleCall` lowers *as*
`handle_call`, an Erlang caller sees the OTP name and a beam-sharp caller writes `HandleCall` — one
function, two spellings, which is a naming rule by another route. If a wrapper is emitted instead,
there are two functions and [ticket 32](32-ffi-surface.md) already measured the wrapper question
once (~60 bytes, flat).

**3. Should the attribute be emitted at all when the callbacks are absent?** Today it is, which is
what turns a missing callback into a warning against a file the author did not write. Refusing to
emit an unsatisfiable attribute is the smaller fix and might be the right one *regardless* of how 1
and 2 land.

## What is already decided — do not re-raise

| Decided | By |
|---|---|
| No snake_case⇄PascalCase rule anywhere in the language | [32](32-ffi-surface.md) |
| The **behaviour name** lowers through a fixed compiler-known table of five | [32](32-ffi-surface.md), and it is in `bs_emit:otp_name/1` |
| `behaviour GenServer` names a contract **the compiler knows as a type**, and the user's narrower signature is checked by containment | [14](14-concurrency-and-otp-model.md) §4 |
| A user-declared contract is purely additive, and Roc's `requires` is the stealable mechanism | [14](14-concurrency-and-otp-model.md), [21](21-escape-hatch-precedents.md) |

## Notes

**This blocks a gate.** `compiler/bin/spec-check.sh` cannot pass until it is answered, so it is excluded
from CI with a pointer here — see `.github/workflows/ci.yml`. That exclusion is the cost of
leaving this open, and it is the only one.

Blocked by nothing. **Small**, and sub-question 3 may be resolvable on its own.

**Linear**: ENG-202. The `NN → ENG-(166+NN)` mapping is offset by one from ticket 33 — see the
map's Notes.

---

## Answer — resolved 2026-08-15

**A callback's emitted name comes from a fixed table in `bs_otp`, and a module that declares a
behaviour without defining its mandatory callbacks is refused at the declaration.**

**Sub-question 1 answers itself on mechanism rather than on preference — the alternative cannot
be written down.** It offered "something the user writes", meaning the author spells the OTP name
themselves. They cannot: `uident` is `[A-Z]{ALNUM}*` in the lexer, so **a beam-sharp function
name is PascalCase by construction** and `handle_call` is not a spellable function name. It never
will be without changing the rule that lets the grammar tell a type from a function with no
symbol table. That leaves the table ticket 32 already pointed at — names the compiler knows, the
way it knows `ValidateAs` — one level down.

**Both tables live in `bs_otp`**, which is a real move rather than tidiness: a behaviour whose
name the compiler knows and whose callbacks it does not is exactly the state that produced this
ticket. `bs_check` (the presence check) and `bs_emit` (the lowering) read the one table, the rule
F5 applied when it exported `resolve/2` instead of letting the emitter keep a copy.

**The name changes, with no wrapper**, and the Question's own worry — that renaming is "one
function, two spellings, a naming rule by another route" — is answered by scoping rather than
waved away: a row fires only for a name *and arity* that is a callback of a behaviour the module
**declares**.

**A contract that cannot be satisfied is refused, not emitted and not silently omitted.** The
error names the missing callbacks in the spelling the author must write.

**`gen_statem`'s `{'StateName', 3}` is absent from the table on purpose.** It is OTP's
placeholder for state functions in `state_functions` mode, whose names are the *user's*, so they
are ordinary beam-sharp functions and must not lower. A table of known names cannot hold a name
nobody knows yet, and inventing one would be ticket 32's derivation rule arriving through the one
door left open.

**Ticket 14 §4's type containment is not owed here, and that was measured rather than deferred.**
A narrowed callback spec is accepted by Dialyzer and `erlc`, so 14 §4's promise survives contact
with the platform — contravariance does not bite, because Dialyzer's behaviour check is
success-typing rather than strict subtyping. A wrong spec is still reported `Invalid type
specification`, so the attribute does not make Dialyzer more permissive. Doing it in the compiler
as well would buy a better diagnostic and no additional safety, and it is named in F10's
out-of-scope rather than left implied.

**A compiler-known callback table, contract-scoped and keyed by `{behaviour, name, arity}`. The
name changes; no wrapper. A behaviour declared without its mandatory callbacks is an error at the
declaration.** Built the same day as F10; the gate it blocked is green.

## 1. A table, and sub-question 1 answers itself on mechanism

Not a preference — **the alternative cannot be written down.** Sub-question 1 offered "something
the user writes", i.e. the author spells the OTP name themselves. They cannot: the grammar's
function productions are

```
signature -> type_prim uident '(' params ')'
clause    -> uident '(' patterns ')' guard '->' body
```

and `uident` is `[A-Z]{ALNUM}*` in the lexer. **A beam-sharp function name is PascalCase by
construction**, so `handle_call` is not a spellable function name and never will be without
changing the rule that lets the grammar tell a type from a function without a symbol table.

That leaves the table, which is what ticket 32 already pointed at: the behaviour *name* lowers
through a fixed table of five, "not a derivation rule… names the compiler knows, the way it knows
`ValidateAs`". The callback table is that construct one level down, exactly as the Question said.

**Both tables now live in `bs_otp`**, and that is a real move rather than tidiness. A behaviour
whose name the compiler knows and whose callbacks it does not is precisely the state that produced
this ticket, so the pairing is the thing that would rot if they were apart. Both `bs_check` (the
presence check) and `bs_emit` (the lowering) read from the one table — the rule F5 applied when it
exported `resolve/2` rather than letting the emitter keep a copy.

## 2. The name changes. No wrapper — and the objection is answered by scoping, not waved away

The Question's own worry was that renaming is *"one function, two spellings, which is a naming rule
by another route"*. It is not, and the reason is that **a row fires only for a name AND arity that
is a callback of a behaviour the module DECLARES**:

- `HandleCall/3` in a module with no `behaviour` line stays `'HandleCall'/3`.
- `HandleCall/3` in a module declaring `Supervisor` stays `'HandleCall'/3` — it is a gen_server
  callback, not a supervisor one.
- `HandleCall/2` anywhere stays `'HandleCall'/2`.

A rule is a derivation applied to every name. This is finite, hand-written, and **contract-scoped**:
it says nothing about any name that is not in a contract the author asked for. All three cases above
are asserted in `otp_tests`.

**Why rename rather than wrapper**: the shipped precedent one level up. `otp_name/1` renames
`GenServer` to `gen_server` and does not also emit `'GenServer'`. Doing the opposite one level down
would be the inconsistency. The wrapper's measured ~60 bytes was never the deciding cost.

**The arity key earns itself twice.** `FormatStatus` is a genuine gen_server callback at *both* `/1`
and `/2`, so the table needs arity to tell its own rows apart — and it is what stops a future
same-named helper being captured silently.

## 3. The attribute is not emitted for a contract that cannot be satisfied — it is refused

Sub-question 3 asked whether to emit the attribute when callbacks are absent. **Neither emit nor
silently omit: error at the declaration**, naming the missing callbacks in the spelling the author
must write.

```
examples/counter.bs:11: error: behaviour GenServer is declared and not satisfied
  these callbacks are mandatory and this module does not define them:
    HandleCast/2
```

Silently dropping the attribute would leave a program whose `behaviour GenServer` line means
nothing, which is the compiles-and-means-something-else shape F7 was bitten by. Erroring matches
three shipped precedents: `kind_field_is_minted` errors at a declaration, rebinding errors because
a name means one thing in a clause, and a cyclic alias is refused by name.

The mandatory sets were **read off the runtime**, not written from memory —
`M:behaviour_info(callbacks) -- M:behaviour_info(optional_callbacks)` on OTP 28:

| behaviour | mandatory |
|---|---|
| `gen_server` | `init/1`, `handle_call/3`, `handle_cast/2` |
| `supervisor` | `init/1` |
| `application` | `start/2`, `stop/1` |
| `gen_statem` | `init/1`, `callback_mode/0` |
| `gen_event` | `init/1`, `handle_event/2`, `handle_call/2` |

## 4. What is deliberately NOT in the table, and it is the interesting row

`gen_statem` lists `{'StateName', 3}` among its callbacks. **It is absent here on purpose.** That
entry is OTP's placeholder for state functions in `state_functions` mode, whose names are the
*user's* — so they are ordinary beam-sharp functions and must not lower. A table of known names
cannot contain a name nobody knows yet, and inventing one would be ticket 32's derivation rule
arriving through the one door left open.

## 5. Ticket 14 §4's type containment is not owed here, and that is measured rather than deferred

14 §4 says a behaviour names a contract the compiler knows **as a type**, with the user's narrower
signature checked by containment. This ticket ships the **presence** half only — and the type half
turns out to be largely free at the boundary, which was checked before the code was written rather
than assumed:

- A **narrowed** callback spec — `handle_call('get' | {'add', integer()}, any(), integer())` against
  OTP's `handle_call(term(), {pid(), term()}, term())` — is **accepted** by Dialyzer and by `erlc`.
  So 14 §4's promise survives contact with the platform; contravariance does not bite in practice,
  because Dialyzer's behaviour check is success-typing rather than strict subtyping.
- A **wrong** one is still reported `Invalid type specification`, so the behaviour attribute does
  **not** make Dialyzer more permissive about specs — which matters, because it means the gate this
  ticket unblocks is as strong with a behaviour module in it as it was without.

Doing it in the compiler as well would buy a better diagnostic and no additional safety. That is a
feature nobody has asked for yet, and it is named in F10's out-of-scope rather than left implied.

## What this cost the map

Nothing was re-raised. The four rows in *"already decided"* above all stand, and this answer is
built on two of them rather than around them.

## Decisions entry

<!-- The body of this ticket's entry in wayfinder/decisions.md, which is GENERATED
     from blocks like this one. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- [What name does a behaviour callback emit?](issues/35-behaviour-callback-names.md) — **a fixed
  table in `bs_otp`, and a module declaring a behaviour it does not satisfy is refused at the
  declaration.** Sub-question 1 answers itself on *mechanism* rather than preference: `uident` is
  `[A-Z]{ALNUM}*` in the lexer, so **a beam-sharp function name is PascalCase by construction** and
  `handle_call` is not a spellable name — the alternative could not be written down. That leaves the
  table ticket 32 already pointed at, one level down. **Both tables live in `bs_otp`** and both
  `bs_check` and `bs_emit` read the one copy, because a behaviour whose name the compiler knows and
  whose callbacks it does not is the state that produced this ticket. The rename is scoped to a name
  *and arity* that is a callback of a **declared** behaviour, which is what stops it being a naming
  rule by another route. `gen_statem`'s `{'StateName', 3}` is absent on purpose — those names are the
  user's. **Ticket 14 §4's type containment is not owed here, measured rather than deferred**:
  Dialyzer accepts a narrowed callback spec and still rejects a wrong one, so doing it in the
  compiler buys a diagnostic and no safety. Resolved 2026-08-15.
```
