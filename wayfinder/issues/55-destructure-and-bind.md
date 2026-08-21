# 55 — A pattern that destructures a record and binds the whole value

Type: grilling
Status: **resolved 2026-08-22** — [ENG-237](https://linear.app/davewil/issue/ENG-237). Raised and
answered the same day, from measuring the exemplar frontier. A record pattern may name its type and
any pattern may take a trailing binder; see [Answer](#answer). **Decided, not built** — the feature
must land the type prefix and the binder together or 25c's wall does not move
[FRONTIER](../../compiler/examples/exemplars/FRONTIER) · [25c](../prototypes/25c-event-queue-consumer.md)

## Question

`compiler/examples/exemplars/25c-event-queue-consumer/consume.bs:20` is the **front wall** of one of
ticket 25's three exemplars, and it has been unasked since the exemplars were extracted on
2026-08-13. The exemplar README lists it in the table of spellings the 2026-08-15 dialect rewrite
**could not reach**, owed by `unasked` — no repo file, no Linear issue. By the map's own rule that
*"a feature file naming a decision it needs is raising a ticket"*, its absence has been a live defect
for nine days.

The line:

```csharp
(Frame { Type = :method } f, rest) =>
    Dispatch(f)
```

It wants to do two things at once: **constrain** `Type` to `:method`, and **bind** the whole frame
to `f` so the body can pass it on. The compiler answers:

```
error: syntax error before: 'Frame'
```

## What the compiler has and has not got

**The mechanism is already built and already exercised.** `p_alias` is Erlang's `Var = Pattern` node
and it is live in the emitter — `bs_emit.erl:326` synthesises one whenever `ensure_var/3` is handed a
structural pattern it cannot name, and `bs_emit.erl:454` and `:538` lower and scan it. Every record
clause that dispatches on a tag already emits one. **There is no surface syntax that reaches it.**

So this is not a request for a capability. It is a request for a spelling, over codegen that ships
today.

## The exemplar's line is wrong twice more, and that is part of the question

`Frame { Type = :method } f` diverges from the current dialect in **three** places, and only the
third is open:

1. **`=` as the field separator.** Settled and not reopenable here: ticket 26 §2 split the
   separators — `=` assigns in construction and `with`, `:` matches in a pattern and declares in a
   type. The grammar has `assign_field -> uident '=' expr` and `pat_field -> uident ':' pattern`.
   The exemplar predates the split. It must read `Type: :method` after any rewrite.
2. **The leading `Frame`.** A record pattern today is **bare** — `pattern -> '{' pat_fields '}'` —
   and the grammar argues at line 480 that the tag is an ordinary field, so *"dispatching over a
   union of records needs no record-specific pattern form: `{ Kind: :'Shop.Order' }` is it."*
   Construction, by contrast, **does** name the type: `expr -> uident '{' assign_fields '}'`. So
   the language is already asymmetric here, and the exemplar takes the construction side.
3. **The trailing `f`.** The binder. Nothing in the grammar puts a name after a pattern.

**This matters for what "resolved" means.** `bsc` stops at the first error, so the diagnostic names
`Frame` — item 2 — and not the binder. **Answering the binder alone does not move 25c's wall**: the
parser would still choke on the type prefix. The two must land together or the frontier record does
not change, which is the same coupling 25c already recorded once for interval patterns and interval
refinements.

## The compiler delta each answer costs

**(a) Bare pattern, trailing binder** — `{ Type: :method } f`

```
pattern -> '{' pat_fields '}' lident
```

One production. The exemplar is rewritten to drop `Frame`. Keeps the grammar's existing claim that a
record pattern needs no type prefix, and keeps the tag as an ordinary field.

**(b) Type prefix and trailing binder** — `Frame { Type: :method } f`

```
pattern -> uident '{' pat_fields '}'
pattern -> uident '{' pat_fields '}' lident
```

Two productions, and a **checker** obligation the bare form does not have: `Frame` must be resolved
to a declared record and checked against the fields named, which is a new error class. It is C# 9's
`obj is Frame { Type: X } f` verbatim, and the audience is C#/TypeScript.

**(c) Binder on the left** — `f = Frame { Type: :method }`, Erlang's and Rust's side of the survey.
Costs the `=` token in pattern position, which F8 spent on *matching* (`= name` is ticket 45's
`p_eqvar`, and a bare `=` in a body is a binding). Likely a grammar conflict rather than a taste
question.

## What must be measured, not argued

- **The yecc conflict count**, before and after, by running `yecc:file/2` on both grammars. A quiet
  `rebar3 compile` proves nothing. The specific risk in (b): after `uident '{' uident`, the token
  that tells a pattern from a construction — `:` against `=` — is **two** tokens ahead, and yecc has
  one.
- **Whether `as` is available.** Gleam, F# and OCaml all spell this `... as f`. beam-sharp cannot
  assume it is free: the map records that `as` is taken for C#'s **checked conversion**, and that
  meaning is load-bearing for ticket 08's guard answer.
- **Whether the binder is reachable from `switch` as well as from a clause head.** 25c's use is in a
  switch arm, not a parameter list.

## Binding constraints

- **Ticket 26 §2's separator split is settled.** `:` matches, `=` assigns.
- **Ticket 45 gave `==` the match-a-bound-value meaning** and `=` was deliberately left out of
  pattern position. Answer (c) reopens that; it may not.
- **The borrow heuristic applies.** Survey C#, Erlang, Elixir and Gleam and take the most accurate
  word; C# does not win ties. Borrow the construct, or don't borrow the glyph — and **run it**.

## The survey — run, not reasoned

Four neighbours, four probes, all executed. Outputs are in the prototype headers.

| | Type named in the pattern? | Binder position | Binder spelling | Probe |
|---|---|---|---|---|
| **C# 9** | **optional** — both forms compile | after the pattern | bare designation, no keyword | [`55a`](../prototypes/55a_csharp_designation.cs) |
| **Erlang** | mandatory — `#frame{}` | **either** side of `=` | `=` | [`55b`](../prototypes/55b_erlang_alias.erl) |
| **Elixir** | mandatory — `%Frame{}` | **either** side of `=` | `=` | [`55c`](../prototypes/55c_elixir_alias.exs) |
| **Gleam** | mandatory — `Frame(..)` | after the pattern | `as` | [`55d`](../prototypes/55d_gleam_as.gleam) |
| **beam-sharp today** | **impossible** | — | — | — |

**The survey is unanimous on the point this ticket thought was the open one.** All four name the
type in the pattern; beam-sharp is the only one of the five that cannot. Erlang and Elixir have no
bare record pattern at all, and Elixir's nearest equivalent — `%{__struct__: Frame, type: :body}` —
requires hand-writing the struct tag, which is character-for-character the cost beam-sharp pays
today with `{ Kind: :'Shop.Frame' }`.

**It splits 2–2 on the binder**, and both sides are already spent here:

- `=` (Erlang, Elixir) is refused. Ticket 45 gave `==` the match-a-bound-value meaning and left `=`
  out of pattern position deliberately; F8 spent `=` on `var x = …` bindings. Answer (c) reopens a
  settled decision to buy nothing the other spellings do not.
- `as` (Gleam, and F#/OCaml behind it) is refused for a reason already on the map: **`as` is
  committed to C#'s checked conversion**, and that meaning is load-bearing for ticket 08's guard
  answer. It is not in the lexer today, which makes it look free; it is reserved, not free.

That leaves **C#'s bare trailing designation**, which is the audience's own spelling and the only
one of the three not already carrying a meaning.

Two probe results worth keeping beyond this ticket. C#'s designation binds the **whole** value, not
the projected field (`55a` case 3), and needs no `var` — `var` is only required for a var-pattern in
*field* position. And Erlang's alias works in a function head, a case, and **nested inside a tuple**
(`55b`), which is 25c's actual shape, so codegen constrains nothing here.

## The grammar, measured

[`55f_yecc_conflicts.sh`](../prototypes/55f_yecc_conflicts.sh). Baseline: `bs_parser.yrl` generates
with **zero** conflicts, which is what makes the test sharp.

| Variant | Spelling added | Conflicts |
|---|---|---|
| base | — | **0** |
| a | `{ Type: :method } f` | **0** |
| b | `Frame { Type: :method }` and `… f` | **0** |
| c | `f = Frame { … }` | **0**, and see below |
| d | b, plus the bare `Frame f` | **0** |

**The risk this ticket named is false.** The stated worry was that in (b), the token telling a
pattern from a record construction — `:` against `=` — sits two tokens past `uident '{' uident`
while yecc has one. It does not conflict. LALR item sets carry the distinction without needing the
lookahead, because `pattern` and `expr` are never both live in the same state.

**(c)'s zero is the one not to trust, and the self-test is why that is known.** `=` carries a
precedence declaration (`Nonassoc 50 '='`, `bs_parser.yrl:42`), and yecc resolves a conflict on a
token with a precedence **silently** — reporting nothing. So (c)'s measurement cannot tell "no
conflict" from "conflict silently resolved". (a), (b) and (d) touch only `'{'`, `'}'`, `uident` and
`lident`, none of which appear in the precedence block, so their zeros are real.

**That trap was found by the self-test failing, and it had already produced one wrong answer.** The
first control this script used was `pattern 'and' pattern`, which `bs_parser.yrl:366` predicts would
conflict — and it measured clean, which read as a blind harness. The harness was fine; `and` carries
`Left 200`. The control was rebuilt as a **reduce/reduce** conflict, which no precedence declaration
can resolve, and the harness then reported 7 of them while the untouched grammar measured 0 in the
same run. Both halves are required: a harness that fired on everything would have passed the red
check.

A second correction on the way there, and it is the same shape: the first version counted conflicts
by grepping for `shift/reduce conflict`, wording yecc never emits per site. It reports each site as
`Parse action conflict scanning symbol …` and the total once, as
`Warning: conflicts: A shift/reduce, B reduce/reduce`. The original grep would have read a grammar
riddled with conflicts as clean.

## Answer

**Variant (d): a record pattern may name its type, and any pattern may take a trailing binder.**
Five forms, of which only the last is what exists today:

```csharp
Frame { Type: :method } f      // type, constraints, and the whole value bound
Frame { Type: :method }        // type and constraints
Frame f                        // type and the whole value — LANGUAGE.md's own illustration
{ Type: :method } f            // bare, with the whole value bound
{ Type: :method }              // bare — unchanged, and still legal
```

**The type prefix is the half that carries the weight, and 25c is not the reason.** The reason is
that `{ Kind: :'Shop.Frame' }` asks a user to hand-write a **compiler-minted tag**, including a
fully-qualified module name, to say something as ordinary as *"this is a Frame"*. That atom is an
erasure detail: `bs_emit.erl` mints it and `tag_test/3` reads it back with `map_get`. Every
neighbour surveyed lets the type name stand in for it. This is the one place the language currently
makes an implementation detail load-bearing in source.

**And it is not a new question.** [`LANGUAGE.md:611`](../../LANGUAGE.md) has carried it since
records shipped — dispatch *"is written `Area({ Kind: :'Shapes.Circle' })`, not `Area(Circle c)`…
whether a sugar mirroring construction is added is a grammar-opinion question that is still open"* —
while the exemplar README carried the same gap under `unasked`. **Two files recorded the same
unasked question independently and neither raised it**, which is precisely the failure the map's
longest bullet is about. `Area(Circle c)` is variant (d)'s third form, so the reference's own
illustrative spelling is the one being made real.

**Why the trailing binder rather than a leading one**: the signature already reads *type then
binder* — `param -> type_prim lident`, so `Order o`. `Frame { Type: :method } f` is that same shape
with a constraint wedged into the middle, and `Frame f` in pattern position is character-identical
to the parameter a reader already knows. The two live in different nonterminals (`clause` takes
`patterns`, a signature takes `params`), so this is a consistency the grammar can afford — measured
at zero conflicts in variant (d).

**Answering the binder alone would not have moved 25c's wall**, and that is the coupling to respect
when this is built: `bsc` stops at the first error and the error is `Frame`, the type prefix. The
two land together or the frontier record does not move.

### What the compiler must gain

- **Grammar**: three productions, measured at zero conflicts (variant d).
- **AST**: a `p_rec` node carrying the type name, and a `p_bind` node wrapping any pattern with a
  name. `p_bind` lowers to the `p_alias` the emitter **already has** — no codegen work.
- **Checker**: one new obligation, and it is a new error class — `Frame` must resolve to a declared
  record, and the fields named must exist on it. This is the cost the bare form does not pay, and
  it is worth paying: it is the same check `Order{ Total = :oops }` already runs at construction,
  which F21 built on 2026-08-21.
- **Exhaustiveness**: a type-prefixed pattern must subtract exactly what `{ Kind: :'…' }` subtracts
  today, or the headline guarantee changes meaning. This is the half to write a failing test for
  first — ticket 54 is six days old and was exactly this shape.

### Not decided here

- **`Frame { }`** — an empty brace list. `Frame f` says it better and is in; whether the empty
  braces are also legal is left to the feature.
- **Nested binders** — `Frame { Payload: p } f` binds both a field and the whole. Erlang and Gleam
  both permit the nesting (`55b`, `55d` case 4); no exemplar asks for it, so it is not refused, just
  unbuilt.

## Notes
