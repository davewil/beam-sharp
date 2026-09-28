# 112 — May an arithmetic operand have no numeric part?

Type: grilling
Status: claimed — [ENG-555](https://linear.app/davewil/issue/ENG-555). Raised 2026-09-28 out of
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

## Round 1

**Q1. Is an operand of `+ - * / %` with no `int` or `float` part refused?**

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

## Next, depending on Q1

- **Does `+` join two strings, as C#'s does?** This asks for `string` to be the one non-numeric
  operand `+` accepts. It only arises once Q1 has said whether a non-numeric operand is refused at
  all. Today the only planned way to join strings is ticket 96's `List.Join` row (ENG-454, unbuilt).

## Not decided here

- **An operand with a numeric part and another part**, `int | :none` or `term`. It compiles today,
  and [83](83-a-union-operand-at-an-operator.md) scoped it out. Q1 is about an operand with *no*
  numeric part.
- **Comparison operators.** `<` over two strings is the BEAM's term order and does not crash.
