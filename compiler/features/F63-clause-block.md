# F63 — The clause block: a function's clauses in braces after its signature

**Status**      **done 2026-09-29** · [ENG-550](https://linear.app/davewil/issue/ENG-550) — 13
                tests in `clause_block_tests`, seen red first (the three
                routed-diagnostic tests shown to discriminate by narrowing the
                routing); `check-language.sh` gained a must-compile block and a
                `diagnoses: clause_outside_block` block in §2, both seen red
                first; the tree-sitter grammar takes the block; one new example,
                `examples/Signalbox/signalbox.bs`, and its roster and tour rows.
                David, closing it, accepted the mixing refusal as reported at the
                stray clause's own line (ticket 110's amendment), the twin
                measured on position-free forms, and F63.7's paste in place of
                the residual gate
**Implements**  [ticket 110](../../wayfinder/issues/110-an-optional-clause-block.md), resolved
                2026-09-28. Decides nothing
**Closes**      [ENG-550](https://linear.app/davewil/issue/ENG-550)
**Depends on**  F46 (a function as a value, whose call of a bound name is why the clauses
                need a comma between them)
**Leaves**      a trailing comma after the last clause, now [ticket 115](../../wayfinder/issues/115-a-trailing-comma.md)
                ([ENG-574](https://linear.app/davewil/issue/ENG-574)) for every list in braces
                or brackets, and whether the block becomes the preferred spelling (not decided
                by ticket 110)

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
refused as `clause_outside_block`, at the clause. A second block for the same function carries a
second signature of the same arity, so it is refused by the rule that already refuses one,
`F/1 is declared more than once`, and needs nothing of its own.

**Diagnostics speak the form written.** Where a diagnostic prints a clause to paste, a block
function gets an arm: `(Stop s) -> ...`, for pasting before the closing `}` after a comma.

## Scenarios

| Id | Given | Then |
|---|---|---|
| F63.1 | one module written in both forms: records dispatched, a guard, two parameters, and two functions of one name at different arities | the abstract forms are equal once positions are zeroed, the exports are equal, and every function returns the same values |
| F63.2 | the same module in both forms, through `bsc --api` | the two outputs are identical |
| F63.3 | a block whose clauses have no comma between them, the first body a bound name | a syntax error, not a call |
| F63.4 | a block function missing a case | the inexhaustive diagnostic prints `(Stop s) -> ...`, with no function name |
| F63.5 | a block function with a named clause of the same name and arity after it | refused as `clause_outside_block` at the clause's own line, the only error |
| F63.6 | a block and a named function of the same name at a different arity in one file | compiles: arity makes them two functions |
| F63.7 | the printed arm from F63.4 pasted before the `}` after a comma | the program compiles |
| F63.8 | one inexhaustive function written in both forms | both are refused as not exhaustive, naming the same missing case: `Direction(Stop s) -> ...` for the named form and `(Stop s) -> ...` for the block |

## Measured

- **yecc**: 5 → 6 shift/reduce, 0 reduce/reduce. The one added is `'{'` after a signature,
  resolved by shift into the block; the conflict list otherwise equals the base's by symbol.
  `binary_tests`' named-conflict count moves with it.
- **Without a separator**: a scratch grammar, never shipped, first showed `(0) -> n` above
  `(1) -> 2` as `syntax error before: '->'` on the second arm. That `n` is unbound, so F63.3
  measures the corrected `(0, n) -> n` above `(1, n) -> 2` through the shipped compiler instead,
  with the same error on line 4, and with commas `Pick(0, 42)` returning 42. The base conflict at `'('` after a lowercase name
  is what swallows it, so the count showed nothing — only parsing the program did.
- **tree-sitter**: the same ambiguity is reported at generate time and settled with `prec.right`
  on `signature`, matching yecc's shift. `signature` is in none of the grammar's declared
  `conflicts`, so the rule-wide `prec` settles only this ambiguity. A scratch file with a guarded arm, a lambda-bodied last
  arm, a field-set-returning signature after a block and a two-parameter block parses with no
  `ERROR` node.
- **Order of printed arms** is the residual's, not the declaration's: a block missing `Task` and
  `Stop` prints `(Stop s)` first. The test does not pin it.
- **`--api` answers for a module refused only by `clause_outside_block`**, as it does for one
  refused by `no_clauses`: both are function-body refusals, and `--api` stops only on a
  declaration refusal. The two are in the same class.
