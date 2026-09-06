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

## Round 2

Asked 2026-09-06. Two questions; the sites question and the parametric-alias question wait on a
blast-radius measurement and belong to round 3.

### Q3 — How many sentences does the declaration site have?

After round 1 all three of these are refused. Today the first is refused and the other two compile
silently.

```csharp
type Ledger = atom | :nothing                        // absorbed, and it IS the failure channel
type Label  = binary | string                        // absorbed, not the failure channel
type Slot   = map<string, int> | map<string, binary> // nothing absorbed; no head reaches either
```

`Ledger` gets F31's message today, and it earns its keep — it names the harm (*"no caller can write
the failure clause"*) and gives a hint that is specific and correct: *"tag it — `(:some, T) |
:nothing`"*.

**`Label` is where "print the normalised type as the repair" breaks.** The normalised type is
`binary`, so the mechanical repair is `type Label = binary` — and that is almost certainly *not*
what the author meant. Someone writing `binary | string` wanted either-or; the likelier intent is
`string`. The compiler knows the type and cannot know the intent.

`Slot` needs a different sentence again, because the fix is different in kind: tag the members, and
note that the refusal is **temporary** — under Q2(a) `Slot` becomes legal the day ticket 48 ships a
map pattern form. A message that says "tag them" as though it were permanent will be wrong within
one feature.

**The compiler delta**: how many tags in `bs_diag.erl`, and whether `collapsed_failure_channel`
survives as its own tag or becomes a hint line under a general one. F31 already varies its hint by
channel (`bs_diag.erl:1103-1110` for `:nothing`, `:1111-1120` for `(:error, _)`), so "one tag whose
hint varies" is a shape this compiler already has.

### Q4 — Does this close [ticket 64](64-failure-types-collapse-at-term.md)'s first question?

Ticket 64 asks four things. Its Q1 is *"Is it a defect at all, or the type system working
correctly?"* — and round 1's Q1(a) answers it: the collapse is sound and it is **still** refused,
because what it costs is the author's intent rather than soundness.

Its Q4 — *"Is there one rule here rather than two special cases?"* — is answered too: there is one
rule, `M ⊆ union(others)`, and F31's failure channel was a filter on it.

What round 1 does **not** answer is 64's expressiveness half. A `map<string, term>` lookup — the
shape all three of ticket 48's motivating cases have — still cannot say "absent" in a type the
checker can see, and now it is refused loudly rather than collapsing silently:

```csharp
public option<term> Fetch(map<string, term> m, string k)   // refused: term | :nothing IS term
public (:ok, term) | :absent Fetch(map<string, term> m, string k)   // 48's workaround, per call site
```

So: does ticket 64 narrow to that expressiveness question and stay open, or is there a reason to
keep its Q1 open too?

## Round 2 — answered 2026-09-06 (David)

**Q3 → two tags.** One for absorption, one for unreachability, because the fixes differ in kind
rather than in degree. The absorption tag states the normalised type as **fact** — *"`Label` is
`binary`"* — and offers the repair as a fork, *delete the absorbed member, or narrow the one
absorbing it*, because the compiler cannot tell which the author meant and `binary | string` is the
case that proves it. F31's failure-channel wording survives as a **third hint variant** under that
tag, not as a tag of its own: its harm sentence is a specialisation of *"a member you wrote is not
in the type"*, and its hint is too specific to lose. The unreachability tag says the members are
fine and nothing can reach them, and names the pattern grammar as the reason, so the refusal's
temporariness is visible.

**Q4 → narrow ticket 64.** Its Q1 and Q4 are answered by this ticket and are to be marked so in its
file; Q2 and Q3 stay live. Ticket 64 stops being *"is the collapse a defect"* and becomes *"what
does a `term`-valued lookup reach for"*.

## Blast radius, measured 2026-09-06

Every `.bs` file in the tree (105 files, 78 directories) parsed per-directory, every top-level
union's members resolved individually and tested with the exact Q1(a) predicate
`bs_types:is_subtype(Mi, bs_types:union(others))` — the call `absorbed/2` makes. Markdown, the
eunit suite's inline program strings and the gate heredocs swept alongside.

| | newly failing |
|---|---|
| `.bs` modules | **0** |
| eunit tests | **1** |
| gate scripts | **0** |
| compiled-doc gates (`check-language`, `check-tour`, `check-readme`) | **0** |
| Q2(a), everything | **0** |

The one test is `string_or_binary_absorbs_to_binary_test/0`,
`compiler/test/strings_tests.erl:111-118`, which asserts `{ok, _, []}` — zero diagnostics — for
`type Any = string | binary`. Its doc twin is scenario **F9.7**,
`compiler/features/F9-strings-and-binaries.md:120-123`: *"`string | binary` absorbs to `binary`
rather than erroring."*

**F9.7's reasoning survives; only its verdict changes.** Its comment reads *"09 §4 errors on
INDISCRIMINABLE members and `string` is nested rather than overlapping, so the neighbouring rule
correctly does not fire"* — still true under Q2(a). What refuses it is Q1(a), a rule that did not
exist when F9.7 was written.

