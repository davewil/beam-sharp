# 41 — How does a module name another, and where do its types come from?

Type: grilling
Status: **claimed** 2026-08-15 — §1 and §2 answered. §3 and §4 open, and **§2's answer put §3 on
the critical path**: unqualified names cannot be resolved without each import's exported name/arity
set, so §3 is now a prerequisite of building §2 rather than a neighbour of it.

Raised 2026-08-15 from the fog patch *"Imports and cross-module scope"*, together with
[ticket 40](40-module-and-namespace-system.md). 40 decides what a module is and what a name
identifies inside it; this one decides how a *second* module says that name, and how the checker
knows its type.

**§3 is the load-bearing one, and it appears in neither fog patch.** It is what actually blocks
`List.Map`, and therefore the collection library, and therefore AoC input and every string
operation.

## What does not parse today

```csharp
Go() -> List.Map(1)
```
```
qcall.bs:5: error: syntax error before: '.'
```

The grammar has `atom_lit '.' lident '(' … ')'` for FFI and `lident '.' uident` for projection,
and **no** `Module.Fn(…)` at all. The exemplars write both `using Shop.Orders` and
`Json.Encode(b)`, `Orders.All()`, `List.Fold(…)` — all four unspelled, and
`examples/exemplars/README.md:116` files them under "module fog".

---

## §1. Naming a module — ANSWERED, on mechanism

**`using` generalises; the call site is qualified.** No new keyword is needed and no ambiguity is
introduced, because the two forms differ in the **token class of the left side** — exactly the
discriminator `LANGUAGE.md` §11 already uses for the three dot-forms:

```csharp
using :lists {                       // atom_lit → FOREIGN: attaches types to Erlang's own name
    int sum(list<int> xs)
}

using Shop.Orders                    // uident path → NATIVE: declares a dependency
```

| Form | Left side | Means |
|---|---|---|
| `o.Status` | `lident` | field projection |
| `List.Map(x)` | `uident` | qualified call |
| `:ets.lookup(x)` | `atom_lit` | foreign call |

Three reasons this is mechanism rather than preference:

1. **`using` is C#'s own import keyword** (`using System;`) — a tier-1 borrow that happens to be
   the word already in the language, so the borrow heuristic and the existing surface agree.
2. **The FFI `using` already introduces no B# name.** `LANGUAGE.md` §11: *"The declaration attaches
   types to the name Erlang already has. It does not introduce a B# name."* A native `using` that
   also introduces no name is the **same construct**, not an overloaded one.
3. **It answers ticket 23 §11 directly.** 23 found *"forbid an edit in one file changing another
   file's meaning"* unworkable as stated, and concluded the live question is whether a file
   **declares what it depends on**. Under one-function-per-file a file's `using` lines are its
   dependency list, in the file, checkable.

### Compiler delta for §1

```
bs_parser.yrl   using_decl -> 'using' modpath              (native form, no block)
                expr -> modpath '.' uident '(' expr_list ')'
                expr -> modpath '.' uident '(' ')'
```

`modpath` is ticket 40 §1's rule, shared. **One yecc conflict check is owed** — `modpath` and
`type_prim -> uident` both start with `uident`, and `expr -> uident '{' … '}'` (record
construction) and `expr -> uident '(' … ')'` (local call) are live neighbours. The claim is that
LALR(1) separates them on the following token; it has not been run.

---

## §2. ANSWERED 2026-08-15 — `using` brings names into scope UNQUALIFIED

David: *"I think B would be expected"* … *"whatever needs to be done to support B should be done."*

```csharp
using Shop.Orders

int Total(Order o)
Total(o) -> Sum(o.Lines)          // not Shop.Orders.Sum(o.Lines)
```

**The audience test decides it**, and the map elevates that test explicitly: *a construct a C#
developer reads on sight, versus one they must be taught.* An import that leaves every call site
fully qualified makes the `using` line look like it does nothing, which is the opposite of what
either audience expects.

### C# has three tiers, and B# has room for only one

```csharp
using Shop;                  // → Orders.All()   namespace in scope, type name short
using static Shop.Orders;    // → All()          members in scope, unqualified
using Orders = Shop.Orders;  // → Orders.All()   alias
```

C#'s two-tier `using` exists because C# splits **namespace** from **type**. B# has no such split:
`Shop.Orders` is one module, one atom (§1 of [ticket 40](40-module-and-namespace-system.md)), and
its functions are its members — there is no inner level for a short form to name. So plain `using`
meaning *unqualified* is the only tier this language has room for, and it is **TypeScript's
named-import semantics exactly**. Adding `using static` would import a distinction B# does not have.

