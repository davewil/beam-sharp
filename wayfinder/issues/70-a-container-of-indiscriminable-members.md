# 70 — A container whose elements no clause head can tell apart

Type: grilling
Status: claimed — raised 2026-09-07 as [ENG-334](https://linear.app/davewil/issue/ENG-334),
taken 2026-09-09
Blocked by: —

## Why this is raised now

F36 built [ticket 68](68-an-absorbed-member.md) and filed this instead of answering it, because a
feature that needs a decision raises a ticket rather than making one. **It under-refuses**, so
nothing legal breaks and no program changes meaning. What is wrong is that a shipped sentence in
`LANGUAGE.md` §7 claims more than the compiler holds.

## Measured 2026-09-09 at `e661b30`, run rather than inferred

```csharp
type T = map<string, int> | map<string, binary>                    // REFUSED
type T = list<map<string, int>> | list<map<string, binary>>        // compiles
type T = (:a, map<string, int>) | (:a, map<string, binary>)        // compiles
type T = list<int> | list<binary>                                  // compiles, and 09 §4 says it should
```

The second and third hold exactly the members the first is refused for, one container level in.
The refusal on the first reads:

```
error: no clause head can tell `map<string, int>` from `map<string, binary>`
  in T
  both members survive normalisation, so neither is absorbed - but
  no pattern reaches either one and no guard separates them, so a
  value of this type can be passed and returned and never matched.
```

`discriminable/4` (`bs_check.erl`) accepts a pair when **either** constituent has a pattern that
*reaches* it, without asking whether that pattern *separates* the two. `list<map<…>>` has a spine
pattern — `[]`, `[m, ..]` — so it reaches; but `[m, ..]` binds a domain map either way and no guard
tells the two apart, which is the very thing the bare pair is refused for.

## Two wordings, both on 68's record, and they diverge here

| Where | Wording |
|---|---|
| 68's header, and line 251 | *"the criterion is **reachability** by a clause head, pattern or guard"* |
| 68 Q2's answer (David, 2026-09-06) | *"Discriminable means a clause head can **decide** it — pattern or guard"* |
| `LANGUAGE.md` §7, shipped | *"If **no clause head** — pattern or guard — can **distinguish** two of its members"* |
| today's diagnostic | *"no pattern **reaches** either one and no guard **separates** them"* |

They agree everywhere except where a container's element type is itself indiscriminable, and 68's
worked examples do not reach that case. §7's own justification for `list<int> | list<binary>` — *"a
guard on that binding decides which member the value came from"* — is false when the element is a
domain map.

## Round 1 — asked 2026-09-09

**Q1. This compiles today. Should it?**

```csharp
type Slot  = map<string, int> | map<string, binary>               // refused today
type Slots = list<map<string, int>> | list<map<string, binary>>   // compiles today
```

`Slots` is `Slot` inside a list. A clause head can reach an element of `Slots` — `[m, ..t]` binds
one — and cannot decide which member it came from, because that is what `Slot`'s refusal says.
Answer **refuse it** or **leave it**.

**What the compiler gains if it is refused.** `discriminable/4` recurses into container elements
and bottoms out at *"the elements are discriminable"* rather than at *"the elements have
patterns"*, so `list<int> | list<binary>` stays legal — 09 §4's own accepted example. The recursion
needs the same `mu` guard F36 added to `head_parts/2`. It decides more programs illegal, so it owes
a blast-radius measurement over `compiler/examples` before it lands. `LANGUAGE.md` §7 then says
what the compiler holds; today it says more.

**If it is left**, §7's sentence and `CONTEXT.md`'s **Discriminable** entry are rewritten to
*reaches*, F36's known-limit note becomes the permanent record, and the divergence stops being a
defect.

## Decisions entry

_Written on resolution._
