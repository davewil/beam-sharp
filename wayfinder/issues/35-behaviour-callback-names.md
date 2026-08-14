# 35 — What name does a behaviour callback emit?

Type: grilling
Status: open

Raised 2026-08-14 while wiring up CI. `bin/spec-check.sh` fails on `master`, and the cause is a
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

**This blocks a gate.** `bin/spec-check.sh` cannot pass until it is answered, so it is excluded
from CI with a pointer here — see `.github/workflows/ci.yml`. That exclusion is the cost of
leaving this open, and it is the only one.

Blocked by nothing. **Small**, and sub-question 3 may be resolvable on its own.

**Linear**: ENG-202. The `NN → ENG-(166+NN)` mapping is offset by one from ticket 33 — see the
map's Notes.
