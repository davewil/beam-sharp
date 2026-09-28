# 112 — How does B# build a string? Template strings, and what `+` takes

Type: grilling
Status: claimed — [ENG-555](https://linear.app/davewil/issue/ENG-555). Q2 answered 2026-09-28; round 3 open. Raised 2026-09-28 out of
[ENG-551](https://linear.app/davewil/issue/ENG-551)
Blocked by: —

## Why this is raised

[25](25-exemplar-programs.md) finding 5 records `+` over two strings as *"decided, not broken"*:
[33](33-body-check-site.md) §2 enumerated five obligation sites, with *"no sixth because `e_op`
… declare[s] nothing"*, so an operator's operands are not checked and the BEAM raises `badarith`.
F5's *Out of scope* says the same: *"`:a + 1` synthesises `int` and is not rejected"*.

That frame has since moved. [80](80-does-an-int-flow-where-a-float-is-expected.md) put a refusal at
the operator (`mixed_operands`, an `int` beside a `float`), and
[83](83-a-union-operand-at-an-operator.md) put another there (an `int | float` operand). So the
operator already checks its operands, and only the case with no numeric part at all was left out.
The Signalbox porting check (ENG-551) hit that case in the program it was porting.

Measured at `54686d6`. Elixir's `Evidence.model_key/1` joins five identity fields with `/`, and the
program a C# reader writes for it is:

```csharp
module Evidence

record ModelIdentity { Lab: string, Model: string, Harness: string }

public string ModelKey(ModelIdentity id)
ModelKey(id) -> id.Lab + "/" + id.Model + "/" + id.Harness
```

```
Evidence/Evidence.bs:6:1: error: ModelKey returns a value its signature does not declare
  not covered by the declared return type:
    int
  If `string` is what you meant, fix the clause, not the signature.
  Otherwise, the signature its clauses justify:
    public string | int ModelKey(ModelIdentity id)
```

The refusal is at the wrong place, and its advice is the defect. Paste the offered signature and
the program compiles, then crashes: `crashed: error:badarith`. The rest compile silently:

| Program | Today |
|---|---|
| `public int Glue(string a, string b)` / `Glue(a, b) -> a + b` | compiles, `badarith` |
| `Bump(atom a) -> a + 1` | compiles |
| `Bump(Order o) -> o + 1`, `Order` a record | compiles |
| `Both(list<int> a, list<int> b) -> a - b` | compiles |
| `Big(s) when s + 1 > 3 -> :big` over `string s` | compiles; the guard is silently false |

## Round 1 (asked 2026-09-28, reframed before it was answered)

David, on reading it: *"I think the issue we're looking at here is how 'template' strings are
implemented. Take a look at Erlang/Elixir/Gleam/C#/TS for inspiration."* The survey is
[research 112](../research/112-template-strings.md). Round 1's question is kept below as asked. It
comes back as Round 3's Q4, because its only contested case, `string`, turns on whether
B# has another way to join strings.

**Q1 (not answered). Is an operand of `+ - * / %` with no `int` or `float` part refused?**

Under **yes**, `ModelKey` is refused at the operator, naming the operand and its type. The wording
is proposed; nothing prints it yet:

```
Evidence/Evidence.bs:6:23: error: ModelKey applies + to a string
  + takes an int or a float on each side; this operand has neither part:
    string
```

The same refusal fires for `a + 1` over an `atom`, `o + 1` over a record, `a - b` over two lists,
and `s + 1` in a guard. Every row in the table above stops compiling. None of them ran without
crashing (or, in the guard, without being silently false), so no working program breaks.
[25](25-exemplar-programs.md) finding 5 and F5's out-of-scope line are then amended.

Under **no**, 25 finding 5 stands. Every row compiles as it does today, and `ModelKey` keeps the
diagnostic above, whose advice compiles into a crash.

**The compiler delta under *yes*.**

- `bs_check:op_result/5`: before `union_result/5`, an arithmetic operator (`+ - * / %`, not a
  comparison, `and` or `or`) refuses an operand whose type meets neither `int` nor `float`, with
  a new `non_numeric_operand` carrying the operator, the side and the operand's type. It answers
  `reported()`, so the return check stops reporting the `int` it used to invent.
- The guard sites. A guard is read, never typed, so an operator-level refusal reaches a guard only
  where it is asked in `walk/6` for a clause and in `arms/10` for a switch arm, against the
  pre-guard domain. F51's `mixed_operands` missed the switch arm the first time.
- `bs_diag` gets the message and the JSON payload. Tests go through the CLI: each row above, the
  guard in a clause and in a switch arm, and `Evidence` itself. `LANGUAGE.md` §4 *Arithmetic on
  `int`* gets a `diagnoses: non_numeric_operand` block, seen red first.
- The emitter does not change.

**The compiler delta under *no*.** None. `op_type/1` goes on answering `int` for an operator
whose operands have no numeric part.

➡️ **Recommended: yes.**

- 33 §2's reason was that `e_op` declares nothing. Since 80 and 83 the operator does declare what
  it takes, and refuses the two other ways to get it wrong, so the operand with no numeric part is
  the one case the rule no longer explains.
- A well-typed program crashing on an operation the checker accepted is what the type system
  exists to prevent. And today the compiler's own advice leads an author into that crash.
- Nothing that runs today stops compiling.

## Round 2

The survey's finding ([research 112](../research/112-template-strings.md), *Comparison*): all five
languages build a template string by flat concatenation, and on the BEAM Elixir's `"#{x}"` and
Gleam's `<>` both lower to one binary construction. Erlang has no interpolation (EEP 62's pull
request stalled on 2023-09-13), and neither has Gleam (issue 1473 closed, to "see how far we get
with `<>`"). C# has `$"…{x}…"`, whose braces are also C#'s block and initialiser braces, as B#'s
are. A literal brace is written `{{`. B# set `$` aside for exactly this form when the match token
was chosen ([45](45-match-token.md)). Today `$` is not a token at all, and a `{` inside a string
literal is an ordinary character, so the form is additive. Nothing that builds a string is built:
`String.FromInt` ([97](97-conversions.md), ENG-462) and `List.Join` ([96](96-standard-environment-breadth.md),
ENG-454) are both unbuilt, and binary construction ([90](90-building-a-binary.md)) is open.

**Q2. Does B# build a string with C#'s `$"…{expr}…"`?**

The Signalbox model key, written with one:

```csharp
module Evidence

record ModelIdentity { Lab: string, Model: string, Harness: string }

public string ModelKey(ModelIdentity id)
ModelKey(id) -> $"{id.Lab}/{id.Model}/{id.Harness}"
```

Under **yes**, this compiles and `ModelKey` returns `"-/glm-5.2/opencode"`. It lowers to one
binary construction, the form Elixir and Gleam emit (measured with `erlc`):

```erlang
'ModelKey'(Id) ->
    <<(maps:get('Lab', Id))/binary, "/", (maps:get('Model', Id))/binary,
      "/", (maps:get('Harness', Id))/binary>>.
```

Every hole in this program is a `string`. Joining valid UTF-8 gives valid UTF-8, so the result is
a `string` with no run-time check. A hole that is not a binary makes that construction crash with
`badarg` (measured), so the checker proves each hole's type before emitting it. Which types a hole
takes is Round 3's Q3. Until then this answer gives `string` holes only, the position Gleam's 2022
plan took.

Under **no**, `$` stays unused and this line is a syntax error. The key is written
`List.Join([id.Lab, id.Model, id.Harness], "/")` once ENG-454 builds that row. Nothing compiles
today.

**The compiler delta under *yes*.**

- **Lexer.** `$"` opens an interpolated string. Its text is scanned into literal segments and
  holes: `{{` and `}}` are literal braces, `\` escapes are as in a plain string, and each hole's
  source is lexed as tokens. A hole has to balance its braces and skip any string literal inside
  it, which one `leex` regex cannot do, so the rule's action hands the text to a small scanner in
  `bs_lexer.xrl`'s code section. The token is `{interp, Line, Parts}`.
- **Parser.** `expr -> interp`. Each hole's tokens are parsed as an expression, which gives
  `{e_interp, L, [{text, Bin} | {hole, Expr}]}`. The `yecc` conflict count is measured before and
  after.
- **Checker.** `type_of(e_interp)` checks each hole against `string` and answers `string`. The
  pieces `with` and construction already use cover it: a hole is an obligation like a call
  argument, and its residual prints the same way.
- **Emitter.** One `{bin, L, …}`, with a text segment as a `/binary` literal and a hole as
  `(Expr)/binary`.
- **Editor.** tree-sitter needs an external scanner for the holes, as its JavaScript grammar has
  for template literals. Also highlighting in the three editors.
- **Docs and tests.** A `LANGUAGE.md` §4 block and CLI tests: the Signalbox key, a literal brace, a
  refused `int` hole, and a hole in a guard, if Round 3 admits one.

➡️ **Recommended: yes.** It is C#'s own form, so it passes the borrow heuristic's first step
without inventing anything. B# reserved the `$` for it. On the BEAM it costs one binary
construction, the same code Elixir and Gleam emit. It is also the one place a string gets built
where a reader sees the result's shape, which `List.Join` does not show.

**A2 (David, 2026-09-28):** *"yes"*. B# builds a string with `$"…{expr}…"`, which lowers to one
binary construction. `{{` and `}}` write a literal brace. Until Q3 is answered, a hole takes a
`string` only.

## Round 3

Asked 2026-09-28. Q3 and Q4 are independent, so they are asked together. The fog below them waits
on Q3.

**Q3. Does a hole take an `int` as it stands, with no conversion written?**

A receipt line, from a program that stores money as pence:

```csharp
record Order { Id: int, Customer: string, Total: int, Status: :placed | :paid }

public string Line(Order o)
Line(o) -> $"Order {o.Id} for {o.Customer}: {o.Total} pence, {o.Status}"
```

Under **yes**, this compiles and returns `"Order 42 for Ada: 1250 pence, placed"`. Each hole's
conversion is chosen at compile time from its type, one per part, and each is total, so a hole
never fails at run time (measured on OTP 28):

| hole's type | lowered to | e.g. |
|---|---|---|
| `string` | `(E)/binary` | as written |
| `int` | `(integer_to_binary(E))/binary` | `-5` → `"-5"` |
| `float` | `(float_to_binary(E, [short]))/binary` | `0.1` → `"0.1"`, `2.0` → `"2.0"` |
| an atom type | `(atom_to_binary(E))/binary` | `:placed` → `"placed"` |

A hole of any other type is refused at compile time: a record, a tuple, a list, a map, `term`, or a
union spanning two of the parts above. This is C#'s position, where any value converts, narrowed to
the parts that print one obvious way. It is a fixed table read from the hole's static type, as
`op_result/5` reads its operands. It is not a protocol, so ticket 16 is not reopened.

Under **no**, only a `string` fills a hole, which is Gleam's 2022 plan. The line becomes:

```csharp
Line(o) -> $"Order {String.FromInt(o.Id)} for {o.Customer}: {String.FromInt(o.Total)} pence, {String.FromAtom(o.Status)}"
```

That waits on ticket 97's rows (ENG-462, unbuilt), and until they land every numeric hole goes
through the FFI. Written as it stands, `{o.Id}` is refused, naming `String.FromInt`.

**The compiler delta under *yes*.** `type_of(e_interp)` classifies each hole's type as one of the
four parts, or refuses it with a new `interp_hole` diagnostic naming the type and the parts a hole
takes. The emitter picks the lowering from the table above. The tests cover each part, a refused
record, and a refused `int | float` hole. Under *no*, the same diagnostic fires for anything but
`string`, and its advice names ticket 97's conversion for the type.

➡️ **Recommended: yes.** C# is the first source the borrow heuristic surveys, and C# converts.
Every part in the table prints one obvious way through a total BEAM BIF, so the author loses
nothing by not writing the conversion. The line under *no* repeats `String.From…` in every hole
and waits on an unbuilt row.

**Q4. Is an operand of `+ - * / %` with no `int` or `float` part refused?**

This is Round 1's Q1, asked again now that Q2 has given B# a way to build a string. It is the
program, delta and recommendation above. The one change is the refusal's advice for a string
operand, which can now name the repair:

```
Evidence/Evidence.bs:6:23: error: ModelKey applies + to a string
  + takes an int or a float on each side; this operand has neither part:
    string
  build a string with a template: $"{id.Lab}/{id.Model}"
```

Under *no*, `id.Lab + "/" + id.Model` keeps compiling into the `badarith` crash and the
`string | int` advice. With Q2 answered, `+` does not need to join strings: in C#, `a + "/" + b`
and `$"{a}/{b}"` emit the same `String.Concat` (research 112).

➡️ **Recommended: yes**, for Round 1's reasons, and now the refusal can name the repair.

**Fog, after Q3.** Whether a template may be a pattern (`$"order-{rest}"`, the BEAM's
literal-prefix match), format specifiers (`{o.Total:F2}`, C#'s alignment and format), and an
iodata builder (25e's `Iodata`).

## Not decided here

- **An operand with a numeric part and another part**, `int | :none` or `term`. It compiles today,
  and [83](83-a-union-operand-at-an-operator.md) scoped it out. Q1 and Q4 are about an operand with *no*
  numeric part.
- **Comparison operators.** `<` over two strings is the BEAM's term order and does not crash.
