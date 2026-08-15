# 40 — What is a module, what atom does it emit, and what does it export?

Type: grilling
Status: **claimed** 2026-08-15 — §1 answered, §2 and §3 are the open questions

Raised 2026-08-15 from the fog patch *"Module and namespace system, and function identity"*,
which four other patches wait on, and which
[`examples/exemplars/README.md`](../../compiler/examples/exemplars/README.md) names as
*"four of the seven [dialect gaps] … the same fog patch wearing different clothes"*.

Its sibling is [ticket 41](41-imports-and-cross-module-scope.md), raised together because the two
interlock: §2 here decides what a name identifies, and 41 §1 decides how another module says it.

## The failure is already in the repo

`aoc/2019/day01/day01.bs` and `aoc/2025/day01/day01.bs` both open with `module Day01`. Built to a
shared output directory the second silently overwrites the first — measured:

```
2019 -> a9a7dbd0e2bd8b1fc1f650e5a26743b3   Day01.beam
2025 -> ef3043e9b3b41499230689da6571ee3d   Day01.beam
```

Different bytes, same name, no diagnostic. Nothing in the language can tell the two apart, because
a module name has exactly one segment: `module_decl -> 'module' uident`.

---

## §1. The emitted atom — ANSWERED, and forced rather than chosen

**A module's atom is its full dotted path: `module Shop.Orders` emits `'Shop.Orders'`.**

This is not a convention pick. Ticket 26 §1 makes a record's discriminating tag mint from the
*qualified* name, and the single minting point is already written:

```erlang
%% THE SINGLE MINTING POINT. …the tag mints from the QUALIFIED name
qualified(Mod, Name) ->
    list_to_atom(atom_to_list(Mod) ++ "." ++ atom_to_list(Name)).
```

That delivers aggregate identity **only if `Mod` is itself unique across the codebase**. If a
nested module lowered to its leaf (`Orders`), `Shop.Orders.Order` and `Billing.Invoices.Order`
would both mint `'Orders.Order'` and two bounded contexts would silently unify — the exact failure
the minting exists to prevent, one level up and invisible. Carrying the full path is therefore a
**correctness requirement of ticket 26**, not a naming preference.

Three further constraints are satisfied rather than traded against: ticket 13's measured
`erlc` module-atom/filename enforcement (the emitted file is `Shop.Orders.abstr` →
`Shop.Orders.beam`), ticket 23 §10's requirement that the listing be legible to a reader with
nothing but `ls`, and ticket 10 §3's module-in-value-position atom singleton.

### Measured, not inferred

`prototypes/13a_target_measurements.md:96–105` already measured this, including the rejection
message (*"Module name 'Shop.Orders.Order' does not match file name 'agg'"*) and a three-segment
module in emitted Core. Re-confirmed here on OTP 28 with a hand-written Abstract Format file:

```erlang
{attribute,1,module,'Shop.Orders'}.
{attribute,1,export,[{'Two',0}]}.
{function,3,'Two',0,[{clause,3,[],[],[{integer,3,2}]}]}.
```

```
$ erlc +from_abstr +debug_info -o . "Shop.Orders.abstr"    # exit 0
→ Shop.Orders.beam
call=2  mod='Shop.Orders'
```

### The dot, and no prefix — indicated, with one correction on record

The separator and the absence of an `Elixir.`-style prefix are **strongly indicated, not forced**,
and the distinction is worth keeping because the first reason given for it was wrong.

The wrong reason: *"a PascalCase atom already sits outside Erlang's snake_case namespace."*
`prototypes/32b_name_census.md:30–35` had already measured that false — of 1,315 loadable Erlang
modules, **265 are not plain lowercase** (`'PKCS-1'`, `'ELDAPv3'`,
`'CryptographicMessageSyntax-2009'`). Erlang's module namespace has plenty of capitals.

The surviving reason is narrower: **none of those 265 contains a dot.** The separator does the
work, not the casing. Elixir's own modules cannot collide either — they are all `'Elixir.*'`
prefixed, measured live at `research/06-interop-surface.md:266–275`.

Gleam spells its nested separator `@` (`gleam@otp@actor`) because Gleam emits Erlang *source*,
where a dotted atom needs quoting; B# emits Abstract Format directly, so that cost never arrives
and what you write is what `ls` shows. **Provenance caveat**: Gleam's `@` mangling is doc/src in
this repo and never reproduced locally — the local Gleam 1.18.1 measurement only exercised a flat
`-module(ffi32)`.

**Still unmeasured, and stated as an accepted risk rather than a zero**: nothing here measures an
actual collision between a B# module atom and a loaded Erlang or Elixir one, nor a code-server
load-order conflict.

### Compiler delta for §1

```
bs_parser.yrl:121   module_decl -> 'module' uident
                  → module_decl -> 'module' modpath
                    modpath -> uident | uident '.' modpath   (join with ".")

bs_check:qualified/2   NO CHANGE — already Mod ++ "." ++ Name
bsc.erl emit path      NO CHANGE — atom_to_list(Mod) ++ ".abstr" already yields Shop.Orders.abstr
```

Both are already correct because they were written against the module *atom*, never against a
single segment. §1 costs one grammar rule.

---

## §2. THE QUESTION — may a name be overloaded on arity within a module?

The fog patch's title says *"function identity — BEAM identifies functions by name **and arity**,
which multi-clause heads and optional parameters both disturb."* **Measured, neither does:**

- **Multi-clause heads collapse cleanly.** F1 shipped it; `arity(F)` yields one arity per
  function, and the export list, `-spec`, definition and every local call are funnelled through
  one `name/2` (`bs_emit.erl:69–74`) so they cannot drift.
