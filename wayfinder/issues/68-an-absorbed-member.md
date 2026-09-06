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

**But 09 §4 does have a subject, and it arrived through [ticket 48](48-a-map-type-in-the-prelude.md).**
Measured 2026-09-06:

```csharp
type Slot = map<string, int> | map<string, binary>
```

Both members survive normalisation — `bsc --api` prints
`map<string, int> | map<string, binary> Handle(map<string, int> | map<string, binary>)` — and the
declaration compiles clean. Every way of taking it apart is refused, because ticket 48 shipped
`map<K, V>` with no pattern form:

```
MapPat.bs:6:1: error: Handle destructures a map whose keys are not a fixed list
  the parameter's type is: map<string, int> | map<string, binary>
  ...matching one in a clause head is not built.
```

So the language has a union that can be declared, passed and returned and **never taken apart** —
exactly the shape 09 §4 said to refuse. It became writable not because a type was added but
because a *pattern form was withheld*. That is Q2.

## Round 1

Asked 2026-09-06. Q1 first, alone; Q2 added the same round once the measurement below landed. The
two are independent — Q1's programs all have an absorbed member, and Q2's witness has none.

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

### Q2 — 09 §4's criterion contradicts 09 §4's own accepted example. Which is wrong?

09 §4 accepts the first of these and its criterion refuses the second. Measured, they are the same
shape: both keep two members, and **neither is decided by any BEAM guard.**

```csharp
type Xs   = list<int> | list<binary>            // 09 §4: accepted, "overlap at [], not a defect"
type Slot = map<string, int> | map<string, binary>   // criterion says refuse
```

`bsc --api` prints `Xs` as `[] | [int, ..] | [binary, ..]` — three spines, no merge. A clause head
decides it, and this ran:

```csharp
Kind([])           -> :empty
Kind([<<b>>, ..t]) -> :bins      // Kind([<<"a">>]) evaluates to :bins
Kind([n, ..t])     -> :ints
```

That is a **pattern**, not a guard. No BEAM guard can reach inside a list to tell `int` from
`binary`, so under 09 §4's stated vocabulary — *"a member is discriminable iff the compiler can
synthesise a BEAM guard expression that decides it"* — `Xs` would be refused, and the ticket lists
it as ✓.

`Slot` fails for a different reason: `map<K, V>` has no pattern form at all, so nothing reaches
its members. The two cases are separated by the **pattern grammar**, not by the guard vocabulary.

**(a) The examples are right, the vocabulary is wrong.** Discriminable means *some clause head can
decide it* — pattern **or** guard. `Xs` is accepted, `Slot` is refused, and a union's legality
becomes a function of what the pattern grammar admits, so `Slot` becomes legal on the day ticket
48 ships a map pattern.

**(b) The vocabulary is right, the ✓ example was wrong.** `Xs` is refused too, along with every
container union whose members differ only inside.

**The compiler delta for (a)**: a pairwise pass beside `collapse_refused/2` in `check_dir/3`
(`bs_check.erl:87-113`), running on normalised members per 09 §4's own normalise-first rule, which
`m_absorb/1` has already applied by the time it looks. The reachability question is one the
compiler already answers — `bs_types:pattern_parts/1` is what the residual printer uses to decide
whether a shape can be spelled. Refusing `Slot` needs no new analysis, only a new caller.

Note this makes *unspellable* and *indiscriminable* the same property, which they are not today:
F29 records shapes the printer cannot spell (`{cofinite, [:x]}`, `binary \ string`) that a guard
decides perfectly well. Under (a) the criterion has to be reachability by a head, not spellability
of a residual — related, and not the same function.

## Round 1 — answered 2026-09-06 (David)

**Q1 → (a). An absorbed member is an error where it is written.** Any member `M` where
`M ⊆ union(others)` is refused at the declaration, generalising F31 from the failure channel to
every member. The cost is accepted: `type Envelope = term | int` stops, and the repair — deleting
the member — is free, because the normalised type *is* the repair and the compiler can print it.

**Q2 → (a). Discriminable means a clause head can decide it — pattern or guard.** 09 §4's ✓
examples are the decided part; *"a BEAM guard"* was vocabulary reached for before ticket 04's
pattern-based exhaustiveness was the mechanism, and taken literally it refuses
`list<int> | list<binary>`, which the same section accepts. So `Xs` stays legal, `Slot` is refused,
and `Slot` becomes legal on the day ticket 48 ships a map pattern form.

Carried forward into the wording: the criterion is **reachability by a clause head**, which is close
to but not the same function as **spellability by the residual printer** — F29 records shapes the
printer cannot spell that a guard decides perfectly well.

**Filed alongside, not part of this ticket**:
[ENG-330](https://linear.app/davewil/issue/ENG-330) — `Bump(:foo)` over a `public int Bump(T n)`
with `type T = int | atom` and `when n >= 0` crashes `badarith`, because `rel_expr/2` emits a bare
comparison and `boundary_guards/5` adds `is_integer` only for an int-only parameter. The type half
of ticket 46's boundary guard; ENG-292 is the range half.

## Decisions entry

<!-- Written when the ticket resolves. -->
