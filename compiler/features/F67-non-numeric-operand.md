# F67 — an arithmetic operand with no numeric part is refused

**Status**      **in progress** — 25 tests in `non_numeric_operand_tests`, 1303 in the suite; F67.1–10
                seen red before the build (14 of 18 red, the four controls green), F67.3's record name
                and F67.6's type variable red on the first cut, F67.1's one-refusal count red on the
                first cut (the chain printed two), F67.11 green on its first run, there being no key
                collision to see, F67.12's program measured with the cascade on `747fff6`'s compiler;
                F67.13–15 red on the reviewed cut (`25b703c`), from `/code-review`'s findings, and
                F67.15's unary wording and F67.16 red on `02f1129`, from the second review's;
                `check-advice-compiles.sh` gained a template half, its self-test
                red on five stubs and green on the correct template, the gate red against `747fff6`'s
                compiler on T1, T2 and T3; a `diagnoses: non_numeric_operand` block in LANGUAGE.md §4,
                `WRONG DIAG` as `return_not_declared` against the base compiler; the `.abstr` and
                compile log of all 74 example files are byte-identical before and after
**Implements**  [ticket 112](../../wayfinder/issues/112-an-arithmetic-operand-with-no-numeric-part.md),
                A4, *The compiler delta, as decided*, item 2. Decides nothing
