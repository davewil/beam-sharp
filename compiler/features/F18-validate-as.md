# F18 — `ValidateAs<T>`, the generated deep validator

**Status**      **done 2026-08-18**
**Implements**  [ticket 11](../../wayfinder/issues/11-type-system-shape.md) §2 (deep validation is an
                explicit call, never a clause head) and §3 (arrows rejected);
                [ticket 15](../../wayfinder/issues/15-error-model.md) §1 (the collapse check) and §2
                (the amended return type, and `ValidationError` as a path plus the expected type);
                [ticket 27](../../wayfinder/issues/27-parametric-polymorphism.md) §8 (a codegen
                obligation takes a **ground** type argument and is not a generic call);
                [ticket 28](../../wayfinder/issues/28-generic-syntax.md) (the instantiation bracket
                over a closed set of names). It **decides nothing**.
**Unblocks**    ticket 18 §6's decode step — `EtsLookup(…) |> ValidateAs<list<Order>>()` is the shape
                18 §7 writes and nothing could compile; the `list<term>` half of LANGUAGE.md §11's
                foreign-declaration rule, which sends every deep type across as `list<term>` **plus
                `ValidateAs<T>`** and had only the first half built
**Depends on**  F6 (the type-argument bracket, in *type* position), F3 (records, which is what a
                deep validator mostly walks), F9 (`string` as a refinement of `binary`), F7/F14
                (`switch` and the valve, which is how a caller consumes the `result`)

## Why this one now

