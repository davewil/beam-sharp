# F66 — template strings: `$"Order {o.Id} for {o.Customer}"`

**Status**      **in progress** — 22 tests in `template_tests`, 1278 in the suite; F66.1–15 seen red before the build
                (`illegal characters "$"`), F66.16 the control that a plain string keeps its
                braces; the review's F66.17 red on `crashed: error:badarg`, F66.7's `Formattable`
                wording and F66.12's end-of-hole wording red on the first cut, F66.18–19 coverage
                of branches no test reached; F66.20–21 red before ticket 112 A5 let a hole span
                lines, with a fifth §4 block red against `fed3391`'s compiler; four `check-language.sh` blocks in LANGUAGE.md §4, all seen red against
                the base compiler (three `BROKEN`, the `diagnoses: interp_hole` block `WRONG DIAG`
                as `lex_error`); yecc 6 shift/reduce and 0 reduce/reduce before and after;
                tree-sitter parses a scratch file of six templates, one nested in another's hole,
                with no ERROR node; the `.abstr` of all 27 example modules is byte-identical
                before and after; `verify.sh` 47/47 twice from clean clones at `fed3391`
**Implements**  [ticket 112](../../wayfinder/issues/112-an-arithmetic-operand-with-no-numeric-part.md),
                A2 and A3, *The compiler delta, as decided*, item 1; A5 and A6, the build's two
                readings, which David answered in round 4. Decides nothing