**Closes**      [ENG-551](https://linear.app/davewil/issue/ENG-551)
**Depends on**  F51 (the operator's refusals and the guard sites they reach), F53 (the numeric union,
                which stays its own refusal), F66 (the template this refusal's advice names)
**Leaves**      an operand with a numeric part beside another, `int | :none` or `term`, which is
                ticket 83's leave; an operand over a type variable, which is not refused, so
                `F<T>(T a) -> a + 1` still compiles and `F("x")` still raises `badarith`. That is
                not decided here: ticket 27 §2–3 make a variable opaque and unbounded and name
                arithmetic as a capability only a bound would grant, which reads as refusing it,
                while ticket 112's rule is written over concrete types. F67 keeps what compiled,
                and the question is [ticket 116](../../wayfinder/issues/116-arithmetic-over-a-type-variable.md),
                [ENG-579](https://linear.app/davewil/issue/ENG-579); the
                atom literal spelled like a variable in scope, `:'T'` in a function generic over
                `T`, which escapes the refusal and raises `badarith`, since F45 represents the
                variable as that same atom and the checker cannot tell them apart; a template for a chain whose operands are not names, one-level
                projections or plain literals, where the advice names the form without writing it;
                a parenthesised chain on the right, `"a" + (s + "b")`, which is advised the inner
                chain's template alone, since flattening it would reorder numeric additions C# does
                first

## The program

Signalbox's model key, as a C# reader writes it:

```csharp
module Evidence

record ModelIdentity { Lab: string, Model: string, Harness: string }

public string ModelKey(ModelIdentity id)
ModelKey(id) -> id.Lab + "/" + id.Model + "/" + id.Harness
```

Before F67 this was refused as returning an `int`, and offered `public string | int ModelKey(...)`,
which compiles and crashes with `badarith`. Now:

```
Evidence/Evidence.bs:6:24: error: `+` in ModelKey has `string` on its left
  `+` takes an int or a float on each side; this operand has neither part.
  Build a string with a template:
    $"{id.Lab}/{id.Model}/{id.Harness}"
```

Pasted as the body, the template returns `"-/glm-5.2/opencode"`.

## The rule

- `+`, `-`, `*`, `/` and `%` refuse an operand whose type meets neither `int` nor `float`
  (`non_numeric_operand`), naming the operator, the side and the operand's type. A record is named
  as the author wrote it, as a template's hole names one. Unary `-` is the same operator over one
  operand, and refuses one the same way (`side => operand`). Comparisons, `and` and `or` are not
  arithmetic, and are unchanged.
- **Meets, not is a subtype of.** `int | :none` and `term` have a numeric part, and compile as they
  did. **A type variable is not refused**, since whether arithmetic over one is legal is not
  decided (see *Leaves*), and `F<T>(T a) -> a + 1` ran `F(4)` to `5` before F67. The body sees a
  variable as an opaque atom, so a type holding that atom is read as the variable, unless it holds
  every atom: `atom` holds `:T` too, and is refused beside a type variable as it is anywhere else.
- **Arithmetic over an uninhabited operand is uninhabited.** An operand of type `none` never arrives,
  whether it raised or was refused below. It answered `int` before, so the second `+` of a string
  chain refused the first one's `int`, and the return check refused an `int` the chain never made.
  A chain is now one refusal, at its first `+`.
- **The refusal holds in a guard**, where a non-numeric operand is silently false rather than a
  crash: a clause's, a switch arm's and a comprehension's `when`, all three through the one guard
  filter F51's refusals pass.
- **A string under `+` is a join, and the advice is a template.** The parser nests `+` to the left,
  so the checker types a `+` chain as one left fold, each `+` at its own position, and the refusal
  can print the whole chain. It prints one only where the template builds the string C# would:
  every operand fills a hole (`string`, `int`, `float` or an atom type), and one of the first two is
  a `string`, since C#'s `+` adds numbers until a string joins them. `1 + n + "x"` gets no template.
  The operands it copies are names, one-level projections and literals; a brace in a literal is
  doubled, a literal needing an escape is not re-escaped, and a literal's text is printed as
  characters, not as its UTF-8 bytes. Otherwise the advice names the form, `$"...{expr}..."` in
  ASCII as every diagnostic is, without writing it. A string under any other operator is not a
  join, and nothing is offered.

What the build read that no ticket spelled, none of which needed a call:

- **The uninhabited rule** reaches past arithmetic over strings. In a `float` function,
  `(a + 2.0) + 3` printed `mixed_operands` and then *"F returns a value its signature does not
  declare"*, the outer `+` having answered `int`; measured against `747fff6`'s compiler, it now
  prints `mixed_operands` alone (F67.12). The `.abstr` diff over every example, and the rest of the
  suite, are unchanged by it.
- **A refuted lambda parameter binds its names as `term`**, as an unbound name does. It bound them
  from a domain the pattern does not cover, so `(acc, (:ok, n)) => acc + n` over a `result` gave
  `n` the error's `string`, and F67 refused `acc + n` beside the `lambda_param_refuted` that names
  the real fault. `function_value_tests`' own test went red on it, and is green again.
- **The message follows F53's**, "`+` in ModelKey has `string` on its left", rather than ticket
  112's proposed "ModelKey applies + to a string", so the two operator refusals read alike. The
  template goes on a line of its own, as a head does in F53's advice, because it is what the author
  pastes and what the gate lifts.

`/code-review` of `25b703c` (fresh sub-agents, standards and spec) found four defects, fixed with
F67.13–15 red first: an `atom` beside a type variable met the variable's atom and escaped; a
literal's `é` was advised as `Ã©`, which compiled into a different string; the JSON channel
crashed on `€`; and unary `-`, which the rule's wording reaches, compiled. It also found the
advice's `…` against `bs_diag`'s ASCII rule, and two record-name joins where `join/2` serves.
Kept, as judgement calls: the `+` clause repeats the generic `e_op` clause's step, since sharing
it would thread the chain's advice through every operator; and `mixed_pair/1` keeps its name,
which F53 had already outgrown.

A second `/code-review`, of the fixes alone (`25b703c..02f1129`), found unary `-` over an
uninhabited operand answering `float` (F67.16), a unary refusal saying "on its right" and "each
side" (F67.15), and the type-variable question with no ticket file, now
[116](../../wayfinder/issues/116-arithmetic-over-a-type-variable.md). The binary and unary sites
now share one verdict, `operand_verdict/2`, since the duplicate was where the `float` slipped in.
Running the suite for them found F67.11 red in 2 runs of 8, with F66.15's own parity 0 of 8; the
key was renamed from `repair` to `template`, and F67.11 was then green in 16 of 16.

## Scenarios

| Id | Scenario | Expected |
|---|---|---|
| F67.1 | `ModelKey`'s chain of four `+` over strings | one `non_numeric_operand`, at the first `+` (column 24; the test's fixture has no blank lines, so line 4), `side => left`; no `return_not_declared`, and no `string \| int` |
| F67.2 | the advice for `ModelKey`, pasted as its body | `$"{id.Lab}/{id.Model}/{id.Harness}"`, which returns `"-/glm-5.2/opencode"` |
| F67.3 | ticket 112's rows: `a + b` over two strings, `a + 1` over an `atom`, `o + 1` over a record, `a - b` over two lists | refused, each; the atom has `template => none`, the record is named `Order` |
| F67.4 | `2 op s` over a `string`, for each of `+ - * / %` | refused, `side => right` |
| F67.5 | `s + 1 > 3` in a clause guard, a switch arm's guard, and `x * 2 > 3` in a comprehension's `when` | refused, each |
| F67.6 | `int \| :none`, `term` and a type variable under `+`; `a < b` over strings; `a * 100` over `int \| float` | compile (and `F(4)` is `5`, `Less("a", "b")` is `:true`); the union is still `numeric_union_operand` |
| F67.7 | `"n=" + n` over an `int`, and the advice pasted back | `$"n={n}"`, which returns `"n=7"` for `7` |
| F67.8 | `"{" + s + "}"`, and the advice pasted back | `$"{{{s}}}"`, which returns `"{x}"` for `"x"` |
| F67.9 | `1 + n + "x"`, `"x" + o` over a record, `G() + s` | no template printed; the advice names `$"...{expr}..."` |
| F67.10 | `s * 2` over a `string` | refused, and no template offered |
| F67.11 | the diagnostic on the term channel, in `--batch` and standalone, with a rendered template and with `none` | byte-identical (ENG-349). Red in 2 runs of 8 while the key was `repair`, which printed before `op` in one VM and after it in the other; the key is `template` |
| F67.12 | `(a + 2.0) + 3` in a function returning `float` | `mixed_operands` alone: no `return_not_declared` for the `int` the outer `+` used to answer |
| F67.13 | `a + 1` over an `atom`, and over `:ok \| :err`, in a function generic over `T` | refused, each: the variable's exemption does not reach `atom` or another literal beside it (the literal `:'T'` is a *Leaves* line) |
| F67.14 | `"café/" + s`, the advice pasted back; `"€" + s` on the JSON channel | `$"café/{s}"`, which builds what `"café/x"` is; the JSON carries the template as text, `"$\"€{s}\""`, and does not crash |
| F67.15 | `-s` over a `string`; `-n` over `int \| :none` | refused, `op => '-'`, `side => operand`, "as its operand" and no "each side"; the union compiles |
| F67.16 | `-("a" + s)`, `-(-s)` and `-(n + "a")` in a function returning `int` | one `non_numeric_operand` each, and no `return_not_declared` offering `int \| float` |
