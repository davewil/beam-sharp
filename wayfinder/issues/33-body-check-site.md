# 33 — Is a function body typed at all, and where does the check run?

Type: grilling
Status: **resolved 2026-08-14** — see [Answer](#answer) at the end.

> **TWO PREMISES IN THIS TICKET WENT STALE BETWEEN RAISING IT AND RESOLVING IT — THREE HOURS.**
> Left in place rather than edited away, per this map's convention, because the pattern is now
> the third of its kind and is worth more than the fact.
>
> **1. "`bs_check` never visits a function body" is no longer true.** It was true at 14:53 when
> this ticket was raised (`6578f1c`). At 16:12 the same day, [F4](../../compiler/features/F4-local-bindings.md)
> landed `scope_diags/1`, `check_scope/5` and `expr_vars/1` (`d7ae664`), and the checker has
> walked every function body since. Its own header comment says so and draws the line this
> ticket must now stand on: *"33 is about whether a body is **typed**, and nothing here asks what
> type anything has."*
>
> **2. The expression inventory is wrong by eight forms.** The Question says the checker reads
> only `e_op`, `e_var`, `e_int` and `e_atom`, inside guards. `expr_vars/1` reads twelve:
> `e_var`, `e_proj`, `e_tuple`, `e_call`, `e_foreign_call`, `e_op`, `e_record`, `e_with`,
> `e_list`, `e_block`, and the two literals.
>
> **What that changes: the check site is already built.** This ticket was framed as *"where does
> a body check run?"* and the honest question left is narrower — *what does the pass that already
> walks every body do beside asking name questions?* The map has now held a stale premise three
> times (the walking skeleton's *"cannot be phrased sharply"*, the boundary manifest's *"no
> exemplars exist"*, and this). All three were **raised before a build and read after one**. The
> rule this suggests: a ticket raised out of a feature carries a timestamp against the compiler,
> and **re-measuring its Question is the first step of resolving it**, not the last.

Raised 2026-08-14 from building [F3](../../compiler/features/F3-records.md). **Two features have
now hit the same missing seam from opposite directions**, which is the bar this map sets for
raising a ticket rather than bolting a pass onto whichever feature notices it second.

## Question

`bs_check` **never visits a function body.** Measured in the source rather than assumed: it
gathers signatures, checks clause-head exhaustiveness against the parameter product, and
translates guards — and the only expression forms it reads are `e_op`, `e_var`, `e_int` and
`e_atom`, read **inside guards only**. `bs_emit` lowers a call straight to an Erlang call with
nothing checked in between.

**A function body is emitted, not typed.**

So: **is a body typed at all — and if so, where does the check run, and what does it do with a
call whose callee is foreign?**

## Why this is a ticket and not a feature

Because it is a decision with more than one defensible answer, and three closed decisions point
at it without settling it.

- [Ticket 04](04-crossclause-exhaustiveness.md) made signatures mandatory, so **every callee's
  type is already declared**. A body check has nothing to infer — it is containment, the same
  relation [ticket 14](14-concurrency-and-otp-model.md) already uses for behaviour callbacks.
- [Ticket 18](18-boundary-defence.md) §4 made the analysis **function-local**, decided by the
  standing constraint: whole-aggregate would let an edit to one file silently move another
  file's boundary. Whatever this ticket decides has to hold that line.
- [Ticket 11](11-type-system-shape.md) says external values arrive as `term` and **the clause
  head is the decoder** — which answers the *entry* direction and says nothing about a call in
  the middle of a body.

## What is waiting on it, concretely

Four items, none of which is speculative — three are scenarios already written down with their
ids reserved rather than deleted.

| Waiting | Which | What it needs |
|---|---|---|
| F3.3's call-site enforcement | ticket 26 §1 | reject `Update(Order o)` called with an `Invoice`. **This is how 26 §1 phrases the requirement David named**, and F3 could not deliver it — F3 establishes aggregate identity *in the algebra* and there is no call site to reject it at |
| F3.8's projection error | ticket 26 §3 | projecting a field only one union member carries should name the member that lacks it |
| F3.10 | ticket 26 §4 | construction must supply exactly the declared field set. **A body can build a map wearing an `Order` tag without `Order`'s fields and nothing rejects it** — the single largest hole F3 shipped with |
| F2's opaque refinements | ticket 20 §5, ticket 29 | barred from clause heads and foreign declarations, permitted elsewhere — and "elsewhere" is a body, which has no check site to hang the obligation on |

Note the shape of the F3 items: **all three are places where the language has already decided a
rule and the compiler cannot enforce it.** That is a different thing from an unimplemented
feature, and it is why F3's own file says a build claiming them "has stopped checking".

## What is already decided — do not re-raise

| Decided | By |
|---|---|
| Signatures are mandatory, so a callee's type is always declared | [04](04-crossclause-exhaustiveness.md) |
| The analysis is **function-local** | [18](18-boundary-defence.md) §4 |
| One relation — plain set-theoretic containment, coinductive | [11](11-type-system-shape.md), [09](09-union-representation.md) |
| A foreign call declared to return a `result` gets a compiler-emitted wrapper; there is **no `try`** in the surface | [15](15-error-model.md) |
| A foreign declaration may promise only what one BEAM guard decides in O(1) | [18](18-boundary-defence.md) §2 |
| Narrowing is **always written, never inferred** | [08](08-head-and-guard-syntax.md) |

So this ticket adds no checking *rule*. It decides whether the rules already agreed are checked
in a body, and where.

## The sub-questions

**1. Is a body typed, or only its calls?** The cheapest answer that discharges the table above is
**argument containment at call sites and nothing else** — every call's arguments checked against
the callee's declared parameter types, plus construction against its declared field set. That
reaches all four rows without a general expression type-checker, and it is worth asking whether
the general version buys anything the map has asked for.

**2. What happens at a foreign call?** [Ticket 32](32-ffi-surface.md) made a foreign declaration a
real emitted function with a signature, so a foreign callee has a declared type like any other
and this may simply not be a special case. Worth confirming rather than assuming — it would be
the second time 32's decision dissolved a question raised before it landed.

**3. Does the check produce a residual, or a yes/no?** Everything else in this compiler answers
with the *set that is left over*, because [ticket 04](04-crossclause-exhaustiveness.md) found the
residual **is** the missing case and [ticket 23](23-what-the-language-owes-an-agent.md) makes it
the thing an agent is handed to write. A call-site failure has no obvious residual, and if the
answer is a yes/no then this is the first diagnostic in the language that does not hand back
something to write — which 23 makes a real cost rather than an aesthetic one.

**4. Does anything change in the emitted code?** [Ticket 18](18-boundary-defence.md) emits a guard
where generated code consumes a value. If a call site is checked statically, that is an argument
for emitting *less*, not more — the inverse of every codegen obligation so far.

## Notes

Blocked by nothing. **Most valuable before F4**, since angle brackets bring `option<T>` fields and
therefore more construction sites, and F3.10 is already unpoliced.

**Do not re-derive the "no inference" position.** Ticket 04 settled mandatory signatures and
ticket 27 §1 turned instantiation into matching rather than solving. This ticket asks where a
check runs, not whether types are inferred.

**Linear**: ticket 33 is **ENG-200, not ENG-199** — the `NN → ENG-(166+NN)` mapping breaks here,
because ENG-199 was taken by F3's feature PRD, which is not a wayfinder ticket. The map's own
instruction is to verify the arithmetic when creating a ticket; this is the first time it has
not held.

---

## Answer

**A body is typed.** Synthesis is total over the twelve expression forms and there was never a
cheaper option; checking is plain containment at **five sites, every one of them a place a type
was already declared**; and **the residual survives at four of the five** — measured, against the
ticket's own assumption that it would not.

The ticket asked three questions and only one of them was open. Sub-question 1's cheap/general
fork **dissolves**, sub-question 2 was **dissolved by ticket 32** exactly as predicted, and
sub-question 4 answers **nothing changes**. Sub-question 3 — residual or yes/no — was the live
one, and it was settled by running the algebra rather than by argument.

### 1. The cheap answer and the general answer are the same answer

The ticket offers *"argument containment at call sites and nothing else"* as the cheap option that
discharges the table without a general expression type-checker. **There is no such saving.** To
check this call:

```csharp
Order Update(Order o)
Update(o) -> o with { Total = 0 }

Order Handle(Doc d)
Handle(d) -> Update(d with { Total = 1 })
```

…the checker must know the type of `d with { Total = 1 }`. That is an `e_with` over an `e_var`.
Check an argument that is a projection and it needs `e_proj`; a constructor and it needs
`e_record`; a nested call and it needs `e_call`. **Typing an arbitrary argument expression *is*
typing an arbitrary expression** — the argument position is not a smaller grammar, it is the whole
one.

And the whole one is small and bounded. `expr_vars/1` already enumerates it, because F4 needed the
same traversal for name questions:

| Form | Its type comes from | Declared? |
|---|---|---|
| `e_int`, `e_atom` | the literal | — |
| `e_var` | the clause's refined domain at the variable's path (§5) | yes |
| `e_call` | the callee's declared **return** | 04 — signatures are mandatory |
| `e_foreign_call` | the `foreign_sig`'s declared return | 32 |
| `e_proj` | the receiver's declared **field** | 26 §1 |
| `e_record` | the declared record type | 26 §1 |
| `e_with` | the base's type, unchanged — `with` is width-preserving | 26 §2 |
| `e_tuple`, `e_list`, `e_block` | their components | structural |
| `e_op` | `int` for arithmetic, `bool` for comparison | 16 §2 |

**Nothing in that column is inferred, and nothing solves.** Every non-structural row reads a type
some other file declared, which is ticket 04's mandatory signature paying for a second thing it was
not bought for. So the general version is a **total twelve-clause function**, not a research
project, and refusing it would buy nothing — you would write eleven of the twelve clauses anyway
and call the result a special case.

**This is why sub-question 1 was the wrong cut.** The two things it conflated are:

- **Synthesis** — every expression gets a type. Total, unavoidable, twelve clauses.
- **Obligation** — where containment is *checked* and a diagnostic raised. A fixed list.

The decision is entirely in the second, and the map had already made it.

### 2. The five obligation sites, and why there is no sixth

A check runs **wherever a declared type meets a synthesised one**. That is not a design choice
with alternatives; it is the enumeration of the places this language writes a type down.

| # | Site | B# | Relation |
|---|---|---|---|
| 1 | **Call argument** | `Update(d)` | `type_of(d) ⊆ Order` |
| 2 | **Construction** | `Order{ Id = 1 }` | supplied field set **=** declared field set |
| 3 | **Projection** | `d.Total` | every member of `type_of(d)` carries `Total` |
| 4 | **Clause return** | `Order Update(...)` | `type_of(body) ⊆ Order` |
| 5 | **Destructuring bind** | `(a, b) = pair` | `type_of(pair) \ type_of(pattern)` is empty |

Site 1 covers foreign calls too — see §6. **Site 4 is not in the ticket's table and is forced by
[ticket 18](18-boundary-defence.md)'s own criticism of Gleam**: 13 emits a `-spec` for every
function, and 18 measured Gleam *"trusts its `@external` and publishes the false claim as a
`-spec`"* — `-> Int` returning `41.5`. Without a return check beam-sharp publishes exactly the same
unverified claim from its own bodies rather than from an FFI declaration, which is the same defect
with a shorter blast radius. **Site 5 is [ticket 34](34-local-bindings.md)'s deferred destructuring
bind**, which that ticket routed here with the mechanism already named.

**There is no sixth site because there is no sixth place a type is written.** `e_op`, `e_tuple`,
`e_list` and `e_block` declare nothing, so they synthesise and never check.

### 3. The residual survives — measured

The ticket's sub-question 3 asserts *"a call-site failure has no obvious residual"* and prices that
against [ticket 23](23-what-the-language-owes-an-agent.md). **The assertion is false.** Run the
shipped algebra over F3.3's own records — `bs_types:subtract/2` and `bs_types:to_pattern/1`, the
two functions that already produce ticket 04's residual, with nothing added:

| Site | Query | `to_pattern` of the residual |
|---|---|---|
| Call argument | `Doc \ Order` | `{ Kind: :'Shop.Invoice' }` |
| Projection | `(Order \| Note) \ { Total: term }` | `{ Kind: :'Shop.Note' }` |
| Construction | `Order{Id} \ Order` | `{ Kind: :'Shop.Order' }` ← **useless** |

Two of the three hand back **a clause head**, produced by the same printer that formats an
exhaustiveness residual. So:

- **The call-site residual is the clause the caller must write.** `Handle` is handed
  `Handle({ Kind: :'Shop.Invoice' }) -> …`, which is 04's guarantee at a second site and 23's
  synthesised head reaching a construct nobody built it for. **It proposes an edit to the function
  being checked, never to the callee** — forced by 18 §4's function-local rule, which is what stops
  the diagnostic from suggesting you widen `Update`.
- **The projection residual names the member that lacks the field**, which is precisely the
  sentence F3.8 deferred: *"an error naming the member that lacks it, with the fix being to
  discriminate on the tag first."* The residual **is** the tag to discriminate on. F3.8's deferred
  half needs no new machinery at all.

**So the language does not acquire its first empty-handed diagnostic.** 23's cost does not fall
due, and the uniformity that made the compiler an interlocutor holds at every site but one.

### 4. Construction is the exception, and it is honest about it

`Order{ Id = 1 } \ Order` returns `{ Kind: :'Shop.Order' }` — it names **the type you were
building**, not the field you forgot. The subtraction is correct and the diagnostic is worthless,
because two closed maps over different key sets are simply disjoint; the algebra has no way to say
*"this, but short a field"*.

Containment still **catches** it in both directions — measured, `Order{Id}` is not a subtype of
`Order`, and neither is a record carrying an extra field — so **F3.10 closes on soundness
regardless**. What construction needs is a different *residual*: the **field-name difference**,
`declared \ supplied` and `supplied \ declared`, computed on the map member's key set rather than
on the type. That still hands back something to write (`Total = …`), so 23 is satisfied in
substance; it is the one site where the thing subtracted is names rather than values, and saying
so plainly is better than pretending one operation covers five sites.

### 5. A body variable's type is read off the clause's refined domain, not off its pattern

**This is the finding whoever builds it must not get backwards**, and the checker already contains
both the trap and the escape.

`pattern_type({p_var, …})` returns `bs_types:term()` — correct, since a bare variable matches
everything. So in `Update(Order o)`, the *pattern* says `o : term`, and `term ⊄ Order`. Type a body
from its patterns and **every argument fails every call site**. The declared type must be
intersected back in.

Which one? `clause_type/2` already returns the pair — and **`Certain` is the wrong half**:

```csharp
atom Classify(int n)
Classify(n) when Weird(n) -> :odd
Classify(n)               -> :other
```

`Weird` is a user function, so `alternatives/1` answers `unknown` and `apply_guard/3` returns
`{none, Ty}` (`bs_check.erl:355`). Clause 1's `Certain` is **`none`**. Typing its body against
`Certain` gives `n : none` — a value that cannot exist — inside a body that runs. `Possible` gives
`int`, which is what actually reaches it.

`Certain` is *what may be subtracted from the residual*; `Possible` is *what may reach the body*.
The comment at `walk/5` already draws that line for soundness in the other direction, and this is
the same split load-bearing a second time.

**And `walk/5` is already carrying the exact value the body needs.** The domain is the **running
residual** intersected with `Possible` — so an earlier clause narrows a later body for free:

```csharp
atom F(int n)
F(0) -> :zero
F(n) -> :other      // n : int \ 0, because clause 1 already took 0
```

Measured over the shipped algebra rather than reasoned about, because **the two clauses take their
narrowing from different halves of the intersection** and a reader implementing this from one
sentence could reach for the wrong half:

```
clause 1 domain:            (0)                        <- from the PATTERN, via Possible
residual after clause 1:    (int <= -1 | int >= 1)
clause 2 domain:            (int <= -1 | int >= 1)     <- from the RESIDUAL
clause 2 without residual:  (int)                      <- control
domain from Certain = none: none                       <- the trap above, confirmed
```

The control is the load-bearing row: intersecting the *declared* type with the pattern gives clause
2 a bare `int`, so the narrowing in a later body is genuinely the residual's contribution and not
the pattern's. That is 08's *narrowing is always written* falling out with nothing written — **the
earlier clause head is the narrowing** — and it means the body check is **not a second pass over
the AST**, but `walk/5` keeping a value it currently computes and discards.

### 6. Foreign calls are not a special case — ticket 32 dissolved it, confirmed

[Ticket 32](32-ffi-surface.md) made a foreign declaration a signature (`foreign_sig`) attached to
the name Erlang already has, and the parser emits `e_foreign_call` as a distinct node. A foreign
callee therefore has declared parameter and return types like any other callee, and site 1 applies
verbatim.

**How far the declared return is trusted was decided by 18 §2, not here**: a foreign declaration may
promise only what one BEAM guard decides in O(1), and anything wider crosses as `term` plus
`ValidateAs<T>`. The body check trusts the declaration exactly that far and no further, which is
where 18 already put the line. **This is the second question ticket 32 dissolved before it was
asked**, as this ticket predicted.

One real delta rather than a rule: `collect/1` **deliberately excludes** foreign declarations, with
a comment explaining that a foreign declaration is finished rather than unfinished and would
otherwise report `no_clauses`. That exclusion is right for clause checking and wrong for a callee
environment, so the callee env is built from `{signature, …}` **and** `{foreign, …}` both.

### 7. Nothing changes in the emitted code

Sub-question 4 supposes a static call-site check argues for emitting *less*. It does not, and the
reason is already decided twice over.

18's guards sit at **entries** — where a foreign term becomes a typed value. The body check is
**function-local** (18 §4) and [ticket 21](21-escape-hatch-precedents.md) rules out ruling out a
foreign caller, so proving something about *this body* discharges no obligation about *who calls
the exported function*. The remaining route is closed by 18's own structural finding: **elision is
exported-vs-local, not local-call vs remote-call**, since a BEAM function has one entry label — so
there is no guarded-public/unguarded-internal pair to split.

Nor does it relax F3.9's second tier. The exact-set guard is emitted where a codegen obligation
consumes a record; a record reaching that point may have arrived through a parameter rather than
been built in the same body, so the static proof does not cover the consuming site.

**Net: the body check adds no emission and removes none.** It is the first checking capability in
the language that is purely a frontend concern, and that is worth stating because every previous
one arrived as a codegen obligation.

### The compiler delta

Stated against the shipped source, so the feature that implements it has nothing to design:

```erlang
%% NEW. The whole of it — total over the twelve forms of §1.
-type scope() :: #{atom() => bs_types:ty()}.
-spec type_of(expr(), scope(), env()) -> bs_types:ty().

%% NEW. The read-only twin of refine_at/3, which already descends these paths.
%% Needed because pattern_type/3 records where each variable sits and nothing
%% currently reads a component back out.
-spec at_path(bs_types:ty(), path()) -> bs_types:ty().

%% NEW. Site 2's residual is field names, not a type — §4.
-spec field_delta(Supplied :: [atom()], Declared :: [atom()]) ->
          {Missing :: [atom()], Extra :: [atom()]}.

%% CHANGED. walk/5 already computes the body's domain and throws it away.
walk([C | Rest], Residual, Env, Diags, N) ->
    {Certain, Possible} = clause_type(C, Env),
    Domain = bs_types:intersect(Residual, Possible),      %% NEW — from what is already here
    Diags1 = body_diags(C, Domain, Env) ++ Diags,         %% NEW
    walk(Rest, bs_types:subtract(Residual, Certain), Env, Diags1, N + 1).

%% CHANGED. collect/1 excludes foreign declarations by design (§6); a callee
%% environment needs both kinds.
-spec callees([decl()]) -> #{atom() => {Params :: [bs_types:ty()], Ret :: bs_types:ty()}}.
```

Five diagnostics, four of them carrying a type the existing printer renders as a clause head:

```erlang
{arg_not_accepted,   Callee, Position, Residual}   %% site 1
{field_set_mismatch, Record, Missing, Extra}       %% site 2 — names, not a type
{field_absent,       Field,  Residual}             %% site 3
{return_not_declared, Residual}                    %% site 4
{bind_may_fail,      Residual}                     %% site 5
```

**Nothing new in `bs_types`.** `subtract/2`, `intersect/2`, `is_subtype/2` and `to_pattern/1` are
all shipped and all exercised above.

### What this discharges

| Waiting | Closes at | Note |
|---|---|---|
| F3.3's call-site enforcement (26 §1) | site 1 | residual is the caller's clause head |
| F3.8's projection error (26 §3) | site 3 | residual **is** the member lacking the field |
| F3.10 construction (26 §4) | site 2 | sound at once; diagnostic needs `field_delta` |
| F2's opaque refinements (20 §5, 29) | site 4 | *"permitted elsewhere"* now has a check site |
| 34's destructuring binds | site 5 | provably irrefutable ⇔ residual empty |

### What this does not decide

- **Interval arithmetic on `e_op`.** `1 + 2` synthesises `int`, not `range(3,3)`. Exact interval
  arithmetic is [F2](../../compiler/features/F2-interval-refinements.md)'s business and pulling it
  in here would be F2 leaking into a feature that is not waiting on F2's two owed decisions.
- **Where it is built.** Built 2026-08-14 as [F5](../../compiler/features/F5-body-check-site.md):
  all five sites, 106 tests. The delta above held; the site enumeration was complete; and the one
  thing this ticket did not find was that a **list element has no address**, so reading a body
  variable off the domain answers `term` for it and rejects a shipped example. That is not a
  question about where a check runs, which is why measuring the sites could not surface it. It is a
  feature, not more of this ticket, and it went **before angle brackets**: `option<T>` fields multiply construction sites, and site 2 is the hole F3 shipped
  with. The ticket's original note said *"most valuable before F4"*; F4 landed first and changed
  nothing about the argument except which feature it names.
- **Nothing was left for David to arbitrate.** Three sub-questions closed on mechanism and the
  fourth closed on a measurement, which is the map refusing on mechanism rather than on taste.

## Decisions entry

<!-- This ticket's entry. wayfinder/decisions.md is GENERATED from blocks like this
     one and carries only the first sentence; the whole entry is read here. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- [The body check site](issues/33-body-check-site.md) — **a body is typed; synthesis is total and
  there was never a cheaper option; checking is containment at five sites; and the residual
  survives at four of them.** Resolved 2026-08-14, three hours after being raised, and **two of its
  own premises had already gone stale in that time** — F4's scope pass made *"`bs_check` never
  visits a function body"* false at 16:12, and the Question's expression inventory was short by
  eight forms. **That is the map's third stale premise**, after the walking skeleton's *"cannot be
  phrased sharply"* and the boundary manifest's *"no exemplars exist"*, and all three were **raised
  before a build and read after one**; the rule extracted is that re-measuring a feature-raised
  ticket's Question is the *first* step of resolving it. **The ticket's cheap/general fork
  dissolves**: checking a call argument requires typing an arbitrary expression, because the
  argument position is not a smaller grammar — so the "cheap" option is eleven-twelfths of the
  general one with a different name. What the fork was really hiding is a split the ticket never
  made: **synthesis** (every expression gets a type — total, twelve clauses, every non-structural
  one reading a type another file *declared*, which is 04's mandatory signature paying for a second
  thing) versus **obligation** (where containment is checked). The obligation sites are the
  enumeration of the places this language writes a type down: **call argument, construction,
  projection, clause return, destructuring bind** — five, with no sixth because `e_op`, `e_tuple`,
  `e_list` and `e_block` declare nothing. Two of those were not in the ticket's table: **the return
  check is forced by 18's own criticism of Gleam** (13 emits a `-spec` for every function, and
  without it beam-sharp publishes an unverified claim from its own bodies exactly as Gleam does
  from its FFI), and **site 5 is 34's deferred destructuring bind**. **Sub-question 3 was settled by
  running the algebra rather than by argument, and its assumption was wrong**: `subtract/2` +
  `to_pattern/1` — the two functions that already print 04's residual — return
  `{ Kind: :'Shop.Invoice' }` at a call site and `{ Kind: :'Shop.Note' }` at a projection, so **the
  call-site residual is the clause the caller must write** and **the projection residual is
  literally the member lacking the field**, which is F3.8's deferred sentence needing no machinery.
  So 23's cost never falls due and the language gains no empty-handed diagnostic. **Construction is
  the one exception and is recorded as one**: two closed maps over different key sets are disjoint,
  so the residual names the type you were building rather than the field you forgot — containment
  still catches it in both directions (measured: neither a short record nor a wide one is a
  subtype), and the diagnostic takes a **field-name difference** instead. **The finding a builder
  must not get backwards**: a body variable's type is read off the clause's refined domain at the
  path `pattern_type/3` already records, *not* off its pattern — a bare `p_var` is `term`, so
  without the intersection every argument fails every call site — and it must intersect
  **`Possible`, never `Certain`**, since an untranslatable guard makes `Certain` `none` and would
  type a running body's variable as a value that cannot exist. `walk/5` already computes that
  domain (running residual ∩ `Possible`) and discards it, so **the body check is not a second pass
  and an earlier clause narrows a later body for free** — 08's *narrowing is always written* falling
  out with nothing written. **Measured, because the two halves of that intersection do the work in
  different clauses**: over `F(0) -> …` / `F(n) -> …`, clause 1's body gets `(0)` from the *pattern*
  and clause 2's gets `(int <= -1 | int >= 1)` from the *residual*, where intersecting the declared
  type with the pattern alone leaves clause 2 a bare `(int)`. **Ticket 32 dissolved sub-question 2 exactly as predicted** (a foreign
  callee has a declared signature; how far it is trusted was decided by 18 §2), leaving one
  mechanical delta: `collect/1` excludes foreign declarations by design, and a callee environment
  needs both kinds. **Sub-question 4 answers *nothing changes in the emitted code*** — 18's guards
  sit at entries, the analysis is function-local (18 §4), and 21 rules out ruling out a foreign
  caller, so no proof about a body discharges an obligation about a caller; 18's *elision is
  exported-vs-local* closes the last route. **This is therefore the first checking capability in
  the language that is purely a frontend concern**, where every previous one arrived as a codegen
  obligation. Nothing new is needed in `bs_types`. **BUILT the same day as
  [F5](../compiler/features/F5-body-check-site.md)** — all five sites, 106 tests up from 79, and
  F3's three reserved scenarios now asserted rather than reserved. The delta held and the site
  enumeration was complete; **what the ticket could not have found is that a list element has no
  address**, so reading a body variable off the domain answers `term` for it and rejects
  `examples/fib.bs` — reverting that fix turns 7 of 106 tests red. Measuring *where a check runs*
  cannot surface a question about *whether the checker can address the value it is checking*, which
  is a different axis from the one this ticket was framed on. Both of §5's traps were confirmed by
  **mutating the source rather than by a green suite**: built with `Certain`, the compiler goes
  quieter rather than broken (1 test red), which is why the scenario has to assert an error a wrong
  build **omits**. F5 shipped one hole named rather than discovered — a field's assigned **value**
  is unchecked at construction and at `with` alike, because §2's relation is the field *set* and §1's
  principle says otherwise → [ticket 36](issues/36-field-value-obligations.md).

  **[Ticket 36](issues/36-field-value-obligations.md) closed that hole on 2026-08-21, and closed it
  without a sixth site.** The answer is **yes to both**, and the reason there is no asymmetry to
  weigh is that **site 2 is not "construction" — it is *field assignment***, of which `Order{ … }`
  and `o with { … }` are two spellings meeting **one** declaration. §2's closing sentence was never
  about `with`: its own justification clause enumerates the forms that declare nothing — `e_op`,
  `e_tuple`, `e_list`, `e_block` — and `e_with` is not among them, because `Total: int` is written
  in the record declaration and governs both spellings alike. The ticket's case for a sixth site
  rested on §1's `e_with` row (*"the base's type, unchanged"*), which is a **synthesis** row; using
  it to settle an obligation is precisely the conflation §1 was written to break. **So §2's closing
  sentence stands unamended and §2's site-2 *relation* widens**: supplied field set = declared field
  set, **and** each supplied value is contained in that field's declared type. **What the ticket got
  wrong is its own scope fence.** It forbade re-deriving the name half — *"F5 enforces it"* — and F5
  enforces it **at construction only**: `o with { Nope = 1 }` compiled clean, emitted Erlang's `:=`,
  and raised `{badkey,'Nope'}` at **run time**, so 26 §2's width-preservation was being delivered by
  the BEAM rather than by the compiler. Three defects, not two. **The strongest evidence was already
  in the emitted code**: `bsc` writes a `-spec` declaring the field type and a body violating it in
  the same file, and **Dialyzer names both halves with one verdict** — *"the return types do not
  overlap"* — which is 18's criticism of Gleam turned inward, the very argument §2 used to add site
  4. Gleam 1.18.1, measured rather than cited, rejects construction and update with two identical
  errors and draws no line between them. **One verdict this corrects rather than extends**: §3
  marked construction's residual *useless*, and that was the **name** residual; the **value**
  residual is `type_of(:oops) \ int` = `:oops`, precise beside a known field name — so the one site
  §3 recorded as unable to hand an agent anything writable can do so on its value arm, which
  strengthens 23. The delta grew in scope but not in kind — containment against `declared_fields/1`,
  **nothing new in `bs_types`** — and the name arm needs no new diagnostic, since
  `field_set_mismatch` already carries an `Extra` list whose prose reads *"not declared by Order"*;
  only its headline verb was wrong, because `with` updates rather than builds. Built as
  [F21](../compiler/features/F21-field-value-obligations.md).
```
