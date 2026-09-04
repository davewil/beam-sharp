# 28 — Angle brackets versus less-than: how does the parser disambiguate?

Type: grilling
Status: resolved 2026-08-13
Blocked by: 27 — resolved

## Question

Raised by [ticket 27](27-parametric-polymorphism.md) on 2026-08-12, which listed this among its
own questions and **did not answer it**. 27 settled that the language has real parametric
polymorphism with C#-style angle brackets; this ticket owns the consequence that
`<` and `>` are now overloaded.

The classic problem, and beam-sharp has every ingredient for it:

```csharp
F(a < b, c > d)
```

Two readings. Either two arguments — `a < b` and `c > d`, both comparisons — or one argument,
`a<b, c>` applied to `d`. C++ made this famously painful; C# and TypeScript both ship
disambiguation rules; Rust sidestepped it entirely with turbofish (`::<>`).

**Why it bites harder here than in C#.** Ticket 08 settled `&&`/`||` guards with comparison
operators, so `<` appears in guard position routinely, and guards sit directly against clause
heads where patterns and types are already dense:

```csharp
(x, y) when x < y && Total(x) > 0 -> ...;
```

Decide:

- **The disambiguation rule.** C#'s is specified (ECMA-334): after parsing a candidate type
  argument list, the token that follows decides. Confirm it is expressible for beam-sharp's
  grammar rather than assuming — beam-sharp's declaration syntax is not C#'s, and 27 §4 put
  variables in a *declaration* list on the signature, which C# also has but which beam-sharp
  pairs with a signature carrying types-only and no parameter names (ticket 08).
- **Whether an explicit-instantiation spelling is needed at all.** 27 left open when a call site
  must *write* `Map<Order, Money>(...)` rather than have the arguments determine it. If the
  answer is *never* — because instantiation is always recoverable by matching (27 §1) — then the
  ambiguity only ever arises in *type* positions, which is a much smaller grammar problem, and
  the whole question may shrink. **Establish this first; it may resolve the rest.**
- **Whether the guard sub-grammar is exempt.** Ticket 08 fixed guards to the BEAM guard set with
  no user function calls. If types cannot appear in a guard at all, guards can be parsed with `<`
  unambiguously as comparison, and the problem is confined to signatures and expressions.