**The exemplars are internally inconsistent here and it is worth recording rather than emulating.**
They write `using Shop.Orders` *and* `Orders.All()`, `List.Fold(…)`, `Json.Encode(b)` — the middle
tier. In real C# that pair does not compile: if `Shop.Orders` is a namespace then `Orders` is not a
name. They were written as fog, before any of this was spelled, and the short-qualified shape they
reach for is an **alias** question (see Owed, below), not this one.

### The objection to B, and why it dissolves

This section first argued for the qualified form on a mechanism ground: the compiler's diagnostics
emit *pasteable source* — `heads/2` prints the clause to add, `caller_head/3` the head the caller
must write — so under B the printer must choose a spelling, and choosing wrong hands the user text
that does not compile. That would break ticket 23's property that the residual **is** the missing
case.

**It has a one-line answer: diagnostics always print fully qualified.** A qualified call is legal
regardless of what is in scope at the call site, so the printer never has to know the scope. Costs
nothing, and the pasteability property survives intact. That was the only mechanism argument against
B, and it does not survive contact with the fix.

### What B requires

1. **Ambiguity is an error at the call site**, printing the qualified candidates — so the error
   hands over the fix, the same idiom as the residual. Not a silent winner: a quiet resolution is
   the failure shape this project has been bitten by three times.
2. **An import shadowing a local name is an error**, fixed by qualifying.
   **Note this is NOT the analogy refused in ticket 40 §2.** There, `Fib/1` and `Fib/2` each have a
   perfectly defined meaning and banning them was taste. Here an ambiguous unqualified name has **no
   defined meaning at all** — so the same intuition is load-bearing in one case and decorative in the
   other, which is the distinction worth carrying rather than the rule.
3. **Resolution is by name *and* arity**, since ticket 40 §2 permits overloading. `Sum/1` imported
   beside `Sum/2` local is not a conflict; `Sum/2` beside `Sum/2` is.
4. **The checker needs each import's exported name/arity set**, which puts §3's re-check-source on
   the **critical path** rather than beside it. B cannot be built before §3 is.

### Compiler delta for §2

```
bs_check     an import environment: {Name, Arity} -> Module, built from each `using`
             resolution order for an unqualified call — local, then imports
             a {Name, Arity} reachable from 2+ sources raises {ambiguous_call, ...}
             an import shadowing a local raises {import_shadows_local, ...}
             both into the bsc:resolve_error/2 path, both printing QUALIFIED candidates

bs_emit      an unqualified call to an imported name emits a REMOTE call to that
             module's atom — the resolution happens at check time, never at run time

diagnostics  every printed call/head is fully qualified, unconditionally
```

---

## §2 (original framing, kept for the record) — does `using` bring names into scope unqualified?

§1 settles that `using` names the dependency. It does **not** settle whether the call site may then
drop the qualifier.

```csharp
using Shop.Orders

// A — always qualified                     // B — unqualified after import
Total(o) -> Shop.Orders.Sum(o.Lines)        Total(o) -> Sum(o.Lines)
```

**For A**: the standing constraint says read cost carries full weight and write cost carries little,
and an unqualified name whose origin the reader must hunt for is a read cost. It is also what the
FFI form already does — `:lists.sum(xs)`, never `sum(xs)`.

**For B**: `Shop.Orders.Sum(…)` at every call site is what the exemplars *didn't* write; they wrote
`List.Fold(…)` — qualified, but by a **short** module name, which is a third thing this question
should not conflate with either option.

**The alias I am not slipping in as ergonomics.** C# has `using Orders = Shop.Orders;`, a tier-1
borrow that would soften A. It is a read cost by the same standard that argues for A — the reader
now has to find the alias line — so it is a question, not a sweetener, and it belongs to whoever
takes §2.

**Interaction with ticket 40 §2**: under B, an unqualified `Sum` must resolve against both the
local module and every import, so a collision rule is needed; under A no such rule exists. If 40 §2
also lands on "one arity per name", the resolution rule is over names alone.

---

## §3. THE QUESTION — where does the checker get another module's types?

**This is the real blocker and neither fog patch names it.** To type `List.Map(xs, f)` the checker
needs `List`'s signature *in the B# algebra*, and the compiler is single-file
(`bsc FILE.bs`, one `module` declaration, one `.beam`).

That this is unexplored rather than merely unwritten is already on record — the Dialyzer corpus
study logs it as two of its own gaps: *"[g2] … Nothing here calls out of its own module"* and
*"[g3] the language has no module or import system yet (still fog)"*
(`research/13-dialyzer-on-emitted-specs.md:221–224`). A sweep of `research/` and `prototypes/`
for imports, `-import`, aliasing, shadowing or resolution order returns **nothing measured
anywhere**. This and §2 are the two places the effort has no evidence at all.