Of the four shapes F31 enumerated as the general rule's targets, exactly one is instantiated
anywhere in the tree, and it is that test.

**Two sites facts, measured the same day:**

- **A bare inline union does not parse in a parameter position.** `param` takes a `type_prim`
  (`bs_parser.yrl:229-230`), exactly as `signature` (`:214-217`) and `foreign_sig` (`:126`) do —
  F31's citation of `:140` is stale. But `type_expr` *is* admitted in four nested positions —
  record and map fields (`:92`), tuple elements and generic arguments (`:205-206`), and alias
  bodies — and an absorbed member there compiles silently today:
  `public string H((atom | :ok, int) x)` resolves to `string H((atom, int))`.
- **A parametric alias is already collapse-checked at its instantiation.** `scan_ty/4`'s
  `t_generic` clause (`bs_check.erl:645-660`) substitutes and re-descends, so `Opt<atom>` is
  refused today at the **signature** line, not the alias line. Under Q1(a), `type Pair<T> = T | int`
  at `Pair<term>` needs no new traversal — only the gate removed. No such instantiation exists in
  the tree.

## Round 3

Asked 2026-09-06.

### Q5 — For a nested absorbed member, does the diagnostic name the position or only the declaration?

Both of these compile silently today and are refused under Q1(a). Neither has the absorbed member
at the top level of the declaration:

```csharp
record Job { Id: int, Tag: atom | :urgent, Owner: atom | :nobody }

public string Route((atom | :ok, int) x)
```

F31 reports at the declaration because **no type-expression node carries a line** — lines live on
the enclosing declaration tuple (`bs_check.erl:596-597`). So the line number cannot disambiguate
`Tag` from `Owner`, and F31's message names the member and its absorber but not the position.

**(a) Declaration only.** *"`:urgent` is absorbed by `atom`"*, reported at `Job`'s line. Matches
F31 exactly; costs nothing. With two absorbing fields it emits two diagnostics on one line, and
neither says which field.

**(b) Carry a path.** *"`Job.Tag` is `atom`; `:urgent` is absorbed by it"* and *"the first element
of `Route`'s parameter…"*. `scan_ty/4` already descends with `(Env, L, Seen)` and knows exactly
where it is at each step; a path accumulator is one more argument threaded through five clauses
(`bs_check.erl:638-673`).

### Q6 — Ticket 09 §1's illustration does not parse. Grammar gap, or stale text?

09 §1 shows the inline form as identical to the named one, and it is the passage the "naming is
aliasing" decision rests on:

```csharp
Handle(PaymentResult r)
Handle({ :ok, string } | { :error, string } r)   // measured: syntax error before ":ok"
```

It is stale twice over — a bare union does not parse in a parameter position at all, and the
example spells tuples with braces, which is not this language's tuple syntax.

**(a) File a grammar gap**: `param` should take a `type_expr`, so the inline form works and 09 §1's
claim is literally true at the surface.

**(b) Correct the ticket text**: the alias is the intended spelling, and 09 §1's actual claim — the
name never enters the algebra — is true whether or not the inline form is spellable.

This decides whether Q1(a)'s refusal ever fires at a **bare** inline union. Under (b) it never
does, and the four nested positions are the only inline sites it has to cover.

## Round 3 — answered 2026-09-06 (David)

**Q5 → (b). The diagnostic carries a path.** `scan_ty/4` already knows where it is at each step,
and the reason F31 reports at the declaration — no type-expression node carries a line — is exactly
why the position must arrive some other way or not at all. A record with two `atom`-typed fields is
ordinary, and declaration-only wording gives it two messages differing only in the member name.

**Q6 → (a). File the grammar gap.** `param` takes a `type_prim`, so ticket 09 §1's inline
illustration does not parse; the answer is to make it parse, not to correct the illustration. This
reverses the recommendation, and it widens Q1(a): the refusal must fire at a **bare** inline union
in a parameter position, not only at the four nested positions.

## Round 4

