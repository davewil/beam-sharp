# 47 — Does `using` get an alias, now that unqualified names are legal?

Type: `wayfinder:decision`
Status: claimed — [ENG-219](https://linear.app/davewil/issue/ENG-219) · round 1 with David, 2026-08-28
Raised by: [ticket 41](41-imports-and-cross-module-scope.md) on resolving it, 2026-08-16
Blocks: nothing — 41 resolved without it

> **The ticket-to-issue arithmetic is dead and this is another data point.** 47 is ENG-219, read
> from Linear rather than computed. 42→212, 43→213, 44→215, 45→216, 46→218, 47→219.

## Question

C# has three import tiers. Ticket 41 §5 settled the first two:

```csharp
using Shop;                  // → Orders.All()   short-qualified   §5
using Shop.Orders;           // → All()          unqualified       §2
using Orders = Shop.Orders;  // → Orders.All()   ALIAS — this ticket
```

**Does the third one exist?**

## Why it is open on new grounds rather than merely un-answered

Ticket 41 parked this deliberately and said why, and the *why* is what makes it a live question
rather than a leftover:

> While the qualified form was on the table an alias was a pure read cost, because the reader had to
> find the alias line; now that unqualified names are legal, an alias is strictly **more** explicit
> than the thing it competes with. That is a different argument from the one that shelved it, so it
> should be re-asked rather than inherited.

The argument that shelved an alias was **read cost** — `List.Fold(…)` sends the reader hunting for
what `List` is bound to. That argument assumed the alternative was a *qualified* name, which carries
its source in the call. §2 changed the alternative: the competing form is now a **bare** `Fold(…)`
brought in unqualified, which carries no source at all.

So the comparison has inverted. Against a bare unqualified name, an alias is the form that says
where the name came from.

## What this ticket owes

1. **Whether the alias exists at all.** It is a tier-1 borrow (C#) and a tier-1 borrow for the
   TypeScript half of the audience too (`import { Fold as ListFold }`), so the design heuristic
   supplies it cheaply — but the heuristic's own amendment says survey all three tiers and take the
   most accurate word, not take the highest tier that fits.
2. **Whether it aliases a module, a function, or both.** C# aliases a type or namespace;
   TypeScript's `as` renames an imported *binding*. §2's import tables are keyed differently for
   each — `{Name, Arity} -> Module` for functions, `Orders -> 'Shop.Orders'` for modules — so this
   decides which table an alias writes into, and whether both.
3. **How it interacts with §2's ambiguity rule.** A name reachable from two sources is an error at
   the call site printing the qualified candidates. An alias is a third source. Does aliasing
   *resolve* an ambiguity (the obvious use — two modules both exporting `Orders`), and if so it is
   not a convenience but the **only** spelling for that program.
4. **Whether the exemplars need it.** They write `List.Fold(…)` and `Orders.All()`. §5's
   short-qualified tier already covers both without an alias, which is why 41 could resolve without
   this. Measure before assuming a need.

## What it does not owe

**Not §2 or §5 reopened.** Unqualified names and the namespace rule are settled. This asks only
whether a *third* spelling joins them.

**Not a renaming rule for anything but imports.** `type X = …` is ticket 09's single naming
construct and is not touched here.

---

# Measurement, 2026-08-28

Two prototypes, both runnable and both green as written:

- [`47a_import_collision_probe.sh`](../prototypes/47a_import_collision_probe.sh) — seventeen
  collision shapes put through `bsc`, each with its verdict **pinned**. The fix belongs to another
  ticket, so 47a records what the compiler does today and goes red if a verdict moves in *either*
  direction.
- [`47b_alias_prior_art.sh`](../prototypes/47b_alias_prior_art.sh) — Elixir and Erlang, compiled and
  run. Ticket 41 recorded that a survey for *"imports, `-import`, aliasing, shadowing or resolution
  order returns nothing measured"*; this is that survey.

## §1 — Item 3's premise is false. An alias is never the only spelling for an ambiguity

This is the claim the ticket rested its "not a convenience" case on, and it does not survive contact
with the compiler.

Every collision **between two imports** already has a legal spelling, and the diagnostic names it:

| shape | program | verdict |
|---|---|---|
| `P1` | two namespaces hold `List`, short name used | error **at the use**, both candidates printed |
| `P1b` | the same two imports, name never used | **compiles** — an unused collision is not an error |
| `P2` | two modules export `Sum/2`, called unqualified | error **at the use**, both candidates printed |
| `P2b` | the same two imports, name never used | **compiles** |
| `P2c` | both colliding modules imported, called in full | **compiles**, returns 3 |
| `P7` | a local `Sum/2` **and** both colliding modules, all three called | **compiles**, returns 6 |

`P2c` is the one that settles it. The diagnostic says *"name one of these in full instead"*, and the
form it recommends works — both colliding modules may be imported side by side and separated at the
call site. `P7` pushes that as far as it goes: a module declaring its own `Sum/2` still reaches
`Alpha.Coll.List.Sum` and `Beta.Coll.List.Sum` in the same expression.

So aliasing would not *resolve* an ambiguity, because nothing needs resolving. Item 3's
"**only** spelling for that program" is not a program that exists.

## §2 — But there is a program with no spelling at all, and it is not an ambiguity

Three shapes close on each other, and a top-level module falls through the gap:

```
module P9

using Solo                              // ← refused: "importing Solo brings in Sum/2,
                                        //    which this module also declares"
public int Sum(list<int> xs, int acc)
Sum(xs, acc) -> acc

public int Go(int n)
Go(n) -> Solo.Sum([n], 0) + Sum([n], 0)
```

Drop the `using` line to escape that refusal, and the qualified call becomes unreachable instead —
41 §1 made a file's `using` lines its dependency list, so `Solo.Sum(…)` without one is
*"called but never imported"* (`P9b`). Split the module across files the way 41 §4 mandates —
`using` in `index.bs`, one function per file — and it makes no difference: the check is
per-**directory**, not per-file (`P11`).

The escape that rescues every other shape is the **namespace tier**. `using Alpha.Coll` writes the
`mods` table and never `funs`, so it brings in no bare names and cannot shadow a local — `P5` is
refused and `P6`, the same clash reached one tier up, compiles. A fully-qualified call is satisfied
by a namespace import of the parent (`P8`).

**A top-level module has no parent namespace, so that escape does not exist for it.** `Solo` cannot
be called from a module that declares `Sum/2`, by any route. This is not an edge case: `Interop`,
`Label`, `Foreign` and `Pipeline` in `compiler/examples/` are all top-level modules.

## §3 — The real gap: `using` picks its table by the callee's layout, not the caller's intent

`P5` and `P6` are the same local, the same callee and the same call. One is refused and one
compiles, and the only difference is **which table the import writes** — `funs` or `mods`. Today
that is chosen by where the callee happens to sit on disk, and the calling module cannot ask for
either.

Elixir says the same thing from the other side. Its `alias` writes module names and its `import`
writes function names, and they are **two constructs** — which is why a local `sum/1` sits beside
`alias A.Coll.List` with no clash at all (`E5`). B#'s single `using` does both jobs and offers no
way to select one.

## §4 — The survey, and the one column B# is alone in

|  | chosen-name alias? | what it aliases | two colliding short names | qualified call needs the import? |
|---|---|---|---|---|
| C# | yes | namespace or type | error | no |
| Elixir | yes (`as:`) | module | **silent shadow**, last wins | no |
| TypeScript | yes (`as`) | binding | error | n/a |
| Erlang | **no** | — (`-import` is functions) | hard error | no |
| **B# today** | **no** | — | error | **yes** |

Three of four have the alias, so the borrow heuristic supplies it cheaply. Two measured surprises:
Elixir's bare `alias` binds the **last path segment** — B#'s namespace-tier rule exactly, derived
rather than chosen — and two colliding bare aliases are a **silent shadow** with no diagnostic
(`E3`). B# is the stricter language here, not the looser one.

The last column is the finding. B# is the only language measured where naming a module *in full*
still requires its `using` line. That is 41 §1 on purpose, and it is what turns the shadow rule into
a lockout none of the other four can reach: everywhere else the alias is pure convenience precisely
*because* qualification is always available without it.

## §5 — What the four owed items now answer to

1. **Does it exist?** — the round below. The survey says yes; the measurement removes every reason
   it was going to be load-bearing.
2. **Module, function, or both?** — **a module**, if it exists at all. That is not a survey
   tiebreak, it is the mechanism: `mods` is the table that binds a chosen name to a module atom, and
   an alias is the consumer selecting that behaviour. Aliasing a *function* would have to be spelled
   `using F = Solo.Sum/2` to key `{Name, Arity}`, which nothing in the survey has and which drags in
   40 §2's arity overloading. Refuse the TypeScript half.
3. **Ambiguity?** — dissolved by §1. It resolves nothing that full qualification does not.
4. **Do the exemplars need it?** — **no.** Four native `using` lines exist in the whole corpus
   (`Shop.Collections.List`, `Shop.Collections` twice, `Shop.Orders`); not one wants a chosen name.
   Everything else is the FFI form.

## §6 — Recommendation

**Refuse the alias, and fix the lockout instead — they are independent, and only one of them is a
defect.**

The lockout in §2 is a bug in what 41 §2 already decided, not a missing feature. §2's sentence is
*"ambiguity **and** local-shadowing to be errors printing qualified candidates"* — one sentence,
both halves, and it specifies no firing point for either. F15 built the ambiguity half as a
**call-site** error (`P2b` compiles) and the shadowing half as an **eager using-line** error (`P10`
is refused even though its only call is the fully-qualified one the diagnostic recommends). Making
the shadow fire where the name is *used* costs no new syntax, no new table key and no new keyword,
and `unqualified_key/4` already consults local `callees` before `funs`, so a bare `Sum(…)` would
unambiguously mean the local.

With that fixed, every program has a spelling, and the alias reverts to what 41 originally called
it: convenience. B# already derives a short name in both module shapes — `Solo.Sum(…)` is short
already, and `using Shop.Collections` gives `List.Sum(…)` — so the alias buys a *chosen* name over a
derived one, for a corpus with four import lines and no collisions in it.

**This resolves against a three-of-four survey, which is worth saying out loud.** C#, Elixir and
TypeScript all have the alias. The reason to decline anyway is the fifth column of §4: in all three
of those languages the alias is convenience layered over a qualification that always works, and in
B# the qualification is the thing that is broken. Fixing the broken thing is not the same as adding
the convenience, and doing the second instead of the first would leave `P9` unspellable in a
language that had just grown a feature for it.

---

## Round 1 — for David, 2026-08-28

Two questions. The first is the decision; the second is the one this session cannot make for you
because it is §2's own wording.

**Q1. Does the alias exist?** The recommendation above is no — decline it, fix the lockout, and
leave the language with two import tiers rather than three.

```
// what you get today, and it is refused
using Solo                       // ← error, because this module declares Sum/2

// what an alias would buy, if it existed
using S = Solo                   // writes `mods` only: S -> 'Solo', no bare names
Go(n) -> S.Sum([n], 0) + Sum([n], 0)
```

The compiler delta for the alias: one grammar arm on `'using' uident '=' modpath` (`'='` already
has a precedence slot, so no new terminal), one write to `mods` and none to `funs`, and the first
author-chosen key ever to enter either table — every key today is derived, `{Name, Arity}` from the
callee's exports and the short name from `strip_prefix/2`. It also owes a re-run of the yecc
conflict check that ticket 41 left standing at `bs_parser.yrl:157-169`, because it is a third arm
discriminated on `=` after a `uident` that `modpath` also accepts.

**Q2. Where should `import_shadows_local` fire?** Moving it to the call site is what unblocks `P9`,
and it makes §2's one sentence fire consistently in both halves. But §2's wording is yours, and it
can be read as having meant the eager check — in which case the lockout wants a different fix, and
the alias becomes the candidate again by default.

```
// under the eager rule (today): refused at the `using` line, no escape for a
// top-level module, even though the only call is the recommended one
using Alpha.Coll.List
public int Sum(list<int> xs, int acc)
Go(n) -> Alpha.Coll.List.Sum([n], 0)      // ← never reached; line 3 already failed

// under a call-site rule: this compiles, and a bare `Sum(...)` means the local
```

Delta: delete the eager raise at `bs_check.erl:416`, and let `unqualified_key/4` report the clash
where the bare name is used. `funs` is already list-valued during resolution, so the machinery for
a deferred report is the one `ambiguous_call` uses.
