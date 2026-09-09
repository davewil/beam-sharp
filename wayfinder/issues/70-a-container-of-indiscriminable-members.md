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

**Rewritten twice before it was answered, both times by David, both times because the program was
not one anybody would write.** First framing: the type declarations plus a body returning an atom —
*"the Rows example is weak … what if the return type is something more complex and m and t are
accessed?"* Second: a `Head` returning the binding — *"what would an actual piece of real production
code be trying to achieve?"* Both fair. A hand-written union of two map types is a shape nobody
writes. The program below is how an author actually arrives here.

### How you get here without ever writing a map union

A generic row alias, instantiated twice, unioned for one handler. This is ordinary code:

```csharp
module Ingest

type Batch<T> = list<map<string, T>>          // a batch of rows, keys are field names
type Payload  = Batch<int> | Batch<binary>    // numeric samples, or text ones

public atom Route(Payload p)
Route([])            -> :empty
Route([row, ..rest]) -> Forward(row)

private atom Forward(map<string, int> row)
Forward(row) -> :forwarded
```

**The declaration is accepted.** The refusal arrives later, at the call site, and names a different
function:

> `Ingest.bs:8:25: error: Route hands Forward an argument it does not accept`
> `  argument 1 is not covered by Forward's declared type:`
> `    map<string, binary>`

Widening `Forward` to the honest type is the refused declaration — that type is `Cell` below. And
`Head`-shaped variants get there via F25 instead, which **prints `map<string, int> | map<string,
binary>` as the signature to paste and then refuses that exact line.**

### The same alias, one level down, is stopped at the declaration

```csharp
type Cell<T> = map<string, T>
type Any     = Cell<int> | Cell<binary>
```
> `error: no clause head can tell `map<string, int>` from `map<string, binary>``
> `  in Any`
> `  … it lifts when a pattern form for these members ships.`

**`Payload` is `Any` inside a list.** One is refused where the author declared it, with the reason;
the other is admitted and refused later, somewhere else, about something else.

### What the language actually wants, and it compiles clean today

```csharp
type Payload = (:nums, Batch<int>) | (:text, Batch<binary>)

public atom Route(Payload p)
Route((:nums, rows)) -> Numeric(rows)
Route((:text, rows)) -> Textual(rows)
```
> `[api] atom Route((:nums, list<map<string, int>>) | (:text, list<map<string, binary>>))`

Tag the two instantiations and everything works — each arm dispatches, each stage is declared over
its own row type. **This is the repair under either answer.** Nothing about it is a workaround: it
is what a discriminated union looks like when the members are not self-discriminating, and 09 §5's
last bullet already says so — *"two cases with the same payload need a tag, and the leading atom in
a tuple already is one."*

### The boundary construct compiles, does the work, and throws the answer away

Measured 2026-09-09 at `ea7f896`, while David was weighing the TypeScript-shaped answer. TS needs
an escape hatch — a type predicate, `pet is Fish` — because its narrowing is a closed catalogue of
syntactic forms and you cannot add a discriminant to a type you do not own. **B# already has the
sound version of that hatch**: `ValidateAs<T>` (F18) does the same job at the boundary, and the
compiler *generates* the traversal, so the witness cannot be a lie.

It does not rescue this union:

```csharp
public result<Payload, ValidationError> Decode(term t)
Decode(t) -> ValidateAs<Payload>(t)          // COMPILES
```

The generated validator walks the term, decides at run time which member arrived — and hands back a
`Payload`, **a type with nowhere to record the answer.** It knows, and the knowledge is discarded,
because the union carries no tag. The author pays O(n) and is returned to the same box.

`ValidateAs<Any>` — the same thing one container level down — is **refused**, consistently with
`Any`'s declaration. `ValidateAs<(:nums, Batch<int>) | (:text, Batch<binary>)>` compiles and hands
back a value that dispatches.

So the escape hatch is not the deciding factor either way: **the TypeScript-shaped answer does not
import TypeScript's unsoundness**, because the case TS needs an unchecked predicate for is the case
B# routes through a generated, checked one. What it does mean is that under *leave it*, the
boundary construct is a second place the author can reach this union and get no help.

### The printed-repair contradiction is NOT this ticket's, measured 2026-09-09