### The fork

**A — re-check the dependency's source.** The compiler resolves `using Shop.Orders` to a directory,
checks it, and keeps its signatures in the environment. Correct by construction, no new artefact,
nothing that can go stale. Costs a build-order/dependency-graph question, and requires the source
to be present.

**B — the types travel inside the `.beam`.** Erlang permits arbitrary module attributes and the
emitter already writes three (`module`, `export`, `behaviour`, plus `spec` and `file`), so a
`-bs_sig([…])` attribute carrying the module's public signatures in the B# algebra would ride in
the attributes chunk and be readable via `beam_lib`. Nothing can go stale, and a compiled B#
library is usable **without source**.

### Answer the cheap question first

F10's lesson was *check whether the alternative can be expressed before weighing it*. The version
that applies here is **check whether the alternative is needed before designing it**:

> All 29 `.bs` files in this repo are in this repo. No compiled B# artefact ships anywhere, to
> anyone. There is no consumer of a source-less B# library and none is scheduled.

So **re-check-source covers every case that exists today**, and B is a solution to a problem that
has not arrived. Saying that plainly is worth more than designing B — and it matches the
`scope.md` audit's finding that three of the four boundaries wait on a use case rather than
refusing one.

**B is also blocked, and may not be decided here.** Serialising the type algebra is ticket 16 §4's
mapping, which the map lists as owed and unwritten — the same reason ticket 23 §5's JSON encoding
is marked blocked. A ticket may not decide a mechanism whose prerequisite is undecided.

**What is genuinely open** is therefore narrower than the fork suggests: whether A's dependency
graph is the compiler's job or a build tool's. Ticket 23 settled that the compiler already names
every affected file *within* the compilation unit for free, because ticket 13 made the directory
the module — so what is owed is only the **cross-module** half.

---

## §4. THE QUESTION — what may `index.bs` hold?

`LANGUAGE.md:75` says a module is a directory, one function per file, and *"`index.bs` holds the
declarations shared across it"*. `prototypes/25a/25b/25c` use it, and
`01e-otp-under-directory-module.md:203–211` records that nested directories inside a module, and
`server.bs`-inside-`server/` versus `_module.bs`, are all unresolved. **Nothing has ever compiled
an `index.bs`** — it is an unbuilt convention.

Uncontroversial that it holds the `module` declaration, `type`/`record` declarations, the
`behaviour` declaration and the module's `using` lines. **The question is whether it may hold
functions**, i.e. whether one-function-per-file has an exception, and what a nested directory
inside a module means given ticket 13 settled that sub-modules are source-only and the whole
directory compiles to one `.beam`.

### The mechanism is already measured, and it is not in doubt

Whatever this decides, the aggregation works. `prototypes/13b_aggregate_attribution.erl:9–20`
measured two functions in **one** beam reporting against **two** source files with exact lines,
via a repeated `{attribute,ANNO,file,{Name,Line}}` that re-points every following form:

```
total/1  →  {file,"Order/Total.bs"}, {line,42}
apply/1  →  {file,"Order/Apply.bs"}, {line,7}
```

Two riders: the Abstract Format path gives **exact** lines where the generated-Erlang-text route is
off by one (the `-file` directive occupies the line it names) — another point for ticket 13's
target; and the attribution **does not survive the Core Erlang path**, which discards the abstract
chunk. Irrelevant now, a constraint on ever switching targets.

Aggregating is also the cheaper default: `01d-submodule-realisation.md:14–53` prices a remote call
at 1.84 ns against a local 1.73 ns (6.2%), but an *inlined* local at 0.80 ns, making the remote
**2.3×** slower with `-compile(inline)` opt-in — and `code:atomic_load/1` is verified present on
OTP 28, which removes the torn-upgrade argument for splitting.

---

## Owed by this ticket, not answered

- The yecc conflict check in §1.
- ~~A collision rule, **only if** §2 lands on unqualified names.~~ **§2 landed there** — the rules
  are specified in §2 and are no longer conditional.
- Ticket 16 §4's serialisation mapping, **only if** §3 ever lands on B.
- **An alias, `using List = Shop.Collections.List`** — C#'s third tier, tier-1 borrow, and the thing
  the exemplars are actually reaching for when they write `List.Fold(…)` and `Orders.All()`. It is
  *not* needed for §2 and is not folded into it. Worth noting that §2 changes its standing: while
  the qualified form was on the table an alias was a pure read cost, because the reader had to find
  the alias line; now that unqualified names are legal, an alias is strictly **more** explicit than
  the thing it competes with. That is a different argument from the one that shelved it, so it
  should be re-asked rather than inherited.