**Because §10 of `LANGUAGE.md` states a guarantee the compiler does not keep.** The reference says
*"a foreign term that breaks your types will crash — not always where it entered, but never
silently"*, and then names its own gap in the next paragraph: the wrapper and the boundary guard
are not emitted, so a foreign call is a bare remote call today. `ValidateAs<T>` is the half of that
guarantee an **author** reaches for explicitly, and it is decided down to its return type while the
other half (18 §3's emitted guards) is not.

**And because the decided-unbuilt table is the backlog, not the feature rows.** F16 recorded that
the fourth starvation broke the cycle: a decision that is closed and unbuilt is a feature without a
number yet. `ValidateAs<T>` has been closed since ticket 11 and amended by 15 on 2026-08-12 — it is
the oldest entry in stratum 2 of `PRELUDE.md` marked **decided**, and the only one of the five
codegen obligations whose input type, output type and failure payload are all settled.

## The premise that was wrong, and it is a write-scope correction

The brief for this feature said *"`<T>` already parses; you are not building bracket syntax."* That
is true of **type position only**. Measured on this worktree, against the built escript:

```
$ cat Probe/probe.bs
module Probe

public result<int, term> Check(term x)

Check(x) -> ValidateAs<int>(x)

$ bsc Probe
Probe/probe.bs:5: error: syntax error before: '<'
```

The grammar has `type_prim -> uident '<' type_list '>'` and nothing in `expr` or `call` that accepts
`Name<T>(args)`. [`F6-angle-brackets.md`](F6-angle-brackets.md) says so itself, twice: `ValidateAs<T>`
is listed under **Out of scope** (:229), and :57 gives the reason — ticket 28's rule that *"`<` opens
a bracket after one of those names and is comparison everywhere else"* is a rule over a **closed set**
that, with all three names unbuilt, *"is **empty**. So the rule is a no-op today and F6 does not
write it."* **F18 is the feature that makes that set non-empty**, so F18 is where the rule is written.

**It costs one production and no lexer change, which is cheaper than ticket 28 predicted.** 28 frames
the rule as *lexical* — and `leex` has no context, so implementing it there means a post-lex retag.
It is unnecessary here: a bare `uident` **is not an expression** in this grammar. The only things
that may follow one are `(` (a call), `{` (a record construction) and `.` (a qualified call), so

```
call -> uident '<' type_list '>' '(' expr_list ')'
```

cannot conflict with `expr -> expr '<' expr`, because no `uident` can ever be that rule's left
operand. `yecc` reports no new conflict. **The observable surface is identical to 28's rule** — `Foo
< 3` was a syntax error before this feature and is one after it — and the closed-set restriction
moves from the lexer to `bs_check`, where a name outside the set gets a *named diagnostic* instead
of `syntax error before: '<'`. That is strictly the better error, and it is the same place the
already-decided-but-unbuilt members of the set (`ParseAtom<T>`, `ToExistingAtom`) are refused by
name rather than by silence.

**THIS IS A REALISATION OF 28 §2, NOT A DEVIATION FROM IT AND NOT A NEW DECISION.** 28 §2 decided
*what is true of the language*: `<` opens an instantiation bracket after `ValidateAs`, `ParseAtom`
and `ToExistingAtom`, and is a comparison after everything else. Every program accepted and every
program rejected is the same under either implementation, which is the test that makes this a
realisation. What 28 §2 additionally *described* — the stratum the restriction is enforced in — is a
statement about mechanism written before anything in the set existed to be built, and
[`F6-angle-brackets.md`](F6-angle-brackets.md):57 is explicit that F6 discharged the type-position
half and none of the value-position half. So this feature is the first one in a position to know
what the rule costs, and it costs a production rather than a scanner with a memory. Written down
here because a feature that quietly reinterprets a closed decision is indistinguishable from one
that reopened it, and only one of those is allowed.

**The set is a list, not a name.** `bs_check:codegen_obligations/0` holds all three, the
`not_an_obligation` diagnostic renders that list rather than a hardcoded string, and the fourth
obligation is a list entry with no grammar change. **`ParseAtom<T>` and `ToExistingAtom` are named
and NOT built** — the checker refuses each by name with a message that says which of "decided,
unbuilt" and "never going to work" it is reporting.

## What is being built

```csharp
public result<Order, ValidationError> Decode(term t)

Decode(t) -> ValidateAs<Order>(t)
```

`ValidateAs<T>(x)` is **not a call to a function named `ValidateAs`**. There is no such function in
the emitted module, no runtime dispatch and no type argument travelling anywhere. The compiler
resolves `T` at the call site, generates a monomorphic traversal for that one concrete type, and
lowers the call site to an ordinary local call of the generated function. 27 §8 is enforced rather
than described: a codegen obligation requires a ground type argument, and the generated code is the
proof — there is nothing in it a variable could have been.

**One validator per distinct type per module, not per call site.** Monomorphic *at* every use site
is the requirement (27 §8); emitting the identical traversal twice would satisfy it and waste the
module. Two `ValidateAs<Order>` calls in one module share one generated function, and
`ValidateAs<list<Order>>` generates a second one that calls the first.

### The generated shape

Every generated validator is `(X, P) -> {ok, X} | {error, {Path, Expected}}`, where `P` is the path
accumulated so far, **reversed**, and reversed back exactly once at the single site that builds an
error. The body is one `case` over `X` whose clauses come straight off the algebra's parts — which
is the point: `bs_types` already holds a type as *a DNF partitioned by constructor*, and the BEAM
dispatches on constructor for free. The atom part becomes atom clauses, the integer part becomes
range guards, a tuple product becomes a tuple pattern, a closed map member becomes a map pattern
plus `map_size/1`, and the fall-through clause is the error.

So the traversal is not written against the surface syntax of the type. It is written against the
normalised algebra, which means `option<int>`, `int | :nothing` and a user alias for either
generate **the same** validator — the same property F6.3 established for the checker.

### `ValidationError`, and the two things about it that are assumptions

Ticket 15 §2 fixes the payload as *"a path into the term plus the expected type — the shape Gleam's
decoders return"*, and `CONTEXT.md` adds *"a tuple today; a record candidate if one is ever
introduced"*. That is the whole of what is decided. Two spellings follow from nothing and are
**recorded here as this feature's assumptions**, in the shape F16 used for `--diagnostics term`:

```csharp
type ValidationError = (list<string>, string)
```

**(a) The path is a list of `string`, each segment spelled the way the author would reach that
place.** A record field is `".Total"`, a list element is `"[2]"`, a tuple component is `"(1)"`.
Gleam's `DecodeError` uses a flat `List(String)` too, and stringly indices with it; the departure is
that a segment here says *which kind of step it is* rather than only how far. The empty path means
the term itself was wrong, which is the common case and reads as such.

**(b) Gleam's third field, `found`, is deliberately absent.** 15 §2 names two components and this
implements two. Recorded as a deferred option with its requirement: adding `found` means rendering
an arbitrary foreign term to a `string` inside generated code, which is **ticket 16 §4's
language-published serialisation mapping** — owed and unwritten — and inventing a validator-only
spelling would leave beam-sharp with two renderings of `(:ok, 5)`. That is the same reasoning F16
used to keep 23 §5's JSON encoding out.

`ValidationError` enters **stratum 2** of the prelude — the compiler-known stratum a user could not
have written. Not because its *body* is unwritable (it plainly is writable, and is written above in
stratum-1 vocabulary), but because the compiler is the only thing that constructs a value of it, and
`PRELUDE.md`'s test for the stratum is authorship, not expressibility. This feature is also the
first time `bs_check:prelude/0` is **split into the two strata** rather than being one flat map;
stratum 1 keeps `option` and `result`, stratum 2 gains `ValidationError` and the codegen-obligation
roster that ticket 28's bracket is restricted to.

### Blame: descend where the choice is unique, blame here where it is not

A union asks a question the ticket does not answer: `(:ok, int) | (:error, atom)` handed
`(:ok, :nope)` — is the error *"at `(2)`, expected `int`"* or *"here, expected
`(:ok, int) | (:error, atom)`"*? Both are honest, and picking the first for every union means
picking a winner among failed alternatives, which is blame tracking and needs a rule nobody has
written.

The rule taken: **the validator descends only where exactly one candidate can match, and blames at
the current path where more than one can.** In practice the discriminating step is a constructor —
tuple arity, map field set, atom identity — so `(:ok, :nope)` above *does* get `(2)` / `int`,
because arity 2 with `:ok` first selects one product. A genuine ambiguity — two products of the same
arity, two records with the same field set — blames at the node with that node's whole type as the
expectation, and never invents a preference. Descending speculatively is the more useful error
exactly when it happens to be right, and the compiler cannot know when that is.

**The rule was right and the algebra under it was not — found by exemplar 25d, fixed 2026-08-24
as [ticket 61](../../wayfinder/issues/61-validateas-path-stops-at-the-row.md).** `l_elem/1` hands
every `list<T>` validator its element type as `T` unioned with itself, and `t_absorb/1` kept both
copies — so a list of tuple rows arrived as a two-member union of one product, read as genuine
ambiguity, and blamed the row where `"(N)"` descent was available. Nothing in this section
changed; the union now deduplicates and the descent this section always promised happens.

**Arity alone is not the discriminator, and writing it that way first is how that was found.** A
tagged union is the idiomatic shape on this runtime and *every* member of one has the same arity, so
grouping tuple products by arity reported `(:ok, int) | (:error, atom)` as ambiguous and blamed the
whole union for `(:ok, :nope)` — when the first component decides it outright. The rule as built:
a slot discriminates when **every** candidate carries a distinct singleton atom there. Every, because
a candidate that does not would be shadowed by a sibling's clause; distinct, because two candidates
wearing one tag are still two. A union of records is the same shape one constructor over, keyed on
the `Kind` a record erases to, which is why two records with identical field names still get exact
blame.

### What building it revealed: the collapse check tests EQUALITY, and overlap is not equality

15 §1's predicate refuses an instantiation when `T | <failure member> ≡ T`. It is exactly the right
test for the case 15 measured — a failure channel that vanishes — and it says nothing about a
failure channel that *survives while colliding*. `type Reading = (:ok, int) | (:error, atom)` is the
example: `Reading | (:error, ValidationError)` does not collapse, because a 2-tuple whose second
component is an atom does not contain one whose second component is a pair. So the check passes and
`ValidateAs<Reading>` compiles. But a caller writing `(:error, e)` to catch the failure now also
catches a `Reading` the validator **accepted**, and the two are told apart only by the shape of `e`.

**Inside the generated code this costs nothing**, and that is a design decision rather than luck:
every validator answers `{ok, V} | {error, _}` internally and only the root wrapper unwraps it into
the language's untagged `result`. A validator that returned the bare value could not tell its own
failure from a value it had just accepted, and would have been wrong for exactly this type.

At the *caller's* match site it is a genuine wrinkle, and it belongs to untagged unions rather than
to this feature — 15 §2 chose the untagged shape with its eyes open, because it is what makes
narrowing read well in a clause head. **Recorded, not fixed**: fixing it means either tagging the
success channel, which 15 rejected on the language's showcase, or extending the collapse check from
equality to overlap, which would reject `ValidateAs<Reading>` outright and is a change to a closed
ticket. Neither is F18's to make.

### The refusals, and which of them can fire today

| refusal | decided by | reachable today? |
|---|---|---|
| `ValidateAs<term>` — the failure channel does not survive normalisation | 15 §1 | **yes**, and it is the only instantiation that collapses |
| a name outside ticket 28's closed set — `Encode<int>(x)` | 28 | **yes** |
| a member of the closed set that is not built — `ParseAtom<T>`, `ToExistingAtom` | 10 §4, 10 §5 + 15 §1 | **yes** |
| exactly one type argument and one value argument | 11 §2 | **yes** |
| an arrow anywhere in `T` | 11 §3 | **no** — the algebra has no arrow node and the surface has no `fn(…)` type. F6 out of scope, ticket 27 §(c) |
| a non-ground `T` — `ValidateAs<TSource>` in a polymorphic function | 27 §8 | **no** — polymorphic *signatures* are unbuilt (F6 out of scope), so `T` is `unknown_type` first |

**The collapse row was measured in this repo's own algebra rather than read off ENG-181's table**,
because that table measures the *pre-amendment* return type. `atom | :error` collapses to `atom`;
the amended `atom | (:error, ValidationError)` does not, and only the top absorbs the tagged member:

```
atom | :error       collapsed to atom? true
atom | (:error, VE) collapsed to atom? false
term | (:error, VE) collapsed to term? true
```

So 15 §1's predicate — reject when `T | <failure member> ≡ T` — fires on exactly one instantiation,
`ValidateAs<term>`, which is also the one that is vacuous on its own terms: every term inhabits
`term`, so the validator could only ever succeed and the `result` a caller matched on would have no
failure clause to write.

### `string`'s membership check is generated here

`PRELUDE.md` marks `string` **built as a type** and its membership check **still owed** — *"a literal
establishes the property at compile time, and nothing else can establish it at all yet."* This
feature discharges that for the `ValidateAs` surface and no other: `string` is `binary` refined by
valid UTF-8 (20 §4), and the algebra holds the refinement exactly (`bins => [utf8]`), so the
generated clause is `is_binary(X)` plus a UTF-8 decode that must not return `error` or `incomplete`.
The other half of the part — `[other]`, the non-UTF-8 binaries, which 20 notes has no surface
spelling — is generated as the complement, so `binary \ string` validates correctly if anything ever
produces it.

## Scenarios

| id | input | command | expected | exit |
|---|---|---|---|---|
| F18.1 | `Decode(t) -> ValidateAs<int>(t)` | `bsc examples/Wire Decode 7` | `7` — the success arm returns the value, not a wrapper | 0 |
| F18.2 | the same | `bsc examples/Wire Decode :seven` | `(:error, ([], "int"))` — empty path, the term itself was wrong | 0 |
| F18.3 | `ValidateAs<list<int>>` | `bsc … "[1, 2, 3]"` | the list, unchanged | 0 |
| F18.4 | the same | `bsc … "[1, :two, 3]"` | `(:error, (["[1]"], "int"))` — the element index is in the path | 0 |
| F18.5 | `ValidateAs<Order>` over a record | a well-formed map | the record | 0 |
| F18.6 | the same, one field of the wrong type | the map | `(:error, ([".Total"], "int"))` | 0 |
| F18.7 | a record whose field is `list<Line>` | a line with a bad field | the path composes — `[".Lines", "[1]", ".Price"]` | 0 |
| F18.8 | a closed record with an **extra** key | the map | rejected — a declared map type is closed (26 §4), so `map_size` is part of the check | 0 |
| F18.9 | `ValidateAs<term>` | `bsc` | error: the failure channel does not survive normalisation (15 §1) | 1 |
| F18.10 | `Encode<int>(x)` | `bsc` | error: not a codegen obligation, naming the three that are (28) | 1 |
| F18.11 | `ParseAtom<Colour>(x)` | `bsc` | error: decided, unbuilt — and it names the ticket | 1 |
| F18.12 | `ValidateAs<int>(a, b)` and `ValidateAs<int, atom>(x)` | `bsc` | error on each: one type argument, one value argument | 1 |
| F18.13 | `ValidateAs<Unknown>(x)` | `bsc` | the existing `unknown_type` diagnostic, unchanged | 1 |
| F18.14 | the return type declared `result<Order, ValidationError>` | `bsc` | accepted; declaring the bare success type is the ordinary return-type error | 1 |
| F18.15 | `ValidateAs<string>` | a non-UTF-8 binary | rejected; a valid one accepted | 0 |
| F18.16 | one call site vs two on the same type | `module_info/1` on each | the same generated functions and **one** root wrapper — the second site adds nothing | 0 |
| F18.21 | a union of records with identical field names | run it | the minted `Kind` discriminates, so blame is exact | 0 |
| F18.17 | `ValidateAs<Reading>` over `(:ok, int) \| (:error, atom)`, handed `(:ok, :nope)` | run it | `["(2)"]` / `int` — the unique-candidate descent | 0 |
| F18.18 | a union with two products of the same arity | run it | blame at the node, with the whole union as the expectation | 0 |
| F18.19 | the emitted module | `bin/spec-check.sh` | Dialyzer accepts every spec, generated functions included | 0 |
| F18.20 | `LANGUAGE.md` §10 | `bin/check-language.sh` | the `ValidateAs` block compiles as **shipped** rather than `not-yet` | 0 |

## Out of scope

- **Recursive types, and the traversal owes something when they land.** A validator over a
  recursive type must terminate, and today the question cannot arise: `bs_check:resolve/3` raises
  `{recursive_type, N}` before a validator could be generated, so every `ty()` reaching the
  generator is a **finite tree** and the worklist that dedupes validators cannot cycle. Recorded
  rather than assumed, because a prose-only blocker is an invisible one (F15): when ticket 09's
  equirecursive machinery lands, the generator needs a **name assigned before the body is built** —
  the memo table must hold the function name for a type while that type is still being generated, or
  `Tree = :leaf | (:node, Tree, Tree)` recurses forever at *compile* time rather than at run time.
  The generated code itself already terminates by construction, since it walks a finite term.
- **Arrow types (11 §3) and non-ground `T` (27 §8).** Both refusals are decided and neither is
  reachable — see the table above. Building a check for a node the algebra does not have would be
  a test asserting on nothing.
- **`ParseAtom<T>` and `ToExistingAtom`.** The bracket now admits them and the checker refuses them
  by name. `ParseAtom<T>` is decided (10 §4) and simply unbuilt — a feature, not a ticket.
  `ToExistingAtom` is **owed**: `PRELUDE.md` records that 10 §5 spelled it `atom | :nothing` and 15
  §1 later made exactly that shape an error, with two known-good answers and neither chosen. It must
  not be implemented from the prelude file, so it is not implemented here.
- **The emitted boundary guard and the foreign wrapper** (18 §3, LANGUAGE.md §10's "Owed"). This
  feature builds the *explicit* half of the boundary — the call an author writes. The implicit half
  is a different decision about where the compiler inserts checks nobody wrote.
- **`ValidateAs<State>` inside a generated `code_change/3`** (18 §5). It reuses this mechanism and
  needs the state channel first.
- **`ValidationError` as a record.** 15 §2 flags it as a candidate *if* 26 lands a record form for
  it. It has not; the tuple is what is decided today.
- **`found`, Gleam's third field.** Reasoned above: it needs 16 §4's serialisation mapping.

## Done when

`bsc` compiles and runs a program that calls `ValidateAs<T>` on a valid term and on an invalid one,
and prints a path and an expected type for the second; all twelve gates are green; and the
`ValidateAs` block in `LANGUAGE.md` §10 is tagged **shipped** rather than `not-yet`, which is the
one surface a compiler-facing gate cannot reach.
