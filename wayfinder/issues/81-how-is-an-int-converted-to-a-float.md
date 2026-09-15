# 81 — How is an `int` converted to a `float`: C#'s cast, or an entry under a reserved qualifier?

Type: grilling
Status: resolved 2026-09-15 — [ENG-380](https://linear.app/davewil/issue/ENG-380). Raised 2026-09-15 on resolving
[ticket 80](80-does-an-int-flow-where-a-float-is-expected.md), at David's request, the same turn;
one question, one round, answered seven minutes later
Blocked by: —

## Why this is raised now

Ticket 80 took the BEAM's reading: `int` and `float` are two parts and nothing flows between
them. Every `int` that meets a `float` is therefore converted where the author says so, and today
the only spelling is a foreign declaration, `using :erlang { float float(int x) }`, then
`:erlang.float(n)` at the site. The rule is right and the spelling is the whole of its cost, so
the spelling gets its ticket the day the rule is decided.

**Why a conversion is needed at all — David, 2026-09-15, *"why do I need `:erlang.float`?"*** Not
because of ticket 80. Because of [ticket 38](38-division-and-modulo.md): `/` on two `int`s is
`div`, C#'s operand-typed division, so `List.Sum(xs) / List.Length(xs)` over a `list<int>` is an
`int`, truncated, whatever the declared return. C# needs the same conversion in the same place —
`(double) xs.Sum() / xs.Count` — and Erlang does not, because Erlang's `/` is always float
division, the reading 38 refused so that `-7 / 2` stays `-3`. Under ticket 80 the conversion
cannot be smuggled through a literal either: `List.Sum(xs) / 1.0` is a mixed pair at an operator,
refused. So one operand is converted, on purpose, in the source. **`:erlang.float` is only
*which* spelling, and it is the one nobody chose.** That is this ticket.

## What is already decided, and is not reopened here

- **Nothing unqualified is a function** ([67](67-stdlib-shape-as-a-principle.md)): a bare
  `Float(n)` or `ToFloat(n)` is not on the table. A compiler-known operation lives under a
  reserved qualifier — `List`, `Map`, `Term` today, `bs_check:reserved_qualifiers/0` — and is
  inlined at the site; a user module of that name is refused at the call site (47's rule).
- **`raise` is grammar, not a name** (67, correcting 15). So a form can be grammar when a
  keyword or an operator is what C# has; the question is which of the two this is.
- **The lowering is `erlang:float/1`** under either spelling; the platform has one conversion.

## The program

```csharp
module Stats

public float Mean(list<int> samples)

Mean([]) -> 0.0
Mean(xs) -> ⟨convert⟩(List.Sum(xs)) / ⟨convert⟩(List.Length(xs))

public atom Verdict(float mean)

Verdict(0.0) -> :empty
Verdict(_)   -> :some

public atom Check(list<int> xs)

Check(xs) -> Verdict(⟨convert⟩(List.Length(xs)))
```

Three sites, two of them inside an expression and one an argument. `⟨convert⟩` is the thing to
spell.

## Round 1 (2026-09-15)

**Q1. Which of these two programs is the language's?**

**C#'s spelling — a cast, and it is grammar:**

```csharp
Mean(xs)  -> (float) List.Sum(xs) / (float) List.Length(xs)
Check(xs) -> Verdict((float) List.Length(xs))
```

The compiler delta: `bs_parser.yrl` gains `'(' type ')' expr` as a prefix form, in the one place
the grammar already carries its worst conflict — the parenthesis is shared by the tuple, the
parenthesised expression and the lambda's parameter list (the parser's own comment at the tuple
rule counts *21 reduce/reduce* resolved there), and `(float) x` against `(x)` and `(a, b)` is
decided only by what follows the `)`. **Yecc conflicts are measured, not inferred**: the report
before and after is part of the delta. `bs_check` gains a cast node whose operand must be `int`
and whose type is `float`; a `float` cast of a `float` is refused as a no-op, and `(int) f` is
refused with a reason, because C#'s `(int) 3.7` truncates and the BEAM has `trunc/1` and
`round/1` both — that direction is a second question, gated. `bs_emit` lowers to
`erlang:float(X)`. The tree-sitter grammar and the LSP gain the form. `LANGUAGE.md` gains a
section, since a cast is syntax and the shipping document enumerates syntax.

**The BEAM's spelling — an entry under a reserved qualifier, and it is a call:**

```csharp
Mean(xs)  -> Float.Of(List.Sum(xs)) / Float.Of(List.Length(xs))
Check(xs) -> Verdict(Float.Of(List.Length(xs)))
```

The compiler delta: `Float` joins `reserved_qualifiers/0`; `{'Float', 'Of', 1}` joins
`reserved_table/0` with `reserved_sig` `int -> float`; the emitter's existing inlining of a
reserved call writes `erlang:float(X)` at the site, no beam shipped, exactly as `List.Sum`
is written today. No grammar change, no yecc report, no editor work: `Float.Of(x)` already
parses as a qualified call. `STANDARD-ENVIRONMENT.md` gains a row so `check-status-claims.sh`
has a status to read; a user module named `Float` is refused at the call site by the rule that
refuses one named `List`. The name is the survey's: Gleam writes `int.to_float(n)` on the source
type's module, C# writes `Convert.ToDouble(n)` on a converter; `Float.Of` puts it on the target
type, which is where `Term.Compare` and `Map.Get` put theirs. If the qualifier is right and the
member is not, the member is the round-2 question, not this one.

**One question.** Grammar, C#'s cast, paid for in the parser's most crowded parenthesis and
opening the `(int)` direction as a second decision — or an entry, the BEAM's call, paid for in a
table row and a document row and leaving the reverse direction to be asked as a name.

Under the first, round 2 asks what `(int) f` does. Under the second, round 2 asks whether
`Int.Of(f)` exists and which of `trunc` and `round` it is, or whether both are spelled.

**A1 — the entry, and the member is `FromInt`** (David, 2026-09-15 19:37 and 19:38: *"I think I'm
leaning towards `Float.Of` even if a C# developer would expect a cast"*, then *"`Float.FromInt`
then"*, on the point that C#'s own convention for *make an X from a Y* is `X.FromY`).

## The answer

`Float.FromInt(n)`: a compiler-known entry under the reserved qualifier `Float`, `int -> float`,
inlined at the site as `erlang:float(X)`, no beam shipped, the way `List.Sum` is built. Not a
cast.

```csharp
public float Mean(list<int> samples)

Mean([]) -> 0.0
Mean(xs) -> Float.FromInt(List.Sum(xs)) / Float.FromInt(List.Length(xs))

public atom Check(list<int> xs)

Check(xs) -> Verdict(Float.FromInt(List.Length(xs)))
```

Two things decided the shape, and one the name:

- **A cast is a family, and the family lies.** C#'s `(float) n` is the same syntax as `(int) 3.7`,
  which truncates, and `(byte) 300`, which wraps. A developer who saw `(float)` in B# would assume
  `(int)` and be owed either a silent truncation or a refusal that surprises more than the missing
  cast did. An entry promises nothing about the reverse direction; the reverse gets its own name
  with its own meaning, which is what the BEAM has (`trunc/1` and `round/1` are both real).
- **The entry costs a table row; the cast costs the parser's worst parenthesis.** One row in
  `reserved_table/0`, one in `STANDARD-ENVIRONMENT.md`, no grammar, no yecc report, no editor
  work.
- **The name is C#'s convention, so the C# developer's expectation is met in the member**:
  `TimeSpan.FromSeconds`, `Task.FromResult`, `Color.FromArgb`. `Float.Of` reads as Java or
  Kotlin. The reverse direction, when it is asked, is `Int.FromFloat` by the same convention, and
  that name is where truncate-or-round gets decided.

### What follows

- [ENG-378](https://linear.app/davewil/issue/ENG-378), the float build, ships the entry with the
  type: `Float` joins `reserved_qualifiers/0`, `{'Float', 'FromInt', 1}` joins `reserved_table/0`
  with the signature `int -> float`, the emitter inlines `erlang:float/1`, and a user module named
  `Float` is refused at the call site by the rule that refuses one named `List`. Its example
  program is rewritten to the entry.
- `STANDARD-ENVIRONMENT.md` gains the row now, **decided** and unbuilt, so `check-status-claims.sh`
  has a status to read; `CONTEXT.md`'s *reserved qualifier* entry names `Float`.
- The reverse direction is logged below with what it needs, and is asked when a program needs it.

## Decisions entry

<!-- This ticket's entry. Read whole, here; the map (ENG-165) carries one line. -->

```decisions-entry
- [How is an `int` converted to a `float`?](issues/81-how-is-an-int-converted-to-a-float.md) —
  **`Float.FromInt(n)`: a compiler-known entry under the reserved qualifier `Float`, `int -> float`,
  inlined as `erlang:float/1`; not a cast.** Raised and resolved 2026-09-15 in one round on one
  question, the spelling ticket 80's no-flow rule made necessary — and necessary at all only because
  38's `/` on two `int`s is `div`, so a mean over a `list<int>` converts an operand as C# does. The
  cast was refused because C#'s cast is a family whose other members truncate and wrap, so `(float)`
  would promise an `(int)` the BEAM cannot honour in one meaning, and because it would land in the
  grammar's most crowded parenthesis; the entry is one table row. The member follows C#'s
  `X.FromY` convention (`TimeSpan.FromSeconds`), which is where the C# developer's expectation is
  met instead. The reverse, `Int.FromFloat`, is named and not decided: truncate or round is asked
  when a program needs it. Ships with [ENG-378](https://linear.app/davewil/issue/ENG-378).
```

## Not decided here

- The reverse direction, `Int.FromFloat(f)` by the same convention: truncate (`trunc/1`), round
  (`round/1`), or two members. Deferred until a program in the corpus needs one; what it needs is
  the same row and the same inlining as `Float.FromInt`, plus the choice of BIF, which is the
  whole question.
- `Float.Parse`, `Float.ToString` and the rest of a `Float` qualifier's breadth. Breadth is out
  of scope by 67's rule; this ticket adds one row.
- Whether a `float` literal may be written where a `float` is expected from an `int` literal
  (F# 6's rule). Ticket 80 refused the general flow; the literal-only shape was named there as
  the round-2 question under the other answer and is not reopened here.
