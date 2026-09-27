# F63 — The clause block: a function's clauses in braces after its signature

**Status**      **in progress**
**Implements**  [ticket 110](../../wayfinder/issues/110-an-optional-clause-block.md), resolved
                2026-09-28. Decides nothing
**Closes**      [ENG-550](https://linear.app/davewil/issue/ENG-550)
**Depends on**  F46 (a function as a value, whose call of a bound name is why the clauses
                need a comma between them)
**Leaves**      a trailing comma after the last clause, and whether the block becomes the
                preferred spelling (both not decided by ticket 110)

## The program

```csharp
public atom Direction(Message message) {
    (Hello h)      -> :hands,
    (Demand d)     -> :hands,
    (Task t)       -> :brain,
    (ToolResult r) -> :brain
}
```

is the same function as

```csharp
public atom Direction(Message message)
Direction(Hello h)      -> :hands
Direction(Demand d)     -> :hands
Direction(Task t)       -> :brain
Direction(ToolResult r) -> :brain
```

## The rule

A signature may be followed by a braced block of clauses instead of named equations. Each clause is
the named clause with its name removed, `(patterns) [when guard] -> body`, and clauses are separated
by a comma, as `switch` arms are. There is no trailing comma.

**It is sugar.** The parser expands a block into the declarations the named form produces, the
signature and one named clause per arm in the order written, and records that the function was
written as a block. Everything downstream reads those declarations, so checking, exhaustiveness,
emission and `--api` cannot tell the two apart. "Identical output" is measured on the abstract
forms with every position annotation set to zero: the block form moves a clause's columns by
construction, so the annotated forms cannot be byte-identical.

**A block is the whole of its function.** A named clause with a block function's name and arity is
refused as `clause_outside_block`, naming the clause. A second block for the same function is
refused the same way.

**Diagnostics speak the form written.** Where a diagnostic prints a clause to paste, a block
function gets an arm: `(Stop s) -> ...`, for pasting before the closing `}` after a comma.

## Scenarios

| Id | Given | Then |
|---|---|---|
| F63.1 | one module written in both forms: records dispatched, a guard, two parameters, and two functions of one name at different arities | the abstract forms are equal once positions are zeroed, the exports are equal, and every function returns the same values |
| F63.2 | the same module in both forms, through `bsc --api` | the two outputs are identical |
| F63.3 | a block whose clauses have no comma between them, the first body a bound name | a syntax error, not a call |
| F63.4 | a block function missing a case | the inexhaustive diagnostic prints `(Stop s) -> ...`, with no function name |
| F63.5 | a block function with a named clause of the same name and arity after it | refused as `clause_outside_block`, naming the clause |
| F63.6 | a block and a named function of the same name at a different arity in one file | compiles: arity makes them two functions |
| F63.7 | the printed arm from F63.4 pasted before the `}` after a comma | the program compiles |
