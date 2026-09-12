# F44 — a record or type name crosses `using`

**Status**      **done 2026-09-12** — 21 tests in `type_import_tests`; F25.23 in
                `corrected_signature_tests` flipped from *unspellable across a module boundary*
                to *spells the imported name and compiles pasted*; 837 in the suite, up from
                816. No new gate: the ticket's program is `examples/Shop/Billing/`, which
                `check-examples.sh` refused at the qualified type before the build and
                compiles after it, `editor/bin/check-corpus.sh` reported an ERROR node on the
                same token before the grammar change and parses it after, and the corpus
                roster gained *a qualified type name in a signature*. `./bin/verify.sh` green
                **twice from a clean clone**
**Implements**  [ticket 73](../../wayfinder/issues/73-a-record-name-crosses-using.md), resolved
                2026-09-11 — a record name crosses `using` in both of
                [ticket 41](../../wayfinder/issues/41-imports-and-cross-module-scope.md)'s
                spellings, `Order o` after `using Orders` (§2) and `Orders.Order o` anywhere
                (§5); a `type` alias crosses by the same mechanism under
                [ticket 09](../../wayfinder/issues/09-union-representation.md) §1; collisions
                inherit 41 §2
**Closes**      [ENG-361](https://linear.app/davewil/issue/ENG-361)
**Decides**     nothing. One spelling the ticket left to the feature is taken as the
                ticket's own words have it: the qualified form is `modpath '.' uident`,
                so `Shop.Orders.Order` after `using Shop.Orders` is the same production as
                `Orders.Order`, and `Orders.Order` after `using Shop` is the namespace tier
**Depends on**  F11 (the import tables, the world, `using` resolved to source), F15 (a
                module is a directory), F17 (`--api` as a second declaration pass), F22 (a
                record named in a pattern reads its tag back from the resolved type), F25
                (the corrected signature, whose F25.23 this build overturns)

## What was there

A consumer module could name a producer's record only by spelling the minted tag by hand.
Ticket 73's round 1 measured every position; the last two rows of its table were this feature:

| Position | Example | At `d5ecbc2` |
|---|---|---|
| a second module naming the record | `Go(Circle c)` after `using Shapes` | `error: no type named Circle` |
| the same, qualified | `Go(Shapes.Circle c)` | `syntax error before: '.'` |

`import_env/3` built three tables — functions, namespace shorts, every qualified callee — and
no table of types. `bs_api.erl:6` described that as *"a type NAME does not cross the module
boundary"*, and ticket 16's 2026-08-27 amendment cited the sentence as a ground for refusing
open extension. Ticket 73 withdrew the ground: it was the compiler's behaviour, never a
decision, and with the hand-written tag legal in source (ENG-307 item 3) the hatch was the only
route to a producer's type.

## The program

Ticket 73's, in `examples/Shop/Billing/Billing.bs` with `Shop` as the producer:

```csharp
module Billing

using Orders

public int Due(Order o)
Due(o) -> o.Total

public int Owed(Orders.Order o)
Owed(o) -> o.Total
```

```
$ bsc --src-root . Billing/Billing.bs Due "{ Kind = :'Orders.Order', Id = 1, Total = 7 }"
7
$ bsc --src-root . Billing/Billing.bs Due "{ Kind = :'Orders.Invoice', Id = 1, Total = 7 }"
crashed: error:function_clause
$ bsc --src-root . --api Billing/Billing.bs
module Billing
int Due({ Kind: :'Orders.Order', Id: int, Total: int })
int Owed({ Kind: :'Orders.Order', Id: int, Total: int })
```

The `Invoice` is refused at the door: the type that crossed is the producer's, tag and all,
so F42's boundary guard on `Due` is the one `Orders` would have emitted. `--api` prints the
resolved type and never the name, as F17 always has — the name is now spellable three ways in
the dependent, and the resolved form is the one a caller can rely on.

The four refusals the build adds, each read from `bsc` rather than written from memory:

```
Amb/Amb.bs:4:12: error: Order is ambiguous — 2 imports declare it
  name one of these instead:
    Archive.Order
    Orders.Order
```

```
NoUsing/NoUsing.bs:2:12: error: Orders.Order names Orders, which is never imported
  add `using Orders` — a file's `using` lines are its dependency list,
  and a type that skips them makes that list wrong.
```

```
Receipt/Receipt.bs:3:12: error: Orders declares no type named Receipt
  a qualified type is spelled as the module that declares it spells
  it: a `record` or `type` line in Orders.
```

```
Shop/Billing/Billing.bs:3:12: error: no type named Order
  it is declared elsewhere; bring it in, or name where it lives:
    `using Shop.Orders`, or write `Shop.Orders.Order`
```

The last is owed item 3: `Shop.Billing` wrote `using Shop`, which reaches `Shop.Orders`
without bringing `Order` in unqualified, and the refusal names both repairs.

## What shipped

**The qualified spelling is an ordinary `t_ref` carrying the dotted atom.** `type_prim`
gained `modpath '.' uident` and its bracketed form, producing `{t_ref, 'Orders.Order'}` and
`{t_generic, 'Orders.Box', Args}`. `yecc:file/2` with `{report, true}` measured 0 conflicts
before and 0 after. No new node kind exists, so `scan_ty`, `subst`, `type_source`, `written`,
`member_args` and the emitter's `record_tag` needed no clause — the trap ENG-351 and ENG-355
named, avoided by not adding a kind — and a qualified name prints back through `type_source`
exactly as written, which is what lets a corrected signature name `Orders.Order`.

**The world carries a fourth thing per module: `types`.** `bs_check:types_of/3` resolves the
module's own `record`, `type` and refinement declarations under its imports and hands back the
bare-name table. A ground entry crosses as the resolved algebra map it already is — the tag
was minted where the record was declared, so nothing about the type moves. A parametric entry
is still a template, and its body may name the producer's other declarations, or names the
producer itself imported, by bare spellings that mean nothing in a dependent; `crossing/2`
rewrites those references to the qualified form, which every dependent's environment holds
for every reachable module, and leaves the template's own parameters alone.

**`import_env/4` gains a `types` table and a mode.** A module-tier `using` records each type
name against its source the way `funs` records each function, a collision recorded and not
raised. `strict` refuses a `using` the world cannot resolve, as a compile always has (41 §1);
`lenient` skips it, which is what the declaration pass behind `--api` needs (23 §10).

**`type_env/3` builds the environment with imports beneath the module's own declarations.**
Every reachable module's names under `'Mod.Name'`; a namespace-tier short under
`'Short.Name'`, the full spelling winning the same key so a top-level `Orders` is never hidden
by `using Shop` reaching `Shop.Orders`; a module-tier import's names bare. Resolution order is
41 §2's by merge order — local, then imports — so a local `record Order` sits on top of an
imported one and the bare name has one meaning. A name two imports supply is stored as
`{ambiguous, Mods}` and `resolve/3` refuses it at the use as `ambiguous_type`, so an unused
collision is no error, exactly as for a function. The imported entries are carried into the
result unresolved-again; only the standard environment's and the module's own entries go
through the fold, against an environment that holds the imported ones so a local body may
name them: `type Wide = Orders.Doc | Triangle` resolves.

**`exports_of/2` is the second site.** ENG-320's rule: `--api` is a declaration pass through
`exports_of` and never through `check/2`, so a refusal wired to one prints a collapsed
signature as fact from the other. `exports_of/2` takes the world; `bsc:type_world/2` builds one
for `--api` by reading every module the subject's `using` lines reach, in dependency order,
resolving each producer's types under its own imports, and building nothing. A cycle empties
it, a dependency that exists nowhere is skipped, and a dependency whose declarations do not
resolve is left out. F17.12 still holds.

**The unknown-type refusal is told what the world knows.** `resolve/3` raises
`{unknown_type, N}` with one module's environment in hand; `check_dir/3` and `--api` pass every
raise through `hinted/2` on the way out, which rewrites the three shapes ticket 73 made
possible — a bare name some reachable module declares, a qualified name whose module is
reachable and lacks it, a qualified name whose module no `using` reaches — and walks the
`{at, …}` and `{in_file, …}` wrappers rather than stripping them, so the position `at_loc/2`
attached survives. The tag `unknown_type` does not change when a hint is added; the message
knows more.

**A residual head over an imported record spells the shorter name.** `record_names/1` sees
the record under its bare and its qualified spelling, both minting one tag, and offers the
shortest, which is what the author wrote `using` to be able to write:
`Which(Invoice i) -> ...`.

**The editor grammar.** `qualified_type` in `grammar.js`, in `type_prim` and as a
`generic_type` name, riding the declared GLR conflict on `module_path` exactly as
`qualified_call` does. `check-corpus.sh` reported the ERROR node on `Billing.bs` before and
parses it after.

**The record.** `LANGUAGE.md` §1 gains the paragraph, §6 the sentence that a dependent can
name `Shape` and hand it back but not widen it, §18 the row; the compiler README's table names
`examples/Shop/Billing/`; `bs_api.erl`'s header no longer states the withdrawn ground.

## Four things the build found

**F25.23 was a limitation, not a rule, and the suite said so.** *A residual named in another
module is unspellable, not a defect* pinned that `Tree` from `M29` could not be written in
`M30`. Run whole after the build, the suite went red on exactly that test: the corrected line
now prints `public int | :leaf | (:node, Tree, Tree) Get(int n)` for the dependent exactly as
for the local control, and it compiles pasted back. The test is renamed and asserts the
paste. A decided rule reaches past its examples; the failures are the findings.

**"No dependency read" was a description, not the decision.** Ticket 23 §10's rule for `--api`
is *nothing built*, and F17.12 asserts it as *a dependency that exists nowhere is not needed*.
Reading a producer's declarations keeps both: `type_world/2` parses and resolves, emits
nothing, and skips what is not there. What F17's header actually promised — the resolved type,
never the author's private name — is now the reason the resolved form is printed rather than a
consequence of names not crossing.

**A parametric template does not cross as it is.** `type Box<T> = (T, Meta)` names `Meta`,
the producer's record; handed to a dependent that wrote `using Orders`, the bare name resolves
by accident, and handed to one that wrote `Orders.Box<int>` after `using Shop` it does not.
The first draft crossed the template untouched and the second case was the test that caught
it. Names are rewritten at export, once, to the spelling every environment holds.

**The hint's reach is the invocation's.** `suppliers/2` searches the world, which holds the
modules built so far in this invocation: the dependencies the subject reaches, and anything
named on the command line before it. A module nowhere in that closure cannot be suggested,
because nothing has read it. That is the honest edge: the compiler names the `using` a file
could add from what the build already knows, not from a search of the source tree.

## What is asserted, and where

`type_import_tests.erl`, every test through the CLI with each module in the directory its
`module` line implies:

| Id | Asserts |
|---|---|
| F44.1 | the ticket's program: `Due(Order o)` and `Owed(Orders.Order o)` both answer `7`; an `Invoice` handed to `Due` fails the head with `function_clause` |
| F44.2 | `type Doc = Order \| Invoice` crosses; the dependent's clause heads name `Order` and `Invoice`; a head short of one is refused as `Which(Invoice i)` |
| F44.3 | `Box<T>` whose body names the producer's `Meta` crosses qualified and unqualified, and `m.Note` projects |
| F44.4 | two imports supplying `Order` are refused at the use naming `Orders.Order` and `Archive.Order`; unused, no error; `Orders.Order` disambiguates |
| F44.5 | a local `record Order` wins over the import, and the local's field set is what is checked |
| F44.6 | an unknown bare name a reachable module declares names `using Shop.Orders` and `Shop.Orders.Order`; a qualified name with no `using` says *never imported*; a qualified name the module lacks says *declares no type* |
| F44.7 | `Shop.Orders.Order` after `using Shop.Orders`; `Orders.Order` after `using Shop` |
| F44.8 | naming `Shapes.Shape` and handing it back compiles; `type Wide = Shapes.Shape \| Triangle` handed to `Shapes.Name` is refused at the call naming `Draw.Triangle` (ENG-261's measurement, ticket 16's refusal unmoved) |
| F44.9 | `--api` prints the resolved type for both spellings and never `Due(Order)`; refuses the ambiguous name; still answers with a dependency absent |

`corrected_signature_tests.erl` F25.23: the corrected line for a residual naming another
module's type prints as for a local one, and compiles pasted. `corpus_tests.erl`: the roster
row. `check-examples.sh` and `editor/bin/check-corpus.sh`: `examples/Shop/Billing/`.

## What it leaves

- **The qualified spelling in pattern position.** `Which(Orders.Order o) -> ...` as a clause
  head is a syntax error: the typed binder is `uident lident`, and a record pattern's prefix
  is a bare `uident`. The bare imported name works in both, which is what the ticket's
  program uses. The delta is two productions and no checker change, since `record_tag/2`
  already resolves a dotted `t_ref`. Not decided against; not built here —
  [ENG-363](https://linear.app/davewil/issue/ENG-363).
- **A hint for the hatch spelling in type position** — ticket 73, *Not decided here*.
- **Construction through the raw key** waits on a map literal, as the ticket says.
- **`--api` over a dependency that refuses its own declarations** answers about the subject
  with that dependency left out, so the subject reports an unknown type where a compile would
  report the producer's refusal. Recorded; a query is not the place a producer's defect is
  found.
- **The tour** has no section for this; F42 and F43 set the precedent, and `check-tour.sh`
  part 4 ties an edit to republishing the page.
