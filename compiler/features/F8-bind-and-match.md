# F8 — `var` binds, `=` matches, and a name in a pattern is a value

**Status**      **buildable 2026-08-16** — [ticket 45](../../wayfinder/issues/45-match-token.md) ·
                [ENG-216](https://linear.app/davewil/issue/ENG-216) resolved: the token is `==`,
                written `== name`
**Implements**  [ticket 34](../../wayfinder/issues/34-local-bindings.md) (the binding it shipped),
                [ticket 33](../../wayfinder/issues/33-body-check-site.md) §5 / F5 (the irrefutable
                bind), [ticket 01](../../wayfinder/issues/01-sample-code.md) (Variant A's pattern
                grammar). **Raises one decision it must not make** — see *The token*
**Unblocks**    nothing in `examples/exemplars/`. It is here for the reason F4 was: the first thing
                a fluent reader reaches for should not be absent by accident
**Depends on**  F1, F4, F5, F7

## Why this one now, ahead of binaries

**It rewrites every `.bs` file in the repo, and every later feature adds more of them.** F9's
binaries and F10's pipe both introduce new source; doing this after them means rewriting their
files too. That is the whole of the ordering argument, and it is a cost argument rather than a
capability one — F8 unblocks no exemplar.

It takes the F8 slot on [F5](F5-body-check-site.md)'s precedent, which took F5 ahead of angle
brackets: **the features below it had no file**, so binaries and pipe shift to F9 and F10 and
nothing is lost.

## The three things, and only the third is contested

### 1. `var` marks a binding

```csharp
var lines = o.Lines
var (a, b) = Split(lines)
```

**In C#, a bare `x = 1` assigns to an existing variable** — the one thing this language cannot do.
Unmarked, it puts mutation in a C# reader's head at exactly the site the language forbids it, and
`var x = 1` reads as *introduce x*, which is what it is. `var` meaning "infer the type" is also
literally correct here, where everything is inferred.

`var (a, b) = point;` is **real C# deconstruction syntax**, so this moves the destructuring bind
from an invention to a tier-1 borrow. Today's `(a, b) = p` is *not* C#: there it assigns to
pre-existing variables.

**Measured 2026-08-15**, three grammar variants through yecc:

| Rule | Conflicts |
|---|---|
| today — `binding -> expr '=' expr`, narrowed by `to_pattern/1` | clean |
| `binding -> pattern '=' expr` (no marker) | **15 reduce/reduce, yecc refuses to generate** |
| `binding -> 'var' pattern '=' expr` + bare `expr '=' expr` | **clean** |

So `var` is not only free, it **pays**: the marker is what lets the parser take a *pattern*
directly, which deletes `to_pattern/1` and the parse-wider-then-narrow workaround that exists only
because one token of lookahead cannot tell `(a, b) = pair` from the tuple `(a, b)`.

`var` is free in the corpus too: **zero occurrences** as an identifier anywhere.

### 2. `=` without `var` is a match, and never introduces a name

```csharp
x = 1                  // ERROR: introduces x. Write `var x = 1`
1 = x                  // fine — asserts, introduces nothing
(1, 2) = pair          // fine
(a, b) = pair          // ERROR: introduces a and b. Write `var (a, b) = pair`
```

This is already the semantics — David, 2026-08-15: *"x = 1 / 1 = x //no error / 2 = x //error"* —
and it already works, pinned by three tests in `body_check_tests.erl`. What F8 changes is only that
**a binding must say it is one.**

### 3. A NAME in a pattern is a value, not a new binding — and this is what the feature is for

Today this is an error:

```csharp
var expected = Compute()
msg switch {
    == expected => :hit,   // today: error, `expected` is bound twice
    _           => :miss
}
```

So **beam-sharp cannot match against a value computed at run time.** That is the capability
Elixir's `^` exists to provide — David, 2026-08-15: *"Elixir's bind and ^ pin is for a reason, it's
to bypass matching/binding"* — and Erlang has it for free, because a bound variable in an Erlang
pattern *is* a match. beam-sharp, having no rebinding, is in Erlang's position and gets nothing.

The shape that wants it is a reduce whose accumulator is *tested* rather than rebound:

```csharp
Step(acc, items) -> items switch {
    []                 => acc,
    [== acc, ..rest]   => Step(acc, rest),      // the same value again
    [var next, ..rest] => Step(next, rest)      // something new
}
```

**Rewritten 2026-08-16 into the token ticket 45 chose.** As first drafted this block wrote the
second arm `[acc, ..rest]` — a *bare* name meaning "the same value again", which is pin-by-default
and is the rule David did **not** pick. The heading above it says a name in a pattern is a value;
read it as *the capability* this feature supplies, not as the spelling. The spelling is `== acc`,
and a bare name still introduces.

**The workaround is worse than it looks.** Binding a fresh name and testing it in a guard moves a
*pattern* concern into a guard — and the checker translates `var == literal` but **not**
`var == var`, so the guard credits nothing and the arm subtracts nothing from the residual. The
capability is not merely awkward to express, it is expressible only by giving up the guarantee.

## The token — RESOLVED 2026-08-16, and it is `==`

**Ticket 45 answered it: `== name`.** The recommendation below stood, and what the ticket added is
that it no longer rests on readability — it was measured. One grammar rule
(`pattern -> '==' lident`), **no lexer change**, yecc clean against a control that reproduces this
file's own recorded 15 reduce/reduce to the number. It parses in every pattern position **including
nested at depth**, which strikes an item off *Out of scope* below. `>= acc` and `== 4` were both
measured as *not* arriving with it, and both as clean if ever deliberately added.

**Read ticket 45's compiler delta before starting** — it is stated against the shipped source, so
there is nothing here to design. And read its last finding first: **`bs_repl` implements the
opposite rule**, and says so in a confident comment. See F8.8.

The section below is kept as raised, because the candidates and their collisions are the record of
why `==` won.

## The token — as it was raised

**Decided: mark the *match*, with one token, and not `^`.** (David, 2026-08-15.) The reasoning is
frequency: you only need to mark one of the two cases, and you mark the rare one. Binding is
overwhelmingly the common case here — every clause head, every switch arm — so Elixir marking the
*match* is the right call and marking the bind inside patterns would be the expensive inverse.

**Not `^`**, because since C# 8 it is the index-from-end operator (`arr[^1]`). Putting a tier-2
spelling on top of a live tier-1 meaning is worse than a tie, and the borrow heuristic's amendment
is explicit that the tiers rank *sources*, not precedence.

**C# offers nothing to borrow here**, which is why this lands in tier 3, invent-and-say-so: C#
patterns cannot match a runtime value at all, and push you to `when v == expected`.

Candidates, with what each collides with. **The feature must not start until one is chosen.**

| Candidate | Reads as | Collides with |
|---|---|---|
| `==acc` | "equal to acc" | nothing in pattern position. Reuses the language's own exact-equality spelling (16: `==` means `=:=`), and adds no lexer token |
| `^acc` | Elixir's pin | **C# 8 index-from-end.** Refused above |
| `$acc` | a substitution | C# interpolated strings, which `string` will want |
| `&acc` | a capture | C#'s bitwise-and and Elixir's capture operator |
| `~acc` | a sigil | Elixir sigils; free in C# except bitwise-complement |
| `same acc` | plain English | nothing — but a keyword for a one-character job |

**Recommendation: `==acc`.** It is the only candidate that borrows a spelling the language already
has, with the meaning it already has, and needs no new token in the lexer. `[==acc, ..rest]` says
*an element equal to acc*, which is exactly what it does.

**RAISED AS A TICKET AT LAST — 2026-08-15.** This section named a decision the file *"must not
make"* and no ticket existed for it, which is the same gap that stalled F2: a blocker recorded in
prose, in one file, where no query could find it. It is now
[ticket 45](../../wayfinder/issues/45-match-token.md) ·
[ENG-216](https://linear.app/davewil/issue/ENG-216).

**And the recommendation got materially stronger the same day, from a ticket that has nothing to do
with this one.** [Ticket 42](../../wayfinder/issues/42-interval-pattern-spelling.md) put
**relational patterns** in the parameter position, so a pattern may now be `>= 4`, `<= 7` or
`>= 4 and <= 7`. Before that, `==acc` would have been the only operator-shaped thing in a pattern —
a lone oddity needing its own explanation. After it, `== acc` is simply the **equality member of a
family that already exists**, and a reader who has met `>= 4` in a head reads it on sight.

Note also what 42's rule says about it: C#'s relational patterns are `<`, `>`, `<=`, `>=` and
**`==` is not among them**, because C# writes a constant pattern bare. So `== acc` is not a borrow
at all — it is this language extending its own relational family to reach a case C# cannot express,
carrying the meaning `==` already has here (ticket 16: `==` is `=:=`). Tier 3, and the safe kind:
no glyph is being taken from a language that uses it for something else.

## Scenarios

### F8.1 — `var` binds, and the parser takes a pattern

`var x = 1` and `var (a, b) = Split(lines)` both compile and run. Asserted by **parse**, not by
conflict count — F6.9's rule, since yecc resolves shift/reduce silently through the precedence
table.

### F8.2 — `to_pattern/1` is gone

The narrowing action and its twelve-conflict comment are deleted, and `binding -> 'var' pattern
'=' expr` reads the pattern directly. This is the scenario that says `var` paid rather than cost.

### F8.3 — a bare `=` that would introduce a name is an error, and says what to write

`x = 1` → *"introduces x — write `var x = 1`"*. `(a, b) = p` likewise. The message names the fix,
which is F4.7's rule.

### F8.4 — a bare `=` that introduces nothing still matches

`1 = x` compiles; `2 = x` is an error whose residual is `1`. Both already hold; this scenario pins
them against the grammar change rather than re-deciding them.

### F8.5 — a name in a pattern matches the value it holds

The `expected` switch above compiles, and `Step` reduces. This is the capability.

### F8.6 — **a matched name credits NOTHING to `Certain`**

The soundness heart of the feature, and the place it can go quietly wrong.

A matched name is a value test whose value the compiler **does not know**. So it is *inexact* in
exactly `clause_type/2`'s sense — like `[0, ..t]`, which is not every non-empty list — and it may
bound `Possible` while crediting **nothing** to `Certain`. Credit it and the compiler claims
coverage it does not have, which is the one failure the whole project exists to rule out.

The control is a switch whose only non-catch-all arm matches a name: it must report **inexhaustive**,
with the residual the subject's whole type. A build that credits the arm reports exhaustive and is
silently wrong — so this scenario asserts an error the wrong build **omits**, which is F5.7 and
F7.14's shape a third time.

### F8.7 — a matched name's type narrows the pattern

`[acc, ..rest]` where `acc` is `int` should give the arm an element type of `int`, not `term`.
`pattern_type/3` answers `term` for every `p_var` today and has no case for a name that is already
in scope. Named because it is the one place the checker learns something new rather than being
rearranged.

### F8.8 — the prompt and the compiler agree

They do **not** today, and F8 is what fixes it. `bs_repl` gained pin-by-default on 2026-08-15
(a bound name in a pattern matches) while the compiler still errors — so the same three lines
behave differently in a file and at `ibs`. One rule, both surfaces, asserted in `repl_tests` and in
`body_check_tests`.

**And ticket 45 settled WHICH surface moves, which this scenario did not say: `bs_repl` does.**
`src/bs_repl.erl:193–197` matches a bare bound name, under a comment asserting *"the language needs
no `^`: there is nothing to disambiguate."* That comment is now wrong and is the single most
misleading artefact in the way of building this feature — it is confident, it is in shipped source,
and it argues the whole question away. **Delete the claim as well as the behaviour.** A bare name
introduces; `== name` matches. If a bare name also matched, `== name` would be a second spelling for
something already spelled, which is the exact ground ticket 45 refused `== 4` on.

Note the scope line: 45 asserts only that a bare bound name is **not a match** at the prompt. Whether
the prompt should then *bind* it or *error* is ticket 34's question, and this scenario must pick the
same answer the compiler picks — that being the entire point of the scenario.

### F8.9 — the corpus is rewritten and every gate is green

Every `.bs` in `examples/` and `examples/exemplars/`, every compiled block in `LANGUAGE.md`, and
`bin/check-language.sh`'s bidirectional check. This is the largest mechanical part of the feature
and the reason it goes ahead of binaries.

## Out of scope

- **`Order o = expr`**, the typed binding David typed on 2026-08-14. Measured: **6 reduce/reduce**,
  and `var` does not fix it — a tuple *type* `(int, int)` and a tuple *expression* `(1, 2)` are
  indistinguishable at `(`. Recoverable by restricting the typed form to non-tuple types, which is
  a readability decision nobody has made.
- ~~**A pin *inside* nested patterns at arbitrary depth.**~~ **BACK IN SCOPE — ticket 45 measured
  it.** `({ Kind: == k }, x)` parses. Depth was never a separate question: `== name` is a `pattern`,
  and `pattern` is already recursive through every compound form. It only looked like one while
  nobody had run it, which is the cost of writing *unmeasured* instead of measuring.
- **Rebinding.** Still an error. This feature does not reopen ticket 34.
- **`^` as the token.** Refused above, with its C# collision.

## Done when

`var` binds and is required to; a bare `=` matches and refuses to introduce; a name in a pattern
matches the value it holds and credits nothing to `Certain`; the prompt and the compiler give the
same answer to the same three lines; `to_pattern/1` is deleted; and every gate is green over a
rewritten corpus.

**The token is chosen: `==`.** Ticket 45 resolved it on 2026-08-16, so this file is buildable. The
sentence it was gated behind stands as the rule that produced the gate — a spelling every future
`.bs` file carries is a decision, not a feature — and the gate did its job: the ticket found two
things this file had wrong (nested depth was measurable all along, and F8.5's own example was
written in the rule David did not pick).
