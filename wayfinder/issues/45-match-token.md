# 45 — Which token marks a match against a value already bound?

Status: **resolved 2026-08-16** — the token is `==`, written `== name`
Raised by: F8 (`compiler/features/F8-bind-and-match.md`, *The token*)
Blocks: F8 — **unblocked**
Type: `wayfinder:grilling`

## Question

F8 makes `var` bind and bare `=` match. A pattern that must match **the value a name already
holds** — Elixir's pin — needs a spelling, and F8 says outright that it *"must not decide"* it:
a spelling every future `.bs` file carries is a decision, not a feature.

## What is already decided, and by whom

**Mark the *match*, with one token, and not `^`** (David, 2026-08-15, recorded in F8).

- **Mark the match, not the bind**, on frequency: you only need to mark one of the two cases, and
  you mark the rare one. Binding is overwhelmingly the common case — every clause head, every
  `switch` arm — so Elixir's choice to mark the match is right, and marking the bind would be the
  expensive inverse.
- **Not `^`**, because since C# 8 it is the index-from-end operator (`arr[^1]`). A tier-2 spelling
  on top of a live tier-1 meaning is worse than a tie.
- **C# offers nothing to borrow**, so this is tier 3 — invent and say so. C# patterns cannot match a
  runtime value at all; they push you to `when v == expected`.

**So this ticket decides one thing only: which token.** The shape of the answer is settled; leaving
it in a feature file rather than on the map is what this ticket corrects.

## The candidates, as F8 tabled them

| Candidate | Reads as | Collides with |
|---|---|---|
| `==acc` | "equal to acc" | nothing in pattern position; reuses `==`, which 16 already fixed as `=:=` |
| `^acc` | Elixir's pin | **C# 8 index-from-end** — refused |
| `$acc` | a substitution | C# interpolated strings, which `string` will want |
| `&acc` | a capture | C#'s bitwise-and, and Elixir's capture operator |
| `~acc` | a sigil | Elixir sigils; free in C# but for bitwise-complement |
| `same acc` | plain English | nothing — but a keyword for a one-character job |

F8's recommendation is **`==acc`**: the only candidate borrowing a spelling the language already
has, with the meaning it already has, needing no new lexer token.

## The argument that did not exist when F8 was drafted

**[Ticket 42](42-interval-pattern-spelling.md) changed the pattern position under this ticket's
feet, and it argues for `==acc` far more strongly than F8 could have.**

Before 42, a pattern was a literal, a constructor, a binder or a wildcard, and `==acc` would have
been the *only* operator-shaped thing in it — a lone oddity. After 42, the parameter position
admits relational patterns:

```csharp
Classify(>= 4 and <= 7)  -> :reserved
Classify(<= -1)          -> :negative
```

so `== acc` is no longer an oddity but the **equality member of a family that now exists**:

```csharp
Reverse([== acc, ..rest], out) -> ...
```

A reader who has met `>= 4` in a head reads `== acc` correctly on sight, with no new concept. This
is exactly the map's *reads on sight versus must be taught* test passing, where before 42 it was
merely a plausible spelling.

**Note what C# does and does not supply here**, because 42's new rule makes the distinction load
bearing. C#'s relational patterns are `<`, `>`, `<=`, `>=` — **`==` is not among them**, because in
C# a constant pattern is written bare (`case 4:`) and there is no need. So `== acc` is not a borrow;
it is beam-sharp extending its own relational family to cover a case C# cannot express at all
(matching against a runtime value). That is tier 3, and by 42's rule it is the *safe* kind: the glyph
`==` carries into pattern position exactly the meaning it has everywhere else in this language, so
there is no false friend. It reads as what it does.

## What this ticket owes

1. The token.
2. If `==acc`: whether the space is significant (`==acc` or `== acc`, or both), since 42's
   relational patterns will have settled the same question for `>= 4`.
3. Confirmation that the grammar admits it wherever a pattern goes — clause head, `switch` arm,
   list element, record field — or a statement of where it does not.

## Answer

**The token is `==`, and a match against a bound value is written `== name`.** Resolved 2026-08-16.

F8's recommendation stands, and what this ticket adds is that it is no longer a recommendation
resting on readability. **Every claim below was measured through yecc and through an actual parse**,
per the borrow heuristic's own rule — *run it, do not reason about it* — and the probe is kept at
[`prototypes/45a_match_token_probe/`](../prototypes/45a_match_token_probe/).

### The control came first, because a green grammar proves nothing on its own

