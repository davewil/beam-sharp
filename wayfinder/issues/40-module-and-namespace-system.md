# 40 — What is a module, what atom does it emit, and what does it export?

Type: grilling
Status: **resolved 2026-08-15, §3 amended 2026-08-17** — all three sections answered and **built**:
§1 and §2 by F11/F15, §3 by F12. Both specified checks exist (`name_redeclared`, `private_callback`).
**The amendment reverses §3's default**: an unmarked signature is *private*, where the resolution had
said every function must be marked. See *"AMENDED 2026-08-17"* in §3.

Raised 2026-08-15 from the fog patch *"Module and namespace system, and function identity"*,
which four other patches wait on, and which
[`examples/exemplars/README.md`](../../compiler/examples/exemplars/README.md) names as
*"four of the seven [dialect gaps] … the same fog patch wearing different clothes"*.

Its sibling is [ticket 41](41-imports-and-cross-module-scope.md), raised together because the two
interlock: §2 here decides what a name identifies, and 41 §1 decides how another module says it.

## The failure is already in the repo

`aoc/2019/Day01/day01.bs` and `aoc/2025/Day01/day01.bs` both open with `module Day01`. Built to a
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

## §2. ANSWERED 2026-08-15 — arity overloading is PERMITTED

**A. The BEAM's own identity rule, unmodified: a name may carry more than one arity in a module.**

David: *"one arity per name seems a complete dead end."* The cost is what forced `Series` to exist
as a separate name for what is plainly still Fibonacci, and no mechanism ever required it —
`examples/fib.bs` writing `Fib`/`Series`/`Reverse` is **idiom, not constraint**, which is the
distinction this section was written to keep.

**The argument that was NOT made, and should stay unmade.** Ticket 34/F4 refuses rebinding because
*"a name means one thing in a clause"*, and lifting that to *"a name means one thing in a module"*
is an **analogy, not a mechanism**. Nothing on the BEAM breaks under overloading.

### The 01b hazard was mis-cited, and it is orthogonal to this question

This section first cited `01b:587–591` as *"`Fib/1`, `Fib/2` and `Fib/3` in one module"*. **Wrong.**
The text reads *"`Fib/1`, `Fib/2` and **`Fib/2` again**"* — the tail-recursive `Fib(Nat, int, int)`
is `Fib/3`, but the memoised `Fib(Nat, map)` is `Fib/2`, and had the accumulator version taken one
accumulator it would have been `Fib/2` as well.

So the hazard is **same name *and* same arity**, which is a duplicate declaration under A and under
B alike. It was never an argument for B, and choosing A does not inherit it. It is a separate
defect, live today, and §2 is not its owner — it is recorded here only because citing it wrongly is
what made it look like §2's business.

### What actually happens today — measured, and "silently" is half right

Two `Combine/2` declarations with identical signatures and different bodies:

```csharp
int Combine(int n, int m)
Combine(n, m) when n > 0  -> n + m
Combine(n, m) when n <= 0 -> m

int Combine(int n, int m)      // someone else's helper, same name and arity
Combine(n, m) when n > 0  -> n * m
Combine(n, m) when n <= 0 -> 0
```

```
silent.bs:11: warning: clause 3 of Combine is unreachable
silent.bs:12: warning: clause 4 of Combine is unreachable
erlc: Silent.abstr:0: function 'Combine'/2 already defined
      Silent.abstr:0: spec for 'Combine'/2 already defined
```

**The checker merges the two into one four-clause function** — that is what "clause 3" and
"clause 4" mean, there being only two clauses under each signature — and reports them as
unreachable. The program is stopped, but by **erlc at the back of the pipeline**, against
`Silent.abstr:0`: no line, no `.bs` filename, and a message about a file the author never wrote.

**The defect is the diagnosis, not the outcome.** *"Clause 3 is unreachable"* reads as a remark
about the code when the truth is *"you declared this function twice"* — the identical costume to
F7's `true`/`false` bug, where the only trace was an unreachable-clause warning that read like a
comment on the code rather than a report of a misparse. Second appearance of that shape, and the
features README's rule applies: a capability that reports the wrong thing is not caught by a green
suite.

### The owed check, fully specified

A **sibling of the type-redeclaration check** the features README already specifies, at the
function level rather than the type level:

```
bs_check   before the per-function walk, group the signatures by {Name, Arity}
           any group of size > 1 raises {name_redeclared, Name, Arity, Line}
           into the path bsc:resolve_error/2 already catches — the route
           kind_field_is_minted takes, and the reason it can report a line.
           One new resolve_error/2 clause carries the message.
```

It must fire **before** the exhaustiveness walk, or the merged clauses generate the misleading
unreachable warnings first. Not yet built; owned by whichever feature implements §1.

---

## §2 (original framing, kept for the record) — may a name be overloaded on arity?

The fog patch's title says *"function identity — BEAM identifies functions by name **and arity**,
which multi-clause heads and optional parameters both disturb."* **Measured, neither does:**

- **Multi-clause heads collapse cleanly.** F1 shipped it; `arity(F)` yields one arity per
  function, and the export list, `-spec`, definition and every local call are funnelled through
  one `name/2` (`bs_emit.erl:69–74`) so they cannot drift.
- **Optional parameters do not exist.** `param -> type_prim lident | type_prim` — named or
  anonymous, never defaulted. The `?` marker is a *record field* form only.

So the patch names two hazards that are not live. **The live one it does not name** is recorded in
`prototypes/01b-variant-a-at-length.md:587–591`: `Fib/1`, `Fib/2` and **`Fib/2` again**, and
*"two unrelated helpers can collide silently."* (Corrected above — this was first written as
`Fib/3`, which put the hazard in the wrong section.)

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

