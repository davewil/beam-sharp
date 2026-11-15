# 60 — Which modules may name this one?

Type: grilling
Status: **open 2026-08-23** — Backlog
Split from: [22](22-how-opinionated.md), which proposed exactly this and then resolved without it

<!-- ENG-242 -->


## Question

A module controls **what** it exposes. It has no way to say **who** may name it.

`public`/`private` shipped as F12 on 2026-08-17, deciding ticket 40 §3: a signature carries a
visibility marker and private is the default. That is the *what* half. The *who* half has no
spelling, no checker support and, until now, no owner.

Measured at `0b761f6`: `add_module_import/5` reads only the callee's export set
(`bs_check.erl:407-425`), and there is no `internal`, `friend`, `sealed` or `visible_to` anywhere in
the checker.

## Why it split out

Ticket 22 asked *"is this one decision or two?"* about visibility, and answered **two**. The half it
called useful is this one, and 22 said so in its own words: it *"probably is [worth having
independently], in which case it should be split out rather than held hostage here."* It then
resolved on 2026-08-23 without touching it, so the split is now real rather than proposed.

## What 22 established that constrains this

**Do not borrow C#'s `internal` spelling without its semantics.** C#'s `internal` is
assembly-scoped, and beam-sharp has no assembly. F15 makes a **directory** a module, so the natural
unit here is a subtree of the source root, which is not what `internal` means anywhere else. This is
the borrow heuristic's false-friend rule: survey what each language's word already means, and refuse
a word whose meaning is adjacent but wrong.

**Per-function export control is not cheaply available on the BEAM.** Ticket 18 §5 measured that
elision is exported-versus-local with one entry label per function. So a design that wants to hide a
function from *some* callers and not others cannot lean on the emitter to enforce it; it is a
compile-time check on the caller, or it is nothing.

**There is a consumer waiting.** Ticket 24 §2 made the client API the test boundary and used ticket
14's behaviour contract to classify callbacks and client API. What it cannot place is the remainder
— a helper like `RecomputeTotal/1` is neither, and lands `unclassified`. An agent writing tests in a
loop targets `unclassified` functions because they are the easiest thing in the directory to test,
which is structural drift of exactly the kind agent authorship produces.

## What has to be decided

1. **What is the unit?** A directory subtree, a named group, an explicit list of modules, or
   something else. F15 makes the directory the module, so the subtree is the cheap answer and may be
   the right one.
2. **Which direction does the declaration point** — the callee naming who may call it, or the caller
   declaring what it depends on? The second is closer to what `using` already does.
3. **Is it a third visibility marker or a separate construct?** `public`/`private` are on the
   signature. A rule about modules may not belong on a function at all.
4. **What does it cost the checker?** `add_module_import/5` is the site; today it reads the callee's
   export set and nothing else.

## Notes

Not owed a decision soon. It is recorded so that the question has a home, which it did not have
between F12 shipping the *what* half and 22 resolving without the *who* half.

## Round 1 — 2026-11-15

Measured at `258368a` on Erlang/OTP 28.5 (erts 16.4), built from the pinned source, with
`compiler/` unmodified. The probe is [`60a`](../prototypes/60a_who_may_name.sh), and the evidence
is in [research 60](../research/60-which-modules-may-name-this-one.md). The site this ticket
names has moved: `add_module_import/3` is now `bs_check.erl:509-522`, reached from `add_import/7`
at `:495`. Nothing else in the question has changed, and no later ticket decides it.

### The program

`Shop` is the aggregate. Its helper `RecomputeTotal` lives in the sub-module `Shop.Orders`
because one function goes in one file, and it has to be `public` so that `Shop` can call it.
`Warehouse` sits outside the `Shop` subtree and calls the helper directly, which skips the
aggregate.

```csharp
// Shop/Orders/Orders.bs
module Shop.Orders

public int RecomputeTotal(list<int> lines)

RecomputeTotal(lines) -> List.Sum(lines)
```

```csharp
// Shop/shop.bs
module Shop

using Shop.Orders

public int Settle(list<int> lines)

Settle(lines) -> RecomputeTotal(lines)
```

```csharp
// Warehouse/Warehouse.bs
module Warehouse

using Shop.Orders

public int Reprice(list<int> lines)

Reprice(lines) -> RecomputeTotal(lines)
```

**Today both callers compile and run.** `Settle [3, 4]` and `Reprice [3, 4]` each print `7`.
`Reprice` compiles to a plain remote call:

```erlang
'Reprice'(Lines) ->
    'Shop.Orders':'RecomputeTotal'(Lines).
```

The only lever there is today is `private`, and it refuses the aggregate as well:

```
src/Shop/shop.bs:7:18: error: Settle calls RecomputeTotal/1, which Shop.Orders declares `private`
  a private function is not exported, so no other module can
  reach it. Mark it `public` in Shop.Orders, or move the call inside it.
```

The fully qualified call `Shop.Orders.RecomputeTotal(lines)` with no `using` line is already
refused (`Shop.Orders is called but never imported`). So every cross-module reference goes
through `add_import/7`, and that is the single site any check would sit at.

### The question

**Q1. Is `Warehouse`'s call to `Shop.Orders.RecomputeTotal` refused while `Shop`'s own call
compiles: may a module say which modules may name it?**

The unit, which side declares it, and its spelling are this ticket's §1–§3. Each of them follows
from a yes and none is asked here.

### What each answer does

**Under yes**, `Orders.bs` carries one declaration (round 2 decides how it is spelled and what
unit it names). `Shop` compiles, and `Warehouse` is refused at its `using` line:

```
src/Warehouse/Warehouse.bs:3:1: error: Warehouse names Shop.Orders, which only modules under Shop may name
  call what Shop exposes instead, or move Warehouse under Shop.
```

The restriction has to be opt-in, so a module that declares nothing keeps today's meaning. The
corpus already depends on that: the 25a router, outside `Shop`, writes `using Shop.Orders` as
the aggregate's intended API. The compiler gains:

- a `nameable_by` field in each module's `World` entry, built beside `exports` and `private` (`bsc.erl:239`), holding
  the module paths that may name it (absent means any);
- a check in `add_import/7` (`bs_check.erl:495`), before `add_module_import/3` and
  `add_namespace_import/3`, that the importing module `Self` is inside `nameable_by`. A namespace
  import drops the children `Self` may not name, rather than failing;
- a `{not_nameable, Callee, Self, Line}` error and its printer in both diagnostic formats;
- nothing in `bs_emit`. Ticket 18 §5 measured that the BEAM exports to everyone, and the export
  list stays `[{'RecomputeTotal',1}, …]`. Erlang can still call it (probe case 4 does, and gets
  `7`). The check is on B# callers only, and that is the whole of what the language can promise.

**Under no**, the program compiles and runs as it does today, and the compiler gains nothing.
In B#, `public` means public to every module in the source tree. The way to keep a helper
from outside callers is to keep it in the module that calls it, as a `private` file there.
The ticket closes, and a later exemplar that needs a refusal raises a new one with its program
in hand. Ticket 24's `unclassified` helper stays callable, and testable, from anywhere.

### Recommended answer

**No**, because the corpus has no call that ought to be refused. Of 120 `.bs` files, 8 native
`using` lines name another module. 5 of those cross a top-level subtree, and each one names a
module that exists to be called from outside (`Shop.Collections`, `Shop.Orders` from the 25a
router, `Support.Triage`, `Jev`). A yes would build a check that no program yet exercises.
