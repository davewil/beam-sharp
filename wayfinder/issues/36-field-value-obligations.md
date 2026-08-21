# 36 — Is the value assigned to a field checked, and is `with` a sixth site?

Type: grilling
Status: **resolved 2026-08-21** — [ENG-203](https://linear.app/davewil/issue/ENG-203). Yes to both,
and neither is a sixth site: see [Answer](#answer--resolved-2026-08-21) at the end. Raised
2026-08-14 from building [F5](../../compiler/features/F5-body-check-site.md).

## Question

F5 built [ticket 33](33-body-check-site.md)'s five obligation sites. Two expressions now type-check
that plainly should not:

```csharp
record Order { Id: int, Total: int }

Order Make(int n)
Make(n) -> Order{ Id = :oops, Total = n }      // compiles

Order Bump(Order o)
Bump(o) -> o with { Total = :oops }            // compiles
```

`Id: int` is a **declared type**, and `:oops` is a synthesised one meeting it. So: **is a field
assignment a check site — at construction, at `with`, or at neither?**

## Why this is a ticket and not more of F5

Because ticket 33 answered a question adjacent to this one and the two answers point different
ways, which is the bar this map sets.

- 33 §1's **principle** is *"a check runs wherever a declared type meets a synthesised one"*, and a
  record field declaration is exactly that.
- 33 §2's **enumeration** gives site 2 the relation *"supplied field set **=** declared field set"*
  — a statement about names — and §4 elaborates only the name delta. It then closes with *"there is
  no sixth site because there is no sixth place a type is written"*.

F5 implemented the enumeration, because a feature implements and does not decide. The principle and
the enumeration disagree here, and picking between them is a decision.

## The two halves are not the same question

**Construction** is arguably *inside* site 2 — `Order{ … }` is one expression meeting one
declaration, and F5 already computes the declared field types to answer the name delta. The
supplied values are sitting right there unchecked.

**`with` is a genuine sixth site by 33's own counting rule.** 33 §1 characterises `e_with` as
synthesising *"the base's type, unchanged — `with` is width-preserving (26 §2)"*, and gives it no
row in the table. Adding one contradicts the sentence that closes §2.

Answering "yes" to construction and "no" to `with` is defensible and reads badly:
`Order{ Total = :oops }` rejected, `o with { Total = :oops }` accepted, for a reason the author
cannot see from the surface. That asymmetry is the actual cost to weigh.

## What is already decided — do not re-raise

| Decided | By |
|---|---|
| A record IS a closed map type; its field set is exact | [26](26-data-modelling.md) §4 |
| `with` is width-preserving and cannot add a field | [26](26-data-modelling.md) §2 |
| Synthesis is total over the twelve forms; obligation is a fixed list | [33](33-body-check-site.md) §1 |
| The analysis is function-local | [18](18-boundary-defence.md) §4 |

## The compiler delta, if the answer is yes

Small, and stated so the ticket is not answered on cost. F5 already resolves the declared field
types (`declared_fields/1` reads the same map) and already synthesises every assigned value —
`type_of/3` walks them today purely to collect diagnostics from nested expressions:

```erlang
%% NEW, in the e_record clause and again in e_with — one containment per field
%% against the type the record declaration wrote down.
{field_value_not_accepted, Record, Field, Residual}
```

The residual is a type, so the existing printer renders it and ticket 23 is satisfied without a
new shape of diagnostic. **Nothing new in `bs_types`.**

## Notes

Blocked by nothing. Worth answering **before angle brackets**, for the same reason 33 was: an
`option<T>` field multiplies the assignments this question is about.

**Do not re-derive whether a record's field set is exact.** 26 §4 settled it and F5 enforces it.
This ticket is about the *values*, not the *names*.

**Linear**: [ENG-203](https://linear.app/davewil/issue/ENG-203). Verified against the workspace
rather than derived: ticket 35 is ENG-202, so the *"from 33 it is ENG-(167+NN)"* offset does still
hold here — but it was checked, because the map's own instruction is to verify the arithmetic and
the rule has already broken once.

---

## Answer — resolved 2026-08-21

**Yes to both, and neither is a sixth site.** A field assignment is checked against the type the
record declaration wrote down, at construction *and* at `with`. Site 2 is not "construction"; it is
**field assignment**, and `Order{ … }` and `o with { … }` are its two spellings.

The asymmetry this ticket calls *"the actual cost to weigh"* never arises, because the answer is
yes to both halves. What the measurement found instead is that the ticket **under-counted the
defect and mis-drew its own scope fence** — see [Three defects, not two](#three-defects-not-two).

### Why `with` was never the sixth site

The ticket's case for treating `with` as a sixth site rests on two sentences of
[33](33-body-check-site.md). Read verbatim, neither says what the ticket takes it to say.

**33 §2's closing sentence carries its own justification clause, and it enumerates:**

> There is no sixth site because there is no sixth place a type is written. `e_op`, `e_tuple`,
> `e_list` and `e_block` declare nothing, so they synthesise and never check.

Four forms are named. **`e_with` is not among them** — and it could not be, because the type
governing `o with { Total = … }` is `Total: int`, written in the record declaration. That is a
place a type is written, and it is the *same* place that governs `Order{ Total = … }`. One
declaration, two expressions meeting it.

**33 §1's `e_with` row is a synthesis row, not an obligation row.** The row reads *"the base's
type, unchanged — `with` is width-preserving"*, and it sits in the table titled *"Its type comes
from"*. 33 §1's central move is to separate the two:

> - **Synthesis** — every expression gets a type. Total, unavoidable, twelve clauses.
> - **Obligation** — where containment is *checked* and a diagnostic raised. A fixed list.
>
> The decision is entirely in the second.

Citing a synthesis row to settle an obligation is exactly the conflation 33 §1 identifies as
*"why sub-question 1 was the wrong cut"*. `with` synthesising an unchanged type and `with`
checking its assigned values are independent facts; both hold.

**The comment the code carries is therefore wrong**, and is the clearest statement of the error
this ticket corrects — `bs_check.erl`, the `e_with` clause:

```erlang
%% `with` is width-preserving (ticket 26 §2), so the base's type passes through
%% unchanged. The assigned VALUES are not checked: that would be a sixth site,
%% and ticket 33 enumerated five.
```

Width-preservation is about *names*. It licenses nothing about values, and the second sentence
does not follow from the first.

### Measured, not argued

Four measurements, all against the tree at `cf32e50`.

**1. Both of the ticket's claims still hold.** Raised 2026-08-14; F6–F20 have landed since, so
staleness was the first thing checked. `Order{ Id = :oops, Total = n }` and `o with { Total = :oops }`
both compile to a `.beam`, exit 0, no diagnostic.

**2. The compiler already writes down the obligation it does not check.** The emitted `-spec` for
the constructing function declares the field type, and the emitted body violates it *in the same
file*:

```erlang
{attribute,0,spec,{{'Make',1},[{type,0,'fun',[...,
    {type,0,map_field_exact,[{atom,0,'Id'},{type,0,integer,[]}]}, ...]}]}}.
{function,0,'Make',1,[{clause,7,[{var,7,'N'}],[],
    [{map,7,[..., {map_field_assoc,7,{atom,7,'Id'},{atom,7,oops}}, ...]}]}]}.
```

**Dialyzer names both halves, identically**, and it is the tool [13](13-compilation-target-decision.md)
§6 emits these specs *for*:

```
Invalid type specification for function 'Probe':'Make'/1.  The return types do not overlap
Invalid type specification for function 'Probe':'Bump'/1.  The return types do not overlap
```

This is [18](18-boundary-defence.md)'s own criticism of Gleam — *"trusts its `@external` and
publishes the false claim as a `-spec`"* — turned inward, which is the argument 33 §2 used to
*add* site 4. The same argument reaches field assignment, and it does not distinguish the two
spellings because the emitted spec does not either.

**3. Gleam rejects both, with one diagnostic shape.** Measured on the installed 1.18.1 rather than
cited — the closest neighbour on this runtime, and it draws no line between construction and
update:

```gleam
Order(id: Wrong, total: n)      // error: Type mismatch — Expected Int, Found Wrong
Order(..o, total: Wrong)        // error: Type mismatch — Expected Int, Found Wrong
```

Two identical errors. A language that had found an asymmetry here would show it here.

**4. `with` is unchecked on the *name* half too.** See below — this is the finding the ticket did
not anticipate.

### Three defects, not two

The ticket fences itself: *"Do not re-derive whether a record's field set is exact. 26 §4 settled it
and F5 enforces it. This ticket is about the values, not the names."*

**That fence is false for `with`.** F5 enforces the name half at *construction only*.

| Form | Name half | Value half |
|---|---|---|
| `Order{ Id = 1 }` | **checked** — `field_set_mismatch` names the missing field | **unchecked** |
| `o with { Nope = 1 }` | **unchecked at compile time** | **unchecked** |

`o with { Nope = 1 }` compiles clean and emits `{map_field_exact, …, {atom,…,'Nope'}, …}` — Erlang's
`:=`, which raises at run time:

```
RAISED error:{badkey,'Nope'}
```

So 26 §2's width-preservation is real, but it is delivered **by the BEAM at run time**, not by the
compiler at compile time. That is the shape [54](54-list-length-in-the-algebra.md) was about — a
program the compiler accepted that crashes — and it is why this ticket is worth building rather
than filing: leaving it is a known runtime crash in the tree.

The name relation genuinely differs between the two spellings, and that difference is already
settled by 26, not opened here: construction requires field-set **equality**, `with` requires
**subset**. The *value* relation is identical in both. One site, one value rule, two name arms.

### This overturns 33 §3's "useless" verdict

33 §3 measured the residual at each site and marked construction's **useless**:

| Site | Query | `to_pattern` of the residual |
|---|---|---|
| Construction | `Order{Id} \ Order` | `{ Kind: :'Shop.Order' }` ← **useless** |

That measured the **name** residual, which names the type being built rather than the field
forgotten — correct, and worthless, exactly as 33 says. The **value** residual is a different
query and is precise:

```
type_of(:oops) \ int   =   :oops
```

The field name is known (it is the key being assigned), and the residual is the offending type. So
field assignment hands back both halves of a usable diagnostic, and 33 §3's verdict — which is
about the site's name arm — stands unamended while ceasing to be the whole story.
**This strengthens [23](23-what-the-language-owes-an-agent.md) rather than weakening it**: a site
33 recorded as unable to hand an agent anything writable can, on its value arm, do so.

### The compiler delta

Larger than the ticket priced, and larger only in **scope**, not in kind — still containment
against `declared_fields/1`, still nothing new in `bs_types`.

| Arm | Where | Diagnostic |
|---|---|---|
| Construction — value | `type_of`'s `e_record` clause | `field_value_not_accepted` (new) |
| `with` — value | `type_of`'s `e_with` clause | `field_value_not_accepted` (new) |
| `with` — name | `type_of`'s `e_with` clause | `field_set_mismatch`, existing |

**The name arm needs no new diagnostic shape.** `field_set_mismatch` already carries a `Missing`
and an `Extra` list, `field_list/2` renders an empty list as the empty string, and `with`'s failure
is precisely `{field_set_mismatch, Record, [], Extra}` — nothing missing, a name invented. Its
prose already has the right sentence for that arm: *"not declared by `Order`"*.

**Its headline verb is wrong for `with`**, and that is the whole of the prose change:
*"Bump builds an Order with the wrong fields"* is false — `Bump` updates one. The descriptor gains
a form field, `construction | update`, and the verb is read from it. One field, not a fourth
diagnostic shape.

### What this does NOT decide

- **Nothing about the boundary.** [46](46-refined-parameter-at-the-boundary.md) is untouched: this
  check is function-local ([18](18-boundary-defence.md) §4) and says nothing about a foreign caller.
- **Nothing about inference.** The declared field type is read, never solved. [04](04-crossclause-exhaustiveness.md)'s
  mandatory signature pays for this the same way 33 §1 says it pays for synthesis.
- **No sixth site.** 33 §2's closing sentence stands **unamended**. What is amended is one code
  comment that mis-cited it, and 33 §2's site-2 row, whose relation column gains the value half:
  *supplied field set = declared field set* becomes *…, and each supplied value is contained in
  that field's declared type*.

### Incidental finding — `check-links.sh` does not read the tickets

The dead citation this ticket carried for seven days (`26-record-and-aggregate-surface.md`, a file
that has never existed; the file is `26-data-modelling.md`) went unseen because the link gate's
corpus excludes `wayfinder/issues/`. Fixed here. A scan of all 55 issue files found exactly one
other — [48](48-a-map-type-in-the-prelude.md) points at `27-generics-and-parametricity.md`, and the
file is `27-parametric-polymorphism.md`.