Eight variants were generated and every one came back clean, which is exactly the result a broken
harness gives. So the harness was pointed at a grammar already known to be bad: F8 records
`binding -> pattern '=' expr` at **fifteen reduce/reduce with yecc refusing to generate**, and the
probe reproduces **15 reduce/reduce**, to the number. Only then is "clean" evidence.

This is F6.9's rule one step further back. That rule says assert by *parse*, not by conflict count,
because yecc resolves shift/reduce silently through the precedence table. The control says: and do
not trust the conflict count to be *reported* until you have watched it report one.

### 1. The token

`pattern -> '==' lident`. One rule. **No new lexer token** — `==` has lexed since the walking
skeleton, for expression equality, and ticket 16 fixed that spelling as `=:=`, so the glyph carries
into pattern position with precisely the meaning it already has everywhere else.

That is the whole of the mechanism argument against the other five candidates, and it is a mechanism
argument rather than a taste one: `$acc`, `~acc` and `&acc` each need a lexer rule for a character
the lexer has none for (`$` and `~` appear nowhere in `bs_lexer.xrl` outside Erlang char literals in
a helper), and `same acc` needs a reserved word. `^acc` was already refused on C# 8's
index-from-end. **`==` is the only candidate whose cost is one grammar line and zero tokens.**

### 2. The space is not significant, and there was nothing to decide

Owed item 2 **dissolves rather than resolving**. `==acc` and `== acc` produce the identical token
stream — `{'==', L}` then `{lident, L, acc}` — because `==` is a maximal-munch lexer rule and `acc`
cannot begin with it. Both parse; they are the same program. There is no rule for the compiler to
carry and no error it could raise.

**House style is `== acc`, with the space**, matching `>= 4` in ticket 42's relational patterns, and
that is a statement about how the corpus is written rather than about what the grammar accepts. A
formatter could enforce it one day. Nothing else can, and nothing else should try.

### 3. Where the grammar admits it — and the one place it does not

Nine cases were parsed through the candidate grammar. `== name` parses in **every** position a
pattern goes:

```csharp
F(acc, == acc)                 -> ...   // clause head
m switch { == acc => 1, … }             // switch arm
F(acc, [== acc, ..rest])       -> ...   // list element
F(k, { Kind: == k })           -> ...   // record field
F(k, (== k, x))                -> ...   // tuple element
F(k, ({ Kind: == k }, x))      -> ...   // nested, at depth
```

**The last line strikes an item off F8's *Out of scope*.** That file says a pin inside nested
patterns at arbitrary depth is *"unmeasured, and the file says so rather than assuming"*. It is
measured now, and it parses — because `== name` is a `pattern`, and `pattern` is already recursive
through every one of its compound forms. Depth was never a separate question; it only looked like
one while nobody had run it.

**It does not parse to the left of a bare `=`**, and that is the correct answer rather than a
limitation to fix. The left of a bind is parsed as an *expression* and narrowed by `to_pattern/1`
(F8 deletes both), and no expression begins with `==`. Nor is anything lost: under F8 a bare `=`
against a name already in scope **is** a match, so `acc = x` already means what `== acc` would mean
there. The marker exists to disambiguate binding from matching, and in bind position `var` has
already done that job. **A marker is owed only where the ambiguity is.**

### 4. The rule is exactly as narrow as it looks — measured, not assumed

Extending the pattern grammar toward relational forms raises an obvious worry: does admitting
`== name` quietly admit more? Two candidates were tested, and **neither arrives**:

| Form | Does it come free? | If added deliberately |
|---|---|---|
| `>= acc` — a span bounded by a **runtime** value | **No.** Refused by the proposed grammar | yecc **clean**; it would work |
| `== 4` — a second spelling for the literal pattern `4` | **No.** Refused by the proposed grammar | yecc **clean**; it would work |

Both are therefore **available and deliberately not taken**, which is a different statement from
"impossible", and the difference is what stops a future session rediscovering it as a bug.

- **`>= acc` is a capability no ticket has decided.** A runtime-bounded span is a real thing to want
  and it is not this ticket's to grant; granting it as a side effect of choosing a token would be
  precisely the silent surface drift `bin/check-surface.sh` was built to catch. If it is wanted, it
  is a ticket. Note it would inherit F8.6 unchanged — a bound whose value the compiler does not know
  credits **nothing** to `Certain`.