- **Optional parameters do not exist.** `param -> type_prim lident | type_prim` — named or
  anonymous, never defaulted. The `?` marker is a *record field* form only.

So the patch names two hazards that are not live. **The live one it does not name** is recorded in
`prototypes/01b-variant-a-at-length.md:587–591`: `Fib/1`, `Fib/2` and `Fib/3` in one module, and
*"two unrelated helpers can collide silently."*

### The two spellings, in code

**A — arity overloading permitted** (the BEAM's own identity rule, unmodified):

```csharp
module Fib

list<int> Fib(int n)
Fib(n) when n <= 0 -> []
Fib(n) when n > 0  -> Fib(n, 0, 1, [])

list<int> Fib(int n, int a, int b, list<int> acc)
Fib(n, a, b, acc) when n <= 0 -> Reverse(acc, [])
Fib(n, a, b, acc) when n > 0  -> Fib(n - 1, b, a + b, [a, ..acc])
```

**B — one arity per name** (`Fib/1` and the accumulator helper must have different names):

```csharp
module Fib

list<int> Fib(int n)
Fib(n) when n <= 0 -> []
Fib(n) when n > 0  -> Series(n, 0, 1, [])

list<int> Series(int n, int a, int b, list<int> acc)
Series(n, a, b, acc) when n <= 0 -> Reverse(acc, [])
Series(n, a, b, acc) when n > 0  -> Series(n - 1, b, a + b, [a, ..acc])
```

**B is what `examples/fib.bs` already writes**, unprompted — `Fib/1`, `Series/4`, `Reverse/2`,
three distinct names. That is evidence of **idiom, not of constraint**, and the distinction is the
whole of this question: nothing on the BEAM breaks under A, and `math.bs` next door has its own
`Fib/1` in a different module with no issue.

### What each costs

| | A — overloading permitted | B — one arity per name |
|---|---|---|
| BEAM identity | unchanged: name+arity | narrowed: B# identity is the **name** |
| The 01b hazard | live — two unrelated helpers collide silently | impossible by construction |
| Cost | none at the compiler; a real read hazard | forces a name for every helper (`Series`) |
| `ls` under one-function-per-file | one file must hold N arities, or filenames disambiguate | one file, one name, one function |
| `bsc --api`, residuals, `caller_head/3` | must print name+arity to be unambiguous | a name alone identifies |

**The argument I will not make.** Ticket 34/F4 refuses rebinding because *"a name means one thing
in a clause"*, and lifting that to *"a name means one thing in a module"* is an **analogy, not a
mechanism**. B is a real language restriction with a real cost — it is what forces `Series` to
exist — and that cost is not the compiler's to accept.

### Compiler delta

**A**: none. **B**: one check in `bs_check`, over the function list, raising
`{name_overloaded, Name, Line}` into the path `bsc:resolve_error/2` already catches — the same
route `kind_field_is_minted` takes, and the same shape as the type-redeclaration check the
features README specifies.

### Sub-question — does the filename fix the exported name?

Ticket 23 §10 makes the directory listing part of the API surface. So does `Shop/Orders/Apply.bs`
**define** `'Shop.Orders':Apply`, with the compiler erroring when the signature inside disagrees,
or is the filename a convention the signature may contradict? If the latter, listing and API can
drift, which is what 23 §10 exists to prevent. This rides on §2: under A a filename cannot
identify a function at all without carrying the arity.

---

## §3. THE QUESTION — export control

**Today every function is exported, unconditionally** — `bs_emit.erl:55–62`:

```erlang
Exports = [{F, arity(F)} || F <- Fns],
```

Under one function per file plus 23 §10's *"the listing is the API surface"*, a private helper is
still a file and still appears in the listing. `Series` and `Reverse` in `fib.bs` are both
implementation detail and both currently public.

**Both defaults are live borrows and neither is forced:**

```csharp
// default public, `private` opt-in            // C# members default private;
private list<int> Series(int n, int a, …)      // BEAM defaults to explicit -export.
```

- **C#** defaults members to *private* and marks `public`.
- **The BEAM** defaults to unexported and marks `-export`.
- **TypeScript** defaults to module-private and marks `export`.

So every tier-1 and tier-2 source defaults to *closed*, and the language currently defaults to
*open*. That is worth stating plainly because it means "keep today's behaviour" is the option with
no precedent behind it.

**One mechanism input, which constrains but does not decide.** Ticket 06 measured that
`-behaviour` has no runtime effect and **only exports matter** — `gen_server` builds
`fun Mod:handle_call/3` off the module atom. So under a closed default an unexported callback
breaks the behaviour at run time, which is a failure that goes *quiet* — the exact shape that has
bitten this project three times (F5's vacuous containment, F6's hang, F9's byte-vs-UTF-8). That
is survivable either way: F10 already ships a contract-scoped table of callback names and arities,
so the compiler can name a callback that is not exported and error at the declaration. **It is a
reason to build the check, not a reason to pick the default.**

### Compiler delta

One modifier token in `signature`, and a filter on the `Exports` comprehension. Plus, whichever
default is chosen, one check joining that filter to `bs_otp:callback_name/3`.

---

## What this ticket does not decide

- **Where tests live** (ticket 24). Real, sharpened by 23 §10, downstream of §2 and §3, and it
  blocks no build.
- **What `index.bs` may hold.** → [ticket 41 §4](41-imports-and-cross-module-scope.md).
- **Where another module's types come from.** → ticket 41 §3, which is the half that actually
  blocks `List.Map`.

## What it unblocks

The collection library, and through it three things that each name the module system as their
blocker: AoC file input (F9's own note — `string` removed *one of three*), every string
*operation* (`LANGUAGE.md:184`), and four of the seven exemplar dialect gaps.