## §3. ANSWERED 2026-08-15 — `public` / `private` at the signature

David: *"Follow the beam convention for exports, elixir uses def/defp right? — So public/private
works for B#."*

**Elixir's placement, C#'s words.** The marker sits on the signature, one per function:

```csharp
public  list<int> Fib(int n)
private list<int> Series(int n, int a, int b, list<int> acc)
private list<int> Reverse(list<int> xs, list<int> acc)
```

### Why this is the BEAM convention rather than a C# import

Both BEAM languages make export an **explicit, per-function decision**; they differ only in where
the decision is written.

| | Where the decision lives | Unmarked case |
|---|---|---|
| Erlang | a separate `-export([f/1])` list | private |
| Elixir | at the definition — `def` / `defp` | **none: every function is marked** |
| C# | at the member — `public` / `private` | private |
| beam-sharp today | nowhere | everything public |

Taking Elixir's *placement* avoids the one thing Erlang's list costs: a second site that must agree
with the definition, which is exactly the drift `bs_emit`'s single `name/2` funnel was written to
prevent (*"they must agree or the module exports a name nothing defines"*). Taking C#'s *words*
follows the map's amended heuristic — **survey all three tiers, take the most accurate word** —
since `public`/`private` say the thing plainly to both halves of the audience, where `def`/`defp`
carries Elixir's macro vocabulary B# has no use for.

This is the same shape as ticket 35's `behaviour`: the mechanism comes from the BEAM, the spelling
from wherever it reads best.

### AMENDED 2026-08-17 — private is the default; `public` deliberately exposes

**An unmarked signature is private.** `public` exposes a function from its module; `private` may
still be written and means what the absence already means. This **reverses** the paragraph kept
below, and it is the reversal that paragraph named in advance.

David: *"maybe private by default, public to deliberately expose from a module."*

**The original framing had already measured the case and the resolution went the other way.** It is
recorded further down this section: C# defaults members to private and marks `public`; the BEAM
defaults to unexported and marks `-export`; TypeScript defaults to module-private and marks
`export`. **Every tier-1 and tier-2 source defaults to closed.** The borrow heuristic ranks sources
and takes the most accurate word — and on this question all three tiers agree, which is as strong
as that heuristic ever gets. Taking Elixir's *no unmarked case* was taking the one convention that
had no second vote behind it.

**What the reversal costs is one check, and it is a deletion**: `{missing_visibility, Name, Line}`
goes, because there is nothing left to miss. Nothing else about §3 changes — the marker's placement,
its spelling, the export filter and the private-callback check are all untouched, and `private`
remains legal so no `.bs` file needs editing.

**What it buys is the thing defaults are for.** A module's surface becomes the list of things
somebody wrote `public` in front of, which is a shorter and more deliberate list than "everything
nobody wrote `private` in front of". Under the old rule a forgotten marker was an error; under this
one a forgotten marker is *safe*, and the failure mode moves from "the compiler stopped you" to "the
function is not exported", which the private-callback check already catches for the one case where
that would go quiet.

**One cost is real and is accepted rather than argued away.** A new file whose functions are all
unmarked exports nothing, so `bsc examples/Thing 5` cannot run it — and `erlc` additionally deletes
an unexported function that nothing calls, warning `function 'Go'/1 is unused`. Measured
2026-08-17: a fresh one-function module answers with that warning and then
*"which function? the module exports "* with an empty list. **That is the default biting at exactly
the moment the language is least able to explain itself**, and the harness exists to make code
runnable, so the message is owed by this amendment rather than by a later feature: an empty export
list must say that the module exports nothing and that an unmarked signature is private. It
self-corrects the moment the entry point is marked, which is the one word this default is asking
for.

<details><summary>The original resolution, reversed above and kept as written</summary>

`def`/`defp` has **no unmarked case**, and that is the half of Elixir's convention being taken:
a signature carries `public` or `private`, never neither. The standing constraint supports it —
write cost is near-free because agents author these files, and a reader never having to know a
default is a read-cost win at full weight. It also makes ticket 22's *"enforced conventions are
guardrails on the agent"* concrete.

**If that is the wrong half**, the alternative is one line: make `private` the marker and public the
default (or vice versa). Nothing below depends on which, and nothing is built yet.

</details>

### The check this makes possible, and why it is not optional

Ticket 06 measured that `-behaviour` has **no runtime effect** and only exports matter —
`gen_server` builds `fun Mod:handle_call/3` off the module atom. So a `private` callback breaks the
behaviour at *run time*, silently, which is the failure shape that has bitten this project three
times (F5's vacuous containment, F6's hang, F9's byte-vs-UTF-8).

F10 already ships the contract-scoped table this needs, so the check is cheap and must ship with the
keyword rather than after it: **a `private` function whose name and arity are a callback of a
behaviour the module declares is an error at the declaration**, via `bs_otp:callback_name/3`.

### Compiler delta for §3

```
bs_lexer.xrl    public   : {token, {'public',  TokenLine}}.
                private  : {token, {'private', TokenLine}}.
                (two lines; no .bs file uses either word today, measured)

bs_parser.yrl   signature -> visibility type_prim uident '(' params ')'
                visibility -> 'public' | 'private'

bs_emit.erl:55  Exports = [{F, arity(F)} || F <- Fns, is_public(F)]

bs_check        a private F whose {Name, Arity} is in bs_otp:callback_name/3 for a
                declared behaviour raises into the resolve_error/2 path
```

Plus a rewrite of all 29 `.bs` files. That cost is the F8 precedent exactly — F8 took its slot ahead
of binaries *because* it rewrote every file and every later feature adds more of them. The same
argument applies here and points the same way: sooner is cheaper.

---

## §3 (original framing, kept for the record) — export control

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