**Closes**      [ENG-562](https://linear.app/davewil/issue/ENG-562)
**Depends on**  F9 (a string literal's escapes and its UTF-8 check, which a template's text reuses),
                F41 (guard rules), F51 (the guard-site typing a hole's part is read at)
**Unblocks**    [ENG-551](https://linear.app/davewil/issue/ENG-551), whose refusal of `string + string`
                names a template as the repair; [ENG-565](https://linear.app/davewil/issue/ENG-565),
                a record hole through `Formattable` (ticket 113)
**Leaves**      a template in pattern position, format specifiers and an iodata builder (ticket 112,
                *not decided*); a record hole, which is ENG-565; braces nested more than two deep
                inside a hole, the lexer's limit; the same file-and-position keying for `fdiv`, `vproj`,
                `pcall` and `fname`, whose collision the review found and ENG-576 carries

## The program

```csharp
module Evidence

record ModelIdentity { Lab: string, Model: string, Harness: string }

public string ModelKey(ModelIdentity id)
ModelKey(id) -> $"{id.Lab}/{id.Model}/{id.Harness}"
```

```csharp
module Receipts

record Order { Id: int, Customer: string, Total: int, Status: :placed | :paid }

public string Line(Order o)
Line(o) -> $"Order {o.Id} for {o.Customer}: {o.Total} pence, {o.Status}"
```

`ModelKey` returns `"-/glm-5.2/opencode"` and `Line` returns
`"Order 42 for Ada: 1250 pence, placed"`. `compiler/examples/Signalbox/model_key.bs` carries the
first beside a template with an atom hole and a literal brace.

## The rule

- `$"…"` is a template. Its text takes a plain string's escapes and its UTF-8 check. `{{` and `}}`
  write a literal brace, and a single `{` opens a hole, which holds one expression and closes at
  its matching `}`.
- A hole's type chooses how it prints, at compile time: `string` as written, `int` by
  `integer_to_binary`, `float` by `float_to_binary(F, [short])`, and an atom type by
  `atom_to_binary`. Any other type is refused (`interp_hole`), a union spanning two of those parts
  included, since there is no one lowering for it. The refusal's repair is a `switch`, one
  template per arm, which LANGUAGE.md §4 compiles. A record, or a union of records, is refused
  with the news that `Formattable` is not built (ticket 113, ENG-565), never that a record cannot
  print, and it is named as the author wrote it.
- The checker hands each hole's part to the emitter keyed by the hole's file and position: a module
  is a directory, so two files may hold a hole at one position.
- A template is a `string`, and it lowers to one binary construction: a text segment is its bytes
  and a hole is a `/binary` segment.
- In a guard, a template of `string` holes is legal, since a guard may build a binary. Any other
  hole is refused there under its own tag (`interp_in_guard`, ticket 112 A6), at all three guard
  sites: a clause, a switch arm and a comprehension's `when`.
- A hole may span lines, as C# 11's may (ticket 112 A5), and so may a template's text.

What the build read that no ticket spelled went to David as ticket 112's round 4, 2026-09-29:

- **`interp_in_guard` is its own tag** (A6, yes). `foreign_call_in_guard` would name
  `erlang.integer_to_binary`, a call the author never wrote.
- **A hole may span lines** (A5, yes). The build had limited a hole to one line; C# 11 allows the
  newline, and the delta was two characters in the lexer's hole macros. The cost, measured: a
  broken hole that a later `"}"` in the file happens to close is reported at its stray `"`, with
  the code in between quoted. Braces stay two deep inside a hole, a limit of the lexer: one leex
  rule has to match a template's whole extent (a pushed-back tail would be lexed at columns
  already advanced past it, and F35's positions would be wrong after it), and a regular
  expression counts braces only to a fixed depth. LANGUAGE.md states it as the lexer's limit.
- **A malformed template is refused by name** ("a template string closes with `"`, a hole is
  `{expr}`, …") rather than as `illegal characters "$"`. Like every lex error it is placed where
  leex stopped scanning, which for an unclosed template spanning lines is not the `$`. No call.
- **tree-sitter has no external scanner.** Ticket 112's delta expected one. The text is
  `token.immediate(prec(1, …))`, as tree-sitter-go lexes a string, and a hole is already a
  `template_hole` node holding an ordinary expression, the shape the scanner was for. No call.
- **The regex grammars (nvim, syntect, VS Code) colour no string, plain or template**, so
  Syntect shows `//example.com"` inside `"https://example.com"` as a comment. That is a defect,
  ENG-577. tree-sitter's `highlights.scm` colours both.

## Scenarios

| Id | Scenario | Expected |
|---|---|---|
| F66.1 | `ModelKey` over Signalbox's three strings; `id` is read only in holes | `"-/glm-5.2/opencode"` |
| F66.2 | `Line`: an `int`, a `string`, an `int` and an atom hole | `"Order 42 for Ada: 1250 pence, placed"` |
| F66.3 | `$"{i} {f} {g}"` over `-5`, `0.1`, `2.0` | `"-5 0.1 2.0"`: the shortest float that reads back, keeping `2.0`'s point |
| F66.4 | `$"{{x}} = {n}, a}}b"` | `"{x} = 3, a}b"` |
| F66.5 | a hole holding a `switch` whose arm matches the string `"}"` | one hole: `"<close>"` for `"}"`, `"<other>"` otherwise |
| F66.6 | `\"` in a template's text | the escape a plain string has |
| F66.7 | a record in a hole | refused, `interp_hole`, at the hole's `{` (line 4, column 20), not at the `$`; named `Money`, and told `Formattable` is not built; a union of `int \| float` is told to switch, not about `Formattable` |
| F66.8 | a hole of `int \| float`, of `list<int>`, and of `term` | refused, `interp_hole`, each |
| F66.9 | a clause guard comparing against a template of `string` holes | compiles, and selects the clause |
| F66.10 | an `int` hole in a clause guard, a switch arm's guard, and a comprehension's `when` | refused, `interp_in_guard`, at all three |
| F66.11 | `$"{}"`, `$"a}b"`, `$"a{n"`, and a template never closed | refused as a malformed template, by name |
| F66.12 | a hole that does not parse; a hole naming an unbound variable | a syntax error that says the hole ends before its expression does; `unbound_variable` |
| F66.13 | a byte that is not UTF-8 in a template's text | refused as a plain literal's is |
| F66.14 | `ModelKey` and `Line`, emitted | `ModelKey` is one `bin` and converts nothing; `Line` calls `integer_to_binary` twice and `atom_to_binary` once |
| F66.15 | the two new diagnostics on the term channel, in `--batch` and standalone | byte-identical (ENG-349) |
| F66.16 | `"{n}"`, a plain string | unchanged: a brace in a plain string is a character |
| F66.17 | two files of one module, each with a hole at the same line and column, one `int` and one `string` | each prints by its own part: `"7"`, not a `badarg` crash |
| F66.18 | a hole holding a character no token spells; an unknown escape in the text; non-UTF-8 text after the last hole | refused where the template is lexed, each by name |
| F66.19 | `$"n is {raise :boom}"`, a hole of type `none` | no `interp_hole`: it compiles and raises `boom` |
| F66.20 | `Summary`, a `switch` over the status in a hole spanning four lines (ticket 112 A5) | `"Order 42: paid, 1250 pence"` |
| F66.21 | a record hole nested in a `switch` on the third line of an outer hole, and a record hole on the line after the template | `interp_hole` at line 6, column 13, and at line 9 |