- **The tier-3 fallback.** If no borrowed rule fits, a distinct spelling for instantiation
  (Rust's turbofish, or something else) is available — but note the map's amended heuristic:
  resemblance, not reproduction. A divergence needs a reason, not an apology.

## Binding constraints

- **Ticket 27 §4 is settled and not reopenable here.** Variables are declared and named with C#'s
  `T` convention; this ticket decides *parsing*, not spelling.
- **Ticket 08's guard vocabulary is settled** — BEAM guard BIFs, `&&`/`||`, no user function
  calls, expansion rule for named guards.
- **Ticket 08's signature form is settled** — types only, no parameter names; clauses do not
  repeat the function name.
- **The standing constraint applies asymmetrically.** A parser rule an agent must be *prompted*
  about is the expensive kind; a rule that merely costs keystrokes is nearly free.

## Notes

HITL. Small compared to most tickets on this map, and possibly much smaller than it looks — the
second bullet may collapse it. Also carries one loose end 27 recorded and did not place: **the
provisional list-pattern spelling `[h, ..t]`**, which ticket 08 constrains ("prefix-plus-rest
only") but pins no spelling for. It is a grammar question and belongs here unless a later ticket
claims it.

---

## Answer — 2026-08-13

**`<` opens an instantiation bracket after a compiler-known codegen-obligation name and is
comparison everywhere else — one lexer rule over a closed set of three names.**

The second bullet collapsed the ticket, and its own motivating premise is measured false.
Explicit instantiation *is* needed, on **exactly three names** — `ValidateAs`, `ParseAtom`,
`ToExistingAtom` — because a codegen obligation's type argument appears **only in the return
type**, which is the one thing matching cannot recover. Everywhere else instantiation is
recoverable, so **user code never writes a type argument**, and the rule needs no lookahead, no
backtracking and no turbofish: names in the closed set lex as their own token class, so the parser
never faces the choice. That forces the rule ticket 27 implied and never wrote: **every type
variable in a user signature must appear in at least one parameter position**, which is the
condition under which *"instantiation is matching, not solving"* is a true sentence.

**C#'s rule was measured, not cited** (dotnet 9.0.306): a follow-token test that is correct in
both directions — `CS0019` for a bare identifier after `>`, `CS0118` for `(` — and it is **not
LALR(1)-expressible**, since the decision point sits after an unbounded suffix while `yecc` must
commit at the `<`. So this is a **tier-3 divergence with a stated reason**, and it is
unobservable: the two rules agree on the case that occurs and differ only on a form beam-sharp
cannot express.

**Guards are exempt, and the exemption falls out rather than being written** — tickets 08 and 11
between them keep every type out of a guard, so nothing is there for a bracket to attach to. Two
things the platform had already given free, neither chosen for this purpose: **`a < b > c` is a
syntax error today** (`Nonassoc 300`, in the skeleton's operator table for readability), which
removes the C++ chained case entirely; and **no `>>` operator exists**, so `list<list<int>>`
parses — though ticket 20's binary grammar needs `>>` as a *delimiter*, so that half is **owed a
re-check when binaries land**.

**The loose end is closed: `[h, ..t]` is adopted in both pattern and construction position**,
tier-1 C# collection expressions, and free against ticket 26's projection dot outright. Against
float literals it is **earned rather than free**: `1..5` lexes as `1 .. 5` and not `1.` `.5`
*because* the float rule demands digits on both sides of its dot. The skeleton has no float
literal at all, so this is a **constraint `..` imposes on whoever settles them** — Erlang draws
the same line, so it is cheap — and `..` staying unclaimed as a range spelling for ticket 20's
intervals rides on it.

Sharpest downstream consequence: **ticket 27's stratum-2 rule gains a second job.** *"A codegen
obligation requires a ground type argument"* was a typing rule and is now **the parser's
disambiguator**, so the compiler-known set is load-bearing in the grammar, and **stratum 2's
membership is fixed at lex time**.

### Built 2026-08-14 as F6

Shipped as [F6](../../compiler/features/F6-angle-brackets.md) — the **type-position half only**,
124 tests up from 109. `result<T, E>`, `option<T>`, nesting, and user-declared `type Pair<T>`, all
by **substitution**: the variable is gone before the algebra sees it, so the bracket added no node
to `bs_types` and nothing to the emitted code. **The value-position rule was not written and did
not need to be** — with `ValidateAs`/`ParseAtom`/`ToExistingAtom` unbuilt the closed set is
*empty*, so `<` is comparison unconditionally, and F6 pins that against the **real** grammar where
[`28a`](../prototypes/28a_bracket_disambiguation.escript) measured a patched copy.
`list<list<int>>` now has a test, which is where the owed `>>` re-check will trip.

Ticket 27's §(c) — polymorphic function *signatures*, which are **matching and not substitution**
— was cut on ticket 27's own *"the costs are asymmetric and they do not chain"*, with three
measurements behind it: `Map` needs an arrow type the algebra lacks, no exemplar declares one, and
matching a variable **inside a union** is undecided →
[ticket 37](37-instantiation-by-matching.md).

**The hazard F6 found was not a rejection, it was a hang.** A cyclic alias did not error on
master, it spun — invisible to a green suite, and reachable for the first time because a parameter
is what makes `type Tree<T>` natural to write. It is guarded, and the control is a stopwatch
(0.093s versus no output at all), because a test that never returns is not a failing test.

**The second bullet did collapse it, and the ticket's own motivating premise is measured false.**
Every claim below is measured against the walking skeleton's real grammar
([`28a`](../prototypes/28a_bracket_disambiguation.escript),
[`28b`](../prototypes/28b_dot_dot_lexing.escript)) or against a real C# compiler
([`28c`](../prototypes/28c_csharp_disambiguation.md), dotnet 9.0.306), not cited.

> Decision brief: <https://claude.ai/code/artifact/e40ee94f-aa30-4747-9c03-6ccec619c127>

## 1. Explicit instantiation is needed — on exactly three names, all compiler-known

The ticket said to establish this first. It does not collapse to *never*, and it does not stay
large: it collapses to a **closed set the compiler knows before parsing begins**.

**Why user code never needs a bracket.** Ticket 27 §1 made instantiation *matching, not solving*.
At a call site the argument types are known, so any type variable appearing in a **parameter**
position is recovered by matching — which covers every polymorphic function 27 wrote down (`Map`,
`First`, `Identity`, and 16 §5's `Sort<T>` / `Max<T>`). The only variable matching cannot recover
is one appearing in **no** parameter position, and recovering *that* needs the expected type to
flow inwards. That is inference — the thing 27 refused first and hardest, and on which its entire
cost argument rests.

**So this ticket states the rule 27 implied and did not write: every type variable in a user
function's signature must appear in at least one parameter position.** It is not a new preference.
It is the condition under which *"matching, not solving"* is a true sentence; without it the phrase
is false at the first return-only variable, and 27's cost argument has a hole in it. A user wanting
`list<T> Empty<T>()` writes the monomorphic type instead — and the literals `[]` and `:nothing`
mean the case barely arises.

**Codegen obligations break that rule by design, which is precisely why they are not generics.**
`ValidateAs<Order>` takes a `term` and returns `result<Order, ValidationError>`: the type argument
appears **only in the return**. Ticket 27 line 427 already said so outright — they *"look exactly
like generic calls and are not — they are type-directed codegen, monomorphic at every use"* — and
forced them to carry a **ground type argument**.

So: **user code never writes a type argument; `ValidateAs`, `ParseAtom` and `ToExistingAtom` always
do.** Those are stratum 2 (14 §6): compiler-known, and closed.

## 2. The rule — the bracket belongs to a token class, not to a lookahead

> **`<` opens an instantiation bracket after a compiler-known codegen-obligation name, and is
> comparison everywhere else.**

No lookahead, no speculative parse, no backtracking, no turbofish. It is **one lexer rule**: names
in the closed set lex as their own token class, so the parser never faces the choice. Measured in
[`28a`](../prototypes/28a_bracket_disambiguation.escript): variant C is the only one of four that
gets both the instantiation rows and the comparison rows right, in a plain LALR(1) grammar.

### C#'s rule was measured, it is correct, and it is not available here

Bullet 1 asked to *confirm it is expressible for beam-sharp's grammar rather than assuming*.
**Confirmed — it is not**, and the negative is measured twice rather than assumed once.

*C# works, and here is what it actually does* ([`28c`](../prototypes/28c_csharp_disambiguation.md),
dotnet 9.0.306, a generic `Foo<A,B>` in scope):

| Source | Error | Reading C# took |
|---|---|---|
| `F(Foo < b, c > d)` | CS0019 — operator `<` on `method group` and `int` | **comparison** |
| `F(Foo < b, c > (d))` | CS0118 — `'b' is a variable but is used like a type` | **generic** |

So C#'s rule is a **follow-token test after a candidate type-argument list**, and it gives the right
answer in both directions. But it needs **unbounded lookahead** — the candidate list is arbitrarily
long — followed by a re-decision. **LALR(1) cannot do that.** Variant D is what you get if you
encode the production anyway: the parser must commit at `<`, takes the type-argument list, and dies
at `d`. That is not a strawman, it is the only thing an LALR(1) grammar *can* do with that rule.

beam-sharp's parser is `yecc`, and that is not incidental — ticket 13 chose the Abstract Format and
the skeleton is built on `leex`/`yecc` because they ship with OTP.

**This is therefore a tier-3 divergence with a stated reason**, on the map's amended heuristic
(*resemblance, not reproduction*): the borrowed rule was fully specified, fully understood, and
refused because the toolchain the rest of the map already chose cannot express it. Same shape as
27 §2 — a tier-1 borrow that was available and declined for a reason internal to this language.

**And the divergence costs almost nothing, measured.** Variant C and C# **agree** on case A, the
one that occurs. They differ on case B — but in beam-sharp `Foo<b, c>` is not an instantiable form
at all, because §1 removed explicit instantiation from user code. **The reading they differ on does
not exist here to be chosen.**

### Turbofish rejected, and not on taste

It would be a marked spelling for something users never write. §1 leaves exactly three call sites,
all compiler-known, all of which already read as generic calls throughout tickets 11, 15, 16, 18
and 20. `::<>` would rewrite every one of them to buy a disambiguation the closed set supplies free.

## 3. Guards are exempt — and the ticket's "why it bites harder here" is false

The ticket's motivating claim was that `<` appears in guard position routinely, hard against dense
clause heads. **The density is real; the ambiguity is not.**

**Guards contain no types.** Ticket 08 fixed the guard vocabulary to BEAM guard BIFs with no user
function calls, and ticket 11 put deep validation in an explicit `ValidateAs<T>` call *precisely so
a clause head does no unbounded work*. A codegen obligation therefore cannot appear in a guard, and
there is nothing for a bracket to attach to. So `<` in a guard is comparison **unconditionally**,
and the exemption **falls out rather than being written** — no guard sub-grammar, no special case.

[`28a`](../prototypes/28a_bracket_disambiguation.escript) runs ticket 08's own example,
`(x, y) when x < y && Total(x) > 0`, through all four variants: it parses identically in every one,
including the two that have generics.

Worth recording where the enforcement lives: the skeleton restricts guards **semantically**
(`bs_check`), not grammatically. That does not weaken the result — the *parse* is unambiguous
either way, so the checker never has to re-read a guard the parser already resolved.

## 4. Chained comparison was already illegal, which had removed the harder half

**`a < b > c` is a syntax error today**, in expression and guard position alike — `Nonassoc 300` on
the comparison operators, in the skeleton's operator table since it was written, measured in
[`28a`](../prototypes/28a_bracket_disambiguation.escript).

This matters more than it looks. The C++ disaster case is a **chain** of relational operators that
could also be a type-argument list. **beam-sharp cannot write the chain at all**, so the only
ambiguous shape remaining is the comma-separated one the ticket names, which §1 and §2 dispose of.
Nobody chose `Nonassoc` for this reason — it was there for readability — and it had quietly removed
half of this ticket before the ticket was raised.

**A second thing the platform gives free: `>>` is not a token.** `list<list<int>>` parses (28a).
C++'s famous right-shift collision requires a `>>` **operator**, and ticket 08's settled vocabulary
has no bit-shift operators at all — that half is permanent.

**But the *delimiter* half is not settled, and this is measured on the slice.** Ticket 20 committed
to the full `<<_:M, _:_*N>>` binary grammar, which needs `<<` and `>>` as **delimiters**; the
skeleton has neither, since binaries are on its "out on purpose" list. So when binaries land,
`list<list<int>>` must be re-checked against a lexer that has a `>>` token — and if longest-match
takes the two closing angles as one delimiter, nested generics need either a `> >` space rule
(C++98's answer, later abandoned) or the delimiter handled contextually. **Recorded as owed below**
rather than assumed benign.

## 5. The loose end — `[h, ..t]` is adopted, and it is free

Ticket 27 left it provisional; ticket 08 fixed the restriction (prefix-plus-rest only) and pinned no
spelling. **Adopted as written**, in both positions — the pattern `[h, ..t]` and the construction
`[f(h), ..Map(t, f)]` — which is what 27's samples and 18's already use.

**Tier 1 for one audience and unobjectionable to the other.** C# collection expressions spell it
`[first, ..rest]` exactly. TypeScript's spread is `...`, so a TS reader meets a two-dot variant of
something they already know rather than something new. Note this is *collection* spread, which
ticket 26 did not touch: 26 refused **record** spread (`{...o}`) in favour of `with`, on widening
grounds that do not apply to a list.

**It costs nothing lexically** ([`28b`](../prototypes/28b_dot_dot_lexing.escript)), against the two
things that could have collided with it:

- **Ticket 26's projection dot.** `o.Status..t` lexes cleanly as `o . Status .. t` — `..` ordered
  before `.`, and leex's longest-match settles the rest. **This one is established outright.**
- **Float literals** — the classic Pascal/Rust hazard. **`1..5` lexes as `1 .. 5`, not `1.` `.5`** —
  **but read the condition, because this result is earned rather than free.** The skeleton's lexer
  has **no float literal at all**; 28b supplies one, and it demands digits on **both** sides of its
  dot (`{D}+\.{D}+`), which is exactly why longest-match declines it at `1..5`. A float rule spelled
  `{D}+\.` — accepting a trailing dot, as Pascal did — would swallow the first dot and the collision
  would be real.

  **So this is an obligation `..` places on whoever settles float literals, not a property already
  established.** It is a cheap one — Erlang's own lexer already requires digits on both sides (`1.0`
  legal, `1.` not), so honouring it costs nothing and matches the platform — but it must be
  honoured, and it is recorded in *What this ticket owes* below rather than left in a prototype.

**Bonus, and conditional on the same thing:** that leaves `..` available as a **range** spelling
should ticket 20's integer intervals ever want a surface syntax. 20 added intervals to the algebra
and spelled refinements with predicates; it never claimed `..`, and nothing here takes it — but the
availability rides on the float rule above.

## 6. Consequences for other tickets

- **[Ticket 27](27-parametric-polymorphism.md) — its §4 gains the rule it implied.** Every type
  variable must appear in at least one parameter position. 27 needs no amendment, but **the spec
  must carry this line** or *"instantiation is matching, not solving"* is false at the first
  return-only variable.
- **27's stratum-2 rule gains a second job.** *"A codegen obligation requires a ground type
  argument"* was a **typing** rule; it is now also **the parser's disambiguator**. The
  compiler-known set has become load-bearing in the *grammar*, not only in the checker.
- **The map's prelude-stratum fog loses a candidate answer, on new grounds.** The fog asks what
  distinguishes stratum 2 and whether a user may add to it. Independently of that question,
  **stratum 2's membership is now fixed at lex time**, so the set must be **closed and known before
  parsing** — a user cannot introduce a name that takes an instantiation bracket. That does not
  settle the fog; it rules out an open, user-extensible stratum 2 on *grammar* grounds, where
  20 §5 had ruled it out on safety grounds and then narrowed that refusal to a placement rule.
- **[Ticket 15](15-error-model.md)'s owed `ToExistingAtom` respelling is now also a grammar item.**
  Whatever it is respelled to, the name stays in the closed lexer set — so a respelling that
  *renames* it must update the lexer, not only the prelude signature.
- **[Ticket 25](25-exemplar-programs.md) gains a settled surface.** All six exemplars can now be
  written without inventing a bracket rule or a rest spelling. That was the reason to take this
  ticket before writing them.
- **[Ticket 22](22-how-opinionated.md) inherits nothing new.** The `[incomplete]` marker's spelling
  is still 22's, and this ticket adds no attribute grammar for it to collide with.

## What this ticket owes

- **The companion rule in §1 is a real restriction on user code** and is the one thing here a reader
  might want to argue with: a signature whose type variable appears only in the return type is
  rejected. It is forced by 27's refusal of inference, but it was never written down before now.
- **The skeleton does not implement any of this yet** — it has no generic syntax, no `..`, no
  projection dot, and no module identifiers in value position. 28a and 28b measure *patched* copies
  of its grammar and lexer. The rules are proven expressible, not yet shipped.
- **A constraint on float literals, owed to whoever settles them.** §5's `1..5` result is earned by
  the float rule requiring digits on **both** sides of its dot. A trailing-dot float (`1.`) would
  make the collision real. Erlang already draws the line in the right place, so this costs nothing —
  but it is a constraint `..` *imposes*, and the range spelling staying free for ticket 20's
  intervals rides on it.
- **`>>` must be re-checked when binaries land.** §4's finding covers the *operator*, which will
  never exist. Ticket 20's `<<_:M, _:_*N>>` grammar needs `>>` as a **delimiter**, and nested
  generics (`list<list<int>>`) meet it at exactly the same two characters.

## Evidence

| Claim | Where |
|---|---|
| Four grammar variants built from the real `bs_parser.yrl`; C is the only one that reads both instantiation and comparison correctly | [`28a_bracket_disambiguation.escript`](../prototypes/28a_bracket_disambiguation.escript) |
| `a < b > c` is already a syntax error (`Nonassoc 300`); `>>` is not a token so `list<list<int>>` parses; ticket 08's guard shape parses identically under every variant | [`28a`](../prototypes/28a_bracket_disambiguation.escript) |
| yecc resolves shift/reduce conflicts **silently** via the precedence table — every variant reports zero conflicts, including the one that gets the answer wrong | [`28a`](../prototypes/28a_bracket_disambiguation.escript) header |
| `1..5` lexes as `1 .. 5`, not `1.` `.5`; `o.Status..t` lexes cleanly | [`28b_dot_dot_lexing.escript`](../prototypes/28b_dot_dot_lexing.escript) |
| C#'s rule is a follow-token test: CS0019 (comparison) for a bare identifier after `>`, CS0118 (generic) for `(` after `>` | [`28c_csharp_disambiguation.md`](../prototypes/28c_csharp_disambiguation.md) |

## Decisions entry

<!-- This ticket's entry. wayfinder/decisions.md is GENERATED from blocks like this
     one and carries only the first sentence; the whole entry is read here. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- [Angle brackets versus less-than](issues/28-generic-bracket-parsing.md) — **the second bullet
  collapsed the ticket, and its own motivating premise is measured false.** Explicit instantiation
  *is* needed, on **exactly three names** — `ValidateAs`, `ParseAtom`, `ToExistingAtom` — because a
  codegen obligation's type argument appears **only in the return type**, which is the one thing
  matching cannot recover. Everywhere else instantiation is recoverable, so **user code never writes
  a type argument**, and the rule is one line: **`<` opens a bracket after a compiler-known
  codegen-obligation name and is comparison everywhere else** — a *lexer* rule on a closed set, with
  no lookahead, no backtracking and no turbofish. That forces the rule 27 implied and never wrote:
  **every type variable in a user signature must appear in at least one parameter position**, which
  is the condition under which *"matching, not solving"* is a true sentence. **C#'s rule was
  measured, not cited** (dotnet 9.0.306): a follow-token test that is correct in both directions —
  `CS0019` for a bare identifier after `>`, `CS0118` for `(` — and it is **not LALR(1)-expressible**,
  since the decision point sits after an unbounded suffix while `yecc` must commit at the `<`. So
  this is a **tier-3 divergence with a stated reason**, and it is unobservable: the two rules agree
  on the case that occurs and differ only on a form beam-sharp cannot express. **Guards are exempt
  and the exemption falls out rather than being written** — 08 and 11 between them keep every type
  out of a guard, so nothing is there for a bracket to attach to. Two things the platform had
  already given free, neither chosen for this purpose: **`a < b > c` is a syntax error today**
  (`Nonassoc 300`, in the skeleton's operator table for readability), which removes the C++ chained
  case entirely; and **no `>>` operator exists**, so `list<list<int>>` parses — though ticket 20's
  binary grammar needs `>>` as a *delimiter*, so that half is **owed a re-check when binaries land**.
  The loose end is closed: **`[h, ..t]` adopted in both pattern and construction position**, tier-1 C#
  collection expressions, and free against ticket 26's projection dot outright. Against float
  literals it is **earned rather than free**: **`1..5` lexes as `1 .. 5` and not `1.` `.5`** *because*
  the float rule demands digits on both sides of its dot — the skeleton has no float literal at all,
  so this is a **constraint `..` imposes on whoever settles them** (Erlang draws the same line, so it
  is cheap), and `..` staying unclaimed as a range spelling for 20's intervals rides on it.
  Sharpest downstream consequence:
  **27's stratum-2 rule gains a second job** — *"a codegen obligation requires a ground type
  argument"* was a typing rule and is now **the parser's disambiguator**, so the compiler-known set is
  load-bearing in the grammar, and **stratum 2's membership is fixed at lex time**.
  **Built 2026-08-14 as [F6](../compiler/features/F6-angle-brackets.md)** — the *type-position* half
  only, 124 tests up from 109. `result<T, E>`, `option<T>`, nesting, and user-declared
  `type Pair<T>`, all by **substitution**: the variable is gone before the algebra sees it, so the
  bracket added no node to `bs_types` and nothing to the emitted code. **The value-position rule was
  not written and did not need to be** — with `ValidateAs`/`ParseAtom`/`ToExistingAtom` unbuilt the
  closed set is *empty*, so `<` is comparison unconditionally, and F6 pins that against the **real**
  grammar where 28a measured a patched copy. `list<list<int>>` now has a test, which is where the
  owed `>>` re-check will trip. Ticket 27's §(c) — polymorphic function *signatures*, which are
  **matching and not substitution** — was cut on the ticket's own *"the costs are asymmetric and
  they do not chain"*, with three measurements behind it (`Map` needs an arrow type the algebra
  lacks; no exemplar declares one; matching a variable **inside a union** is undecided)
  → [ticket 37](issues/37-instantiation-by-matching.md). **The hazard F6 found was not a rejection,
  it was a hang**: a cyclic alias did not error on master, it spun — invisible to a green suite, and
  reachable for the first time because a parameter is what makes `type Tree<T>` natural to write.
  Guarded, and the control is a stopwatch (0.093s versus no output at all) because a test that never
  returns is not a failing test.
```
