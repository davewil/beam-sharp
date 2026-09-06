# 68 — An absorbed member, and whether 09 §4 has anything left to refuse

Type: grilling
Status: claimed — [ENG-273](https://linear.app/davewil/issue/ENG-273)
Blocked by: —

Raised 2026-09-06 while grilling [ENG-273](https://linear.app/davewil/issue/ENG-273), which was
filed as a *debt* — a decision the compiler had not built. Measuring it found a different shape:
the thing ENG-273 measured is already decided **legal**, and the thing ticket 09 §4 actually
decided has **no program that can express it**. So this is a ticket, not a feature.

Every program below was run through `bin/ibs` at `1fd9036`, 2026-09-06.

## What ENG-273 measured, and what is already decided about it

ENG-273 measured four declarations, each with a member absorbed by another. Re-measured, all four
still resolve to a single member and report **zero diagnostics**:

```csharp
type A = atom | :ok              // --> atom
type B = binary | string         // --> binary       (string IS binary refined by UTF-8)
type C = term | int              // --> term
type D = list<term> | list<int>  // --> list<term>
```

It titled these *"a member nobody can discriminate"*. Two resolved tickets say that is the wrong
sentence for them:

- **09 §4 itself**: *"Normalise first, then check pairwise on the normalised members. `:ok | atom`
  **is** `atom` — the subset is absorbed by the algebra before discriminability is ever asked,
  which removes a whole class of false positives."* Shape A is the ticket's own worked example of
  a **false positive**.
- **[Ticket 20](20-untheorised-term-shapes.md):389** (resolved 2026-08-13): *"**Subsumption is not
  indiscriminability, and conflating them would reject a legal type.**"* It gives an absorbed
  binary union as **legal** and states the rule is *"about indiscriminable members, not
  overlapping ones."*

So a refusal of these four cannot be spelled as a discriminability rule. ENG-273 says as much —
*"a rule covering these four needs its own sentence, and 09 §4 has not been given one."* That
sentence is Q1.

## What is already refused, and by which sentence

[F31](../../compiler/features/F31-collapse-at-the-declaration.md) built
[ticket 15](15-error-model.md) §1: an absorbed member is refused **when it is the failure
channel**, and only then. The gate is `failure_channel/1` (`compiler/src/bs_check.erl:700-702`),
matching exactly two surface shapes — `:nothing` and `(:error, _)`. The scope limit is stated in
the source, `bs_check.erl:597-599`: *"Only the two failure members are checked: `binary | string`
also has an absorbed member, but the sentence this raises would be false about it."*

The predicate underneath is already general — `absorbed/2` at `bs_check.erl:2008` is
`bs_types:is_subtype(Failure, Success)`, F31's one-line normal form of `T | F ≡ T`. **Widening the
refusal is a filter change, not new machinery.**

## What 09 §4 decided, and why nothing reaches it

09 §4's canonical rejected declaration is `type Handler = fun<int> | fun<string>`. Measured:

- **B# has no function type.** `fun<int>` parses as a generic named `fun`
  (`bs_parser.yrl:202`) and is refused at resolve as `unknown_generic` (`bs_check.erl:998`) —
  *"no type named fun takes a type argument"*. Not as an indiscriminable union.
- **Two of the five BIFs 09 §4 names as the discriminability vocabulary are not in the
  compiler.** `is_function` and `binary_to_existing_atom` have zero occurrences in
  `compiler/src/`. The emitter's actual vocabulary (`guard_call/2`, `bs_emit.erl:1360`) is
  `is_atom`, `is_integer`, `is_binary`, `is_list`, `is_tuple`, `is_map`, `map_size`, comparisons
  and `unicode:characters_to_list/2`.
- **No diagnostic tag contains `discrimin` or `union`.** Of 79 tags in `bs_diag.erl` the only
  collapse-related ones are `collapsed_failure_channel` and `validate_collapses`.
- **There is no member enumerator.** `resolve({t_union, Ms}, …)` is two lines
  (`bs_check.erl:1017-1018`) and `bs_types:union/1` erases the boundary immediately.

**Four documents assert this refusal as present**: 09 §4; `CONTEXT.md`'s **Discriminable** entry;
`CONTEXT.md`'s **Binary type** entry (*"two that overlap without containment are indiscriminable
and rejected at the declaration"*); and ticket 15:226. None is backed by a check — the same
failure mode F31 §3 found and named, now at three more sites.

Whether any writable B# type can be indiscriminable **at all** today is being measured; it gates
Q2, not Q1.

## Round 1

Asked 2026-09-06. One question: the rest of the tree hangs off it.

### Q1 — What sentence, if any, covers an absorbed member outside the failure channel?

```csharp
module Shipping

type Status = :pending | :shipped | atom

public string Describe(Status s)
Describe(:pending) -> "waiting"
Describe(:shipped) -> "gone"
```

`atom` absorbs both literals, so the type declared on line 3 **is** `atom` and the two named
states are not in it. Today line 3 compiles and the author is stopped three lines later:

```
Shipping.bs:5:15: error: Describe is not exhaustive
  no clause matches:
  and no pattern spells:
    (atom \ (:pending | :shipped))
```

**The residual is unspellable**, so the diagnostic cannot show the clause that would fix it. Both
real repairs change line 3 — or a catch-all is added, which compiles and makes the two named arms
decorative:

```csharp
Describe(s) -> "unknown"      // measured: compiles, no diagnostic
```

The honest cost of refusing, stated by 09 §4 for its own case — *"this forbids a union that is
only ever passed through and never matched"* — is real and measured:

```csharp
type Envelope = term | int

public Envelope Forward(Envelope e)
Forward(e) -> e               // measured: compiles, no diagnostic
```

**(a) Refuse it at the declaration.** Any member `M` where `M ⊆ union(others)` is an error where
it is written. `Status` and `Envelope` both stop on line 3.

**(b) Leave it to the failure channel.** Today's behaviour: only `:nothing` and `(:error, _)` are
refused; everything else surfaces at the first match site, or never.

**The compiler delta for (a)**: `failure_channel/1` (`bs_check.erl:700-702`) stops classifying the
member and `each_member/4` (`bs_check.erl:675-695`) reports every absorbed one; `absorbed/2`,
`collapse_decl/2` and `scan_ty/4` are unchanged. One new tag in `bs_diag.erl` whose sentence is
true of `binary | string`, and which can print the repair, because the normalised type **is** the
repair — *"`Status` is `atom`; write `type Status = atom`, or narrow it."* Parametric aliases are
skipped by `collapse_decl/2` today and would stay skipped, so `Span<T>` is unaffected.

## Decisions entry

<!-- Written when the ticket resolves. -->
