# 41 — How does a module name another, and where do its types come from?

Type: grilling
Status: **resolved 2026-08-16** — all five sections answered. [ENG-209](https://linear.app/davewil/issue/ENG-209)

§1, §2 and §5 landed 2026-08-15; §3 and §4 on 2026-08-16. **§3 was the prerequisite rather than a
neighbour** — neither unqualified names (§2) nor namespace resolution (§5) could be checked without
it, so those two were answered-but-unverifiable for a day. They are not any more.

**One item spun out rather than absorbed**: the import alias (`using List = Shop.Collections.List`)
is [ticket 47](47-import-alias.md) · [ENG-219](https://linear.app/davewil/issue/ENG-219). It was
parked below with a note that §2 *changed its standing and it should be re-asked rather than
inherited*, which is a decision this ticket does not own.

Three checks are specified and unbuilt — `{module_path_mismatch, …}` (§5), `{function_in_index, …}`
(§4), and §2's ambiguity rule — plus the environment-threading delta in §3. They belong to the
feature that implements the module system, in the same way ticket 40's two checks do.

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

## §3. ANSWERED 2026-08-16 — the compiler re-checks the dependency's source, and owns the graph

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

### ANSWERED 2026-08-16 — the graph is the compiler's, and the premise above is wrong

**First, the correction, because it changes the price.** This section opens by saying *"the compiler
is single-file (`bsc FILE.bs`, one `module` declaration, one `.beam`)"*. **That is false**, measured
in [`41a`](../prototypes/41a_multifile_probe.sh):

```
$ bsc Alpha.bs Beta.bs
exit=0
beams: ./Alpha.beam ./Beta.beam
```

`bsc` already takes a **set** of files and loops over it — `compile_or_run/3` splits argv into files
and run-args, and `compile_only/2` is `[file(F, Opts) || F <- Files]`. What is single-file is the
**environment**, not the invocation. The distinction is the whole cost question: fork A does not need
a new CLI shape, a new entry point or a new artefact. It needs the fold that loop already is to carry
an accumulator.

**Second, the isolation is clean, which is the fact that makes this safe.** A file naming a function
defined in another file of the same invocation is rejected, and rejected *identically in both
argument orders*:

```
$ bsc Alpha.bs Gamma.bs     # Gamma calls Double/1, defined in Alpha
Gamma.bs:5: error: Eight calls Double/1, which nothing declares
$ bsc Gamma.bs Alpha.bs     # same error, order reversed
```

So there is no accidental leakage to undo and no order-dependence already baked in. Whatever
cross-module visibility gets added is **entirely** the new rule, not the new rule plus an
undocumented one — which is not something a design gets for free, and is worth recording before
anything touches `bs_check`.

#### The graph cannot be a build tool's, and the reason is mechanism rather than preference

The fork's two options are not symmetric once the question is put as *"who computes the order?"*

**An order alone buys nothing.** Suppose a build tool topologically sorts the source tree and feeds
`bsc` one file at a time in dependency order. The second invocation still has no way to *learn* the
first module's signatures: it starts with an empty environment and the `.beam` on disk carries no
B# types. To make an externally-computed order useful, the signatures must persist between
invocations — and a persisted signature artefact **is fork B**, which this section already disposed
of twice: no source-less consumer exists, and it is blocked on ticket 16 §4's serialisation mapping,
which the map lists as owed and unwritten.

So *"the build tool owns the graph"* is not a third option. It **reduces to fork B** and inherits
fork B's blocker. That collapses the sub-question the same way ticket 35's did — F10's lesson was
*check whether the alternative can be expressed before weighing it*, and the version here is that the
alternative can be expressed but not **completed**.

**The compiler therefore resolves the graph, within one invocation.** `using Shop.Orders` is a path
on disk (§5); `bsc` resolves it, checks that module, and keeps its public signatures in the
environment for the module that imported it. Correct by construction, nothing to go stale, and no
artefact that can disagree with the source — which is fork A exactly as this section framed it.

#### What is left for a build tool, stated so it is not the next unraised blocker

**Naming the source root and the file set — not the order.** That is the boundary, and it is the
only build-tool decision this ticket creates:

- `bsc` is given a set of `.bs` files (as it already is) or a directory to walk, and computes the
  order itself from the `using` edges.
- A build tool's job is *which files*, *where the source root is*, and *what to do with the output* —
  not *in what sequence to compile them*.

**Where that decision now lives**: nowhere yet, deliberately. B# has no build tool, none is
scheduled, and the map's `scope.md` audit found three of its four boundaries waiting on a use case
rather than refusing one. This is a fourth of the same shape. It is recorded here rather than
raised as a ticket because **there is nothing to decide until something needs building that a file
list cannot express** — and the sentence above is what a future session needs in order to notice
that moment, which is the failure mode the repo has now paid for three times.

#### Two things this does not decide

**Not a cycle rule.** Two modules importing each other is a real question and the compiler will need
an answer — F6 already shipped a cyclic-*alias* guard after a hang, so the precedent for refusing by
name rather than expanding exists. But it is a mechanism the implementing feature meets, not a fork
this ticket must resolve, and stating it as owed is cheaper than guessing at it.

**Not re-checking cost.** Fork A re-checks a dependency's source on every build of its dependents.
That is a compile-time cost with no runtime component and no correctness consequence, and the map's
standing constraint puts write and build cost near zero against read cost. If it ever bites, the fix
is a cache, which is fork B under a different name and can be reconsidered when ticket 16 §4 lands.

#### Compiler delta for §3

```
bsc          compile_only/2 stops being an independent map over Files and becomes a
             fold: resolve `using` edges to paths, order by them, thread one
             signature environment through. The file-set plumbing already exists.

bs_check     the environment gains an imported-signature table, populated from the
             dependency's checked signatures rather than from a file on disk.
             §2's two import tables and one ambiguity rule are what read it.

grammar      `using` modpath and `Module.Fn(…)` both still unparseable — measured
             again in 41a (`syntax error before: 'Alpha'`, `syntax error before: '.'`).
             Owed by §1 and §2, unchanged by this section.
```

---

## §4. ANSWERED 2026-08-16 — everything except functions

`LANGUAGE.md:75` says a module is a directory, one function per file, and *"`index.bs` holds the
declarations shared across it"*. `prototypes/25a/25b/25c` use it, and
`01e-otp-under-directory-module.md:203–211` records that nested directories inside a module, and
`server.bs`-inside-`server/` versus `_module.bs`, are all unresolved. **Nothing has ever compiled
an `index.bs`** — it is an unbuilt convention.

Uncontroversial that it holds the `module` declaration, `type`/`record` declarations, the
`behaviour` declaration and the module's `using` lines.

**Half of this is now closed by §5.** *What a nested directory means* has an answer from both ends:
ticket 13 settled the **inside** case (a directory within a module is a sub-module, source-only,
same `.beam`), and §5 settles the **outside** case (a directory holding no `.bs` files is a
namespace, erased). Between them every directory in the tree is classified.

**What remains open is one question**: may `index.bs` hold **functions**, or does
one-function-per-file have no exception? Note it now carries a second job from §5 — a directory's
`.bs` files are what make it a module rather than a namespace, so a module with no functions yet
still needs `index.bs` to exist for the classification to come out right.

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

### ANSWERED 2026-08-16 — `index.bs` holds no functions, and one-function-per-file has no exception

**The three exemplars already answered this and nobody had looked.** All three `index.bs` files in
`compiler/examples/exemplars/` were written before this question was asked, and all three hold
**zero functions** — only `using`, `type`, `record` and `behaviour`, which is exactly the set this
section calls uncontroversial:

| File | Holds | Functions |
|---|---|---|
| `25a-http-api-server/index.bs` | `using`, 2 `type`, 2 `record` | 0 |
| `25b-websocket-handler/index.bs` | `behaviour`, `type`, `record` | 0 |
| `25c-event-queue-consumer/index.bs` | `behaviour`, 6 `type`, 3 `record` | 0 |

That is evidence rather than prediction: three programs the design must serve, and the exception was
never reached for. It does not settle the question by itself — nobody was stopped from writing one —
but a rule that costs its own examples nothing is a different proposition from one that does.

#### The mechanism is `write_scope`, and it points one way

The map's standing constraint says **one function per file makes `write_scope` a file** — bounded
blast radius, no merge conflicts between agents working different operations, reviewable single-file
diffs. `index.bs` is the one file in a module that **every** agent must edit: a new record goes there,
a new type alias goes there, a new `using` line goes there. It is the module's contended file by
construction.

Permitting functions in it would merge the most-contended file in the module with the one thing the
file-per-function rule exists to isolate. Two agents adding unrelated functions would then collide in
a file **neither of their functions is in** — which is precisely the failure `write_scope = one file`
was chosen to prevent, arriving through the one file the rule did not cover.

**And the write-cost objection does not survive the standing constraint.** *"A three-line private
helper deserves its own file"* is a ceremony complaint, and ceremony is near-free here: humans do not
author these files, agents do, with generators scaffolding them. Read and review cost carries full
weight and points the same way — a reader looking for `Total/1` looks in `Total.bs`, and an
exception means every such search has a second place to check.

#### It strengthens §5's classification job rather than complicating it

§5 gave `index.bs` a second job: a directory's `.bs` files are what make it a module rather than a
namespace, so a module with no functions **yet** still needs `index.bs` to exist for the
classification to come out right. Keeping it function-free makes that job unambiguous — `index.bs`
is *the declaration file*, its presence is the module marker, and the two roles never compete. The
alternative leaves `index.bs` meaning "declarations, and also possibly some functions", which is a
worse thing to have to explain than either half.

#### The helper case, answered rather than waved away

A module-private helper gets **its own file**, and ticket 40 §2's `private` on the signature is what
keeps it out of the export list. Nothing about the aggregate rule changes: ticket 13 already made
every `.bs` file in the directory compile into the one `.beam`, and `13b` measured per-file
attribution surviving that aggregation with exact lines. A private helper in its own file costs one
file and zero runtime.

#### One new check

```
bs_check     {function_in_index, Name, Line} into resolve_error/2 — a function
             declaration in a file named index.bs is an error at the declaration.

             Precedent is exact: `kind_field_is_minted` errors at a declaration,
             rebinding is an error because "a name means one thing in a clause"
             (34, F4), and §5's own {module_path_mismatch, …} takes the same route.
```

**Deliberately an error rather than a convention.** A convention here is unenforceable and would
decay exactly as the exemplars' dead dialect and `LANGUAGE.md`'s `true` claim did — both cases where
prose asserted a rule nothing gated. This one is a single check at a declaration with a filename
test, which is the cheapest gate in the file.

---

## §5. ANSWERED 2026-08-15 — a namespace is a directory that holds no `.bs` files

David: *"what about using the namespace concept in B#?"*

**A directory containing `.bs` files is a module. A directory containing only directories is a
namespace.** Decidable by `ls`, which is the property ticket 23 §10 wants of the layout anyway, and
requiring no marker file, no keyword and no declaration.

```
Shop/                 no .bs files      NAMESPACE — erased entirely
  Orders/             has .bs files     MODULE    'Shop.Orders'
    index.bs
    Total.bs
    Internal/         inside a module   SUB-MODULE, source-only (ticket 13)
  Billing/            has .bs files     MODULE    'Shop.Billing'
```

### It names a hole rather than adding a concept

The first framing of §2 said B# *"has no room"* for C#'s middle tier. **That overstated it.** What
B# lacked was a *name* for the case, not the case: ticket 13 already settled that a directory inside
a module is a **sub-module, source-only, not its own beam**, so `Shop` as a module and `Shop.Orders`
as a separate module already could not coexist — namespaces or not. Naming the outer case costs
nothing new; it stops the hole being unlabelled.

### What it buys

C#'s three tiers, with §2's answer unchanged as the middle one:

```csharp
using Shop;                  // → Orders.All()   short-qualified
using Shop.Orders;           // → All()          unqualified — §2
using Orders = Shop.Orders;  // → Orders.All()   alias (still owed, see below)
```

And it makes the exemplars **nearly right rather than incoherent**: `using Shop` beside
`Orders.All()` is a one-segment correction, not a tier that does not exist. §2 recorded them as
inconsistent on the strength of the earlier framing; this is the narrower and truer version.

### It costs nothing at runtime

A namespace is **erased completely** — no atom, no `.beam`, nothing emitted, no entry in any
attribute. It is purely compile-time name resolution, which is the same status ticket 13 gave
sub-modules. Neither ticket 40 §1's dotted atom nor ticket 26 §1's tag mint moves: `'Shop.Orders'`
is still the atom and `'Shop.Orders.Order'` still the tag.

**It is also a divergence from Elixir, deliberately.** Elixir has no namespaces — `Shop.Orders` is
one module whose name merely contains a dot, and `Shop` may exist independently. B# takes C#'s and
TypeScript's structure instead, because the audience is C#/TS and because ticket 13's aggregate rule
had already foreclosed Elixir's version without saying so.

### The grammar does not change; the resolution does

`using Shop` and `using Shop.Orders` are both `modpath` (§1). Which table the import populates is
decided by **what the path resolves to on disk**, not by its spelling — so §1's one grammar rule
covers both tiers.

- `using Shop.Orders` → the **function** table: `{Name, Arity} -> Module`
- `using Shop` → the **module** table: `Orders -> 'Shop.Orders'`

**One ambiguity rule covers both**, which is the reason this generalises cleanly rather than
doubling the design: a name reachable from two sources is an error at the call site printing the
qualified candidates. `using Shop` beside `using Warehouse`, both holding an `Orders`, fails exactly
as `Sum/2` beside `Sum/2` does.

### One new check, and it has a precedent

**A file's `module` declaration must match its directory path** — `Shop/Orders/Total.bs` must say
`module Shop.Orders`. This is ticket 13's measured `erlc` module-atom/filename enforcement lifted
one level, from the emitted artefact to the source tree, and it is what stops the atom in §1 and the
path on disk from drifting apart.

### Compiler delta for §5

```
bsc          resolving a `using` needs the source tree: a path with .bs files is a
             module, a path with only directories is a namespace. §3 again.

bs_check     two import tables, one lookup point, one ambiguity rule
             {module_path_mismatch, Declared, Path, Line} into resolve_error/2
```

Nothing in `bs_emit` changes at all — which is the sentence that says a namespace is not a runtime
thing.

---

## Owed by this ticket, not answered

- The yecc conflict check in §1. Still owed, and it is a build task rather than a decision.
- ~~A collision rule, **only if** §2 lands on unqualified names.~~ **§2 landed there** — the rules
  are specified in §2 and are no longer conditional.
- ~~Ticket 16 §4's serialisation mapping, **only if** §3 ever lands on B.~~ **DISCHARGED 2026-08-16.**
  §3 landed on **A**, so no signature artefact is serialised and 16 §4 is not a prerequisite of
  anything in this ticket. It remains owed to the map for its own reasons (ticket 23 §5's JSON
  encoding), unchanged.
- ~~**An alias, `using List = Shop.Collections.List`**~~ — **RAISED 2026-08-16 as
  [ticket 47](47-import-alias.md) · [ENG-219](https://linear.app/davewil/issue/ENG-219).** It was
  parked here with the note that §2 *changed its standing* — while the qualified form was on the
  table an alias was a pure read cost, and now that unqualified names are legal an alias is strictly
  **more** explicit than the thing it competes with — and that *"it should be re-asked rather than
  inherited"*. Re-asking is a decision, and this repo's own rule is that naming a decision you need
  **is** raising a ticket, which does not count as raised until the file and the issue both exist.

**Two things §3 added to this list rather than deciding:**

- **A cycle rule.** Two modules importing each other. F6's cyclic-*alias* guard is the precedent —
  refuse by name rather than expand, shipped after a hang that no green suite could see — but the
  import case is a mechanism the implementing feature meets, not a fork this ticket owns.
- **The build-tool boundary is recorded, not raised.** §3 states it explicitly: a build tool names
  the source root and the file set, never the order. There is nothing to decide until something needs
  building that a file list cannot express, so no ticket exists — and §3 carries the sentence a
  future session needs in order to notice that moment.