Asked 2026-09-06. Q6(a) is filed as [ENG-331](https://linear.app/davewil/issue/ENG-331), measured
conflict-free by `yecc:file/2` with `{report, true}` on the grammar before and after, and the
generated parser run against real sources.

### Q7 — Does the grammar gap reach the return and foreign positions, or parameters only?

The same one-word change at `signature` (`bs_parser.yrl:214-217`) and `foreign_sig` (`:126`) is
also conflict-free, and these parse under it:

```csharp
public :a | :b Pick(int n)
:a | :b Pick(int n)                    // no visibility marker
public :a | :b Flip(:a | :b x)
public atom | :nothing Go(int n)       // F31's collapse shape, in a return
```

**(a) Parameters only.** 09 §1's claim is about parameters, and the return position keeps its
alias-only discipline. F31's recorded scenario — *"there is no 'bare union in a return position'
scenario"* — stays true.

**(b) All three positions.** A union is a type, and a type is writable wherever a type is written.
F31's scenario list gains a case, and `collapse_decl/2` already covers `signature`, so the check
follows without change.

The cost of (a) is a rule a reader has to learn for no reason: `Handle(:a | :b x)` legal and
`:a | :b Pick(int)` not. The cost of (b) is that `public atom | :nothing Go(int n)` puts a `|`
between the marker and the function name, which is the hardest place in a C-family declaration to
scan.

### Q8 — How does the unreachability check know which shapes a clause head can match?

Q2(a) made a union's legality a function of the **pattern grammar**, so `Slot` is refused today and
must become legal on the day ticket 48 ships a map pattern form:

```csharp
type Slot = map<string, int> | map<string, binary>
```

**The obvious derivation is not available.** `bs_types:pattern_parts/1` looks like the oracle and is
not one — measured, it returns *type strings, not patterns*:

```
map<string,int> | map<string,binary>  -->  ["map<string, int>", "map<string, binary>"]
list<int> | list<binary>              -->  ["[]", "[int, ..]", "[binary, ..]"]
atom | int                            -->  ["atom", "int"]
(:a, int) | (:b, binary)              -->  ["(:a, int)", "(:b, binary)"]
```

Rows 2 and 4 are real patterns. Rows 1 and 3 are not — nobody writes `map<string, int>` or `atom`
in a clause head. Its own header says why (`bs_types.erl:1350-1354`): *"This is deliberately not
machinery — no cardinality function, no complement, no second format."*

**(a) A per-bucket table in the check** saying which buckets have a whole-bucket pattern —
binary `<<b>>`, list `[]` / `[h, ..t]`, tuple `(a, b)`, tagged map `{ Kind: :t }` — and which do
not: atoms and ints (guard-decided instead) and `map<K, V>` (neither). One line to update when a
pattern form ships, and nothing forces the update.

**(b) Make the oracle real**: extend `pattern_parts/1` or add a sibling that answers *is this member
matchable*, reversing F29's deliberate restraint and giving the check a derivation that cannot go
stale.

The trap under (a) is specific and datable: ticket 48 ships a map pattern, nobody edits the table,
and `Slot` stays refused for a reason that is no longer true.

## Round 4 — answered 2026-09-06 (David)

**Q7 → (b). All three positions.** `param`, `signature` and `foreign_sig` all take a `type_expr`.
Measured conflict-free; [ENG-331](https://linear.app/davewil/issue/ENG-331) covers both halves.

**Q8 → (b). Build the matchability oracle**, rather than a per-bucket table with a forcing
self-test. This reverses the recommendation.

### What (b) costs, measured after the answer

`head_parts/2` already computes the volatile half. Decoding its binder markers:

| union | heads |
|---|---|
| `map<string,int> \| map<string,binary>` | `m: map<string, int>`, `m: map<string, binary>` |
| `map<string,int> \| int` | `n`, `m: map<string, int>` |
| `list<int> \| list<binary>` | `[]`, `[n, ..]`, `[b, ..]` |
| `atom \| int` | `a`, `n` |
| `(:a, int) \| (:b, binary)` | `(:a, n)`, `(:b, b)` |
| `{ Kind: :a, X: int } \| { Kind: :b, X: binary }` | `{ Kind: :a }`, `{ Kind: :b }` |

A member printed as an **annotated binder** (`m: map<string, int>`) has no legal clause head —
there are no typed binders in pattern position. A member printed with structure does. That is the
pattern half of matchability, already computed.

**So the oracle splits, and only one half is volatile:**

- the **pattern** half is derivable from what `head_parts/2` already knows, and it is exactly what
  changes when ticket 48 ships a map pattern form;
- the **guard** half — `is_atom`, `is_integer`, `is_binary`, `is_tuple`, `is_map` — is the BEAM's
  vocabulary rather than the language's, so a table of it does not go stale. `atom | int` is two
  bare binders and is still discriminable, by guard.

Q8(b) therefore does not abolish the table; it moves the table to the stable half and derives the
volatile one. That is a better split than either option as it was put.

## Round 5

Asked 2026-09-06. One question: the frontier is nearly empty and this one gates what is left.

### Q9 — Does the oracle read the printer's output, or do they share a structured intermediate?

`head_parts/2` returns text meant to be pasted into source (`bs_types.erl:34`). The oracle needs a
predicate. Two ways to connect them:

**(a) The oracle reads `head_parts/2`'s output** and tests whether a member came back as a bare or
annotated binder rather than a structural pattern.

**(b) `head_parts/2` is refactored onto a structured intermediate** — one per member, carrying
whether it is a binder or a shape — which the printer renders and the oracle queries.

**(a) is the mistake this session already made once, in a cheaper form.** `pattern_parts/1` looked
like an oracle and was a printer; reading it that way would have shipped a check that refuses the
wrong programs. (a) repeats the shape knowingly: a printing change — F29 adding an annotation,
someone renaming a binder — silently changes what the compiler refuses, and no test necessarily
names the connection.

(b) costs a refactor of a function three callers depend on (`head_parts/2`, `head_combos/2`,
`name_binders/1`, plus the residual printer in `bs_diag`), on a path F29 built deliberately narrow.

## Decisions entry

<!-- Written when the ticket resolves. -->