Put in front of David as a separate fact, because it changes what Q1 is asking. **No container, no
generic alias, no union declared anywhere:**

```csharp
public map<string, int> Pick(int n)
Pick(1) -> Ints()          // private map<string, int> Ints()
Pick(n) -> Bins()          // private map<string, binary> Bins()
```
> `error: Pick returns a value its signature does not declare`
> `  not covered by the declared return type:`
> `    map<string, binary>`
> `  the signature its clauses justify:`
> `    public map<string, int> | map<string, binary> Pick(int n)`

That printed signature is refused by the declaration checker. **F25 recommends a form the compiler
rejects, today, at `ea7f896`, with ticket 70 not involved at all.** It is the F19 shape a third
time — *before trusting a refusal, run the form it recommends* — and it is a defect in its own
right, owed its own Linear issue rather than this ticket's number.

It is recorded here because **it is repaired under every answer to Q1**, and because both of this
round's earlier framings leaned on it as though it were evidence for refusing the declaration. It
is not. It is evidence that one diagnostic is wrong.

### Q1. Where should the author be told?

**Correction to this round's own earlier wording.** It said *"both answers agree the program is
wrong"*. Under *leave it* the **declaration is not wrong** — `Payload` names a real set of values,
and every one of them can be built, passed and returned. What is wrong is expecting to dispatch on
it, and what is broken is the advice the compiler gives when you try. That distinction is what the
third option below turns on.

**Option A — leave it, and stop the compiler contradicting itself.** The criterion stays
*reachability*, which is what 68's header settled and what `discriminable/4` implements. No checker
change, and nothing that compiles today stops compiling. Two diagnostic sites are repaired instead:

* **F25 runs the declaration check before it prints.** Where the signature the clauses justify
  would itself be refused, the diagnostic says *that*, and names the repair that does work —
  tagging — instead of printing a line the compiler will reject.
* **`ValidateAs<T>` refuses a target whose members it cannot report having distinguished.** It
  already refuses `Any` through the declaration check; the same predicate applied to the generated
  validator's target type makes the boundary consistent with itself. Two sites to wire, not one —
  `--api` is a second declaration pass ([ENG-320](https://linear.app/davewil/issue/ENG-320)'s
  sentence, for the fourth time).

**Option B — leave it, prose only.** As above without the two repairs: §7 and `CONTEXT.md` are
rewritten to reachability and the contradictions stay, documented. Cheapest, and the one that gets
re-opened.

**Option C — refuse it at the declaration.** `discriminable/4` recurses into container elements,
bottoming out at *"the elements are discriminable"* so `list<int> | list<binary>` stays legal, with
F36's `mu` guard on the recursion. **This is the option that re-decides 68.** Its header settled
*"reachability by a clause head"* on 2026-09-06 and F36 shipped the next day; taking C means
reading David's *"a clause head can decide it"* as overruling the record's own word, on a case 68's
worked examples never exercised. Owes a blast-radius run over `compiler/examples` first.

Under **A** and **B** the first stop stays the call site. Under **C** it moves to the declaration.
Under **A** and **C** the compiler stops recommending a form it refuses; under **B** it does not.

**Prior art, surveyed 2026-09-09** — [research 70](../research/70-discriminability-prior-art.md).
**Nobody else is asked this question**, so *"what does everyone else do"* is not a tiebreak: Elm and
Gleam are nominal and cannot write the union at all, and ticket 09 §5 refused that escape here
because nominal identity is a lie across the Erlang boundary; TypeScript forms unions exactly as B#
does and answers *leave it* — narrowing simply does not happen — but pairs it with a type predicate
whose body is never checked, which B# has refused; Elixir's algebra is the same family and ships
**redundancy only**, so nothing there ever has to decide; CDuce's patterns type-test at arbitrary
depth, so the members are discriminable in the theory B# borrowed from — **carried from research
04's reading of the CDuce manual, not run here**, and it describes CDuce's pattern *forms* rather
than what its checker does with an unmatchable union. The constraint is the
**BEAM's O(1) guard**, chosen by 09, not set theory's.

<!-- The same shape as the F19 finding: before trusting a refusal, run the form it RECOMMENDS.
     Here the recommended form is refused by a different check in the same compiler. -->

## Decisions entry

_Written on resolution._