- **`== 4` is refused on one-meaning-one-spelling.** The literal pattern `4` already exists and
  means exactly this. A second spelling for it buys nothing and costs a reader the question of
  whether the two differ. C# is the precedent rather than the exception here: its relational
  patterns are `<`, `>`, `<=`, `>=` and **`==` is deliberately not among them**, because a constant
  pattern is written bare. B# adds `==` only for the case C# cannot express at all.

So the family reads: **relational operators take a literal, `==` takes a name.** One sentence, and
it is the sentence `LANGUAGE.md` §2 now carries.

### 5. The compiler delta

Stated against the shipped source, so F8 has nothing to design:

| Site | Change |
|---|---|
| `bs_lexer.xrl` | **none** |
| `bs_parser.yrl` | one rule — `pattern -> '==' lident : {p_eqvar, line('$1'), value('$2')}.` Measured **clean**, against a control that reports 15 |
| `bs_check`: `pattern_type/3` | a `p_eqvar` case. Looks the name up in scope and answers **its** type — the same lookup F8.7 already owes for a bare name |
| `bs_check`: `clause_type/2` | `p_eqvar` is **inexact**, in the sense `[0, ..t]` already is. It may bound `Possible`; it credits **nothing** to `Certain`. This is F8.6 and it is the soundness heart of the feature |
| `bs_emit` | a `p_eqvar` lowers to the Erlang variable itself. A bound variable in an Erlang pattern *is* a match, so the target does the work and no guard is emitted |
| `bs_repl` | already pins by default since 2026-08-15, so this is what makes the prompt and the compiler agree — F8.8 |

The emitter row is the one worth reading twice. **beam-sharp is inventing a token for something the
target has for free**, because B# forbids rebinding and therefore cannot use Erlang's own rule that
a repeated name in a pattern matches. The token buys back a capability the runtime never lost.

### What this ticket does not decide

`==` in **guard** position is unchanged and was never in question: `when x == y` is ordinary
expression equality and already compiles. This ticket adds `==` to *pattern* position only. The two
do not interact, and F8.6's rule is why they must not be conflated — a guard the checker cannot
translate credits nothing, and `var == var` is exactly such a guard. That is the workaround F8
measured as *worse than it looks*, and this ticket is what removes the need for it.

### The finding this ticket did not go looking for

**`bs_repl` implements the opposite rule, and says so in a comment that will mislead whoever builds
F8.** `src/bs_repl.erl:193–197`, shipped 2026-08-15 — the same day David settled the shape:

```erlang
%% ALREADY BOUND — so it MATCHES against the value it holds,
%% rather than rebinding it. Every name is pinned, because
%% ticket 34 says a name means one thing, which is why the
%% language needs no `^`: there is nothing to disambiguate.
```

That is **pin-by-default**: a bare bound name in a pattern matches, and no marker exists or is
needed. It is Erlang's rule, it is coherent, and it is *not the decision*. F8.8 already records that
the prompt and the compiler disagree — but it states the disagreement without saying which side
moves, and the comment above states with confidence that the whole question is moot.

**Ticket 45 settles the direction: the marked rule wins, so `bs_repl` is what changes.** The
argument is this ticket's own, applied to itself — a bare name cannot *also* mean match, because
then `== name` would be a second spelling for something already spelled, which is precisely the
ground `== 4` is refused on two sections above. Choosing to mark the match is choosing that the
unmarked form means something else.

**What the unmarked form means in a head is F8's business and ticket 34's, not this one's**, and the
two candidates are *binds a fresh name* and *is an error*. This ticket asserts only that it is **not
a match**. Recorded here because the misleading artefact is a confident comment in shipped source,
and the next reader of it will be the person implementing F8.

### Assumption stated plainly

David settled the shape — mark the match, one token, not `^` — and the remaining call was the token
itself. It is resolved on `==` without waiting, because F8 is **not yet built**: if the token is
overruled the cost is a find-and-replace across two markdown files and one grammar line, and no
`.bs` file has been written in it. Every argument above is mechanism, and mechanism is what the map
refuses on; the taste call remains open until David says otherwise.

## Decisions entry

<!-- This ticket's entry. wayfinder/decisions.md is GENERATED from blocks like this
     one and carries only the first sentence; the whole entry is read here. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- **A match against a bound value is `== name`** — [ticket 45](issues/45-match-token.md), resolved
  2026-08-16. Raised by F8, which makes `var` bind and a bare `=` match, and which therefore needs a
  spelling for the third case: a pattern that must match **the value a name already holds**. David
  settled the shape on 2026-08-15 — *mark the match, one token, and not `^`* — on frequency, since
  binding is the common case and you mark the rare one, and because `^` has been C#'s index-from-end
  operator since C# 8. **This ticket settled only the token, and settled it by measurement.**

  **The control is the part worth copying.** Eight grammar variants were generated and every one
  came back clean first time — which is precisely what a broken harness reports. So yecc was fed a
  grammar already known to be bad: F8 records `binding -> pattern '=' expr` at fifteen reduce/reduce
  with yecc refusing to generate, and [`45a`](prototypes/45a_match_token_probe.escript) reproduces
  **15**, to the number. Only after that does a clean result carry information. This is F6.9's rule
  pushed one step further back — that rule says assert by *parse* rather than by conflict count,
  because yecc resolves shift/reduce silently through the precedence table; the control adds *and do
  not believe the count is being reported until you have watched it report one.*

  **The cost is one grammar line and no lexer change at all**, which is the whole mechanism argument
  against the other five candidates. `==` has lexed since the walking skeleton and ticket 16 already
  fixed its meaning as `=:=`, so the glyph carries into pattern position with exactly the meaning it
  has everywhere else in the language. `$acc`, `~acc` and `&acc` each need a lexer rule for a
  character `bs_lexer.xrl` has none for; `same acc` needs a reserved word.

  **The space is not significant, and that owed item dissolved rather than resolving.** `==acc` and
  `== acc` are the same token stream, because `==` is a maximal-munch rule and an identifier cannot
  begin with it. Both parse; they are one program. House style is `== acc`, matching `>= 4` — a
  statement about how the corpus is written, not about what the grammar accepts, and enforceable
  only by a formatter that does not exist.

  **It parses in every position a pattern goes** — clause head, `switch` arm, list element, record
  field, tuple element — **and nested at arbitrary depth**, which strikes an item off F8's *Out of
  scope*: that file called `({ Kind: ==k }, x)` unmeasured. Depth was never a separate question,
  because `== name` is a `pattern` and `pattern` is already recursive through every compound form;
  it only looked like one while nobody had run it.

  **It does not parse to the left of a bare `=`, and that is right rather than a gap.** The left of
  a bind is an expression narrowed by `to_pattern/1`, and no expression starts with `==`. Nothing is
  lost: under F8 a bare `=` against a name in scope already *is* a match, so `acc = x` already means
  what `== acc` would. **A marker is owed only where the ambiguity is**, and `var` has removed it
  there.

  **What did NOT come free is the half of this entry most likely to be rediscovered as a bug.**
  Admitting `== name` does not admit `>= acc` (a span bounded by a **runtime** value), and does not
  make `== 4` a second spelling for the literal pattern `4`. Both were measured as refused by the
  proposed grammar — and both were then measured as **yecc-clean if deliberately added**. So each is
  *available and deliberately not taken*, which is a different claim from impossible. `>= acc` is a
  capability no ticket has decided and is not this one's to grant as a side effect of choosing a
  token; that would be exactly the silent surface drift `bin/check-surface.sh` exists to catch, and
  if wanted it is a ticket. `== 4` is refused on one-meaning-one-spelling. The family therefore
  reads: **relational operators take a literal, `==` takes a name.**

  **And the token buys back something the target never lost.** A bound variable in an Erlang pattern
  *is* a match, so `p_eqvar` lowers to the variable itself and emits no guard. beam-sharp needs a
  spelling only because it forbids rebinding and so cannot use Erlang's own rule — which is the same
  position Elixir is in, and the reason `^` exists there.

  **And the finding the ticket did not go looking for.** `src/bs_repl.erl:193–197` implements
  **pin-by-default** — a bare bound name in a pattern matches — under a comment stating *"the
  language needs no `^`: there is nothing to disambiguate."* Shipped 2026-08-15, the same day David
  settled the opposite shape. F8.8 already records that the prompt and the compiler disagree, but it
  does not say which side moves, and that comment says with confidence the question is moot. **45
  settles the direction: the marked rule wins and `bs_repl` is what changes**, by this ticket's own
  argument turned on itself — a bare name cannot *also* mean match, or `== name` is a second
  spelling for something already spelled, which is the exact ground `== 4` was refused on. What the
  unmarked form *does* mean in a head (a fresh bind, or an error) stays F8's and ticket 34's; 45
  asserts only that it is not a match. Worth recording because the misleading artefact is a
  confident comment in shipped source, and its next reader is whoever implements F8.
```
