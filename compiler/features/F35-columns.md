# F35 — columns: a diagnostic names a position, not a line

**Status**      **done 2026-09-05** — 5 new tests, 638 in the suite, up from
                633. One gate extended, none added: `check-diagnostics.sh`
                already owned the shape of a diagnostic's header, so the
                column belongs to the check that was there
**Implements**  [ENG-297](https://linear.app/davewil/issue/ENG-297), the first
                of `ENG-205`'s LSP prerequisites and the only one that needed
                no decision. Its source is `editor/README.md`'s *"what an LSP
                would need from the compiler first"*, items 1 and 2
**Decides**     **one thing, and the decision was already written down**: the
                column is a NEW KEY beside `line`, never a `{Line, Column}`
                tuple replacing it. Ticket 23 §4 makes payload evolution
                additive only, and the suite matches `#{... line := 3}` in map
                patterns throughout — a tuple in `line` would have been the
                first payload change to break every matcher, which is the
                shape that rule exists to forbid
**Closes**      [ENG-297](https://linear.app/davewil/issue/ENG-297). Unblocks
                [ENG-305](https://linear.app/davewil/issue/ENG-305), the LSP
                server
**Depends on**  F16 (the diagnostic as a term, and prose as a pure function of
                it), which is what made this a change in one file rather than
                in sixty call sites
**Leaves**      **a resolve-time error names its DECLARATION, not the type
                that is wrong.** `public int F(Missing m)` is reported at `F`,
                column 12, and not at `Missing`, column 14. The grammar
                attaches no position to a type — `type_prim -> uident :
                {t_ref, value('$1')}` drops the token's location, as does
                every other type production — so the nearest node that has one
                is the declaration. Narrowing it to the type's own span means
                a position on every type node and a change to every consumer
                of one, which is a change to the type grammar rather than a
                gap in this feature.
                **`editor/README.md`'s prerequisite 3 is untouched**: the
                compiler still bails at the first lex or parse failure, which
                is poor while a file is being typed into

## What shipped

Every diagnostic carries a **column** beside its line, in the term and in the
prose. The header was `file:line:` and is now `file:line:column:`.

```
examples/Wire/wire.bs:42:18: error: Classify is not exhaustive
  no clause matches:
    Classify(>= 4 and <= 7) -> ...
```

```erlang
#{function => 'Classify', line => 42, column => 18, tag => inexhaustive, ...}
```

Six conditions that had **no position at all** now have one. `unknown_type`,
`unknown_builtin`, `generic_arity`, `needs_type_args`, `not_parametric` and
`cyclic_type` are raised from below the level that holds a position and used
to reach the author as `file: error: ...`, which an editor can place nowhere
but the top of the file.

## How it is done, and why it is small

**The lexer swap is the whole of it.** `bs_lexer.xrl` wrote `TokenLine` in 57
rule actions; it now writes `TokenLoc`, which leex predefines as
`{TokenLine, TokenCol}`. The parser's `line/1` is `element(2, T)` and did not
change, so every AST node carries a `{Line, Column}` pair without one grammar
edit.

**The pair becomes two keys at exactly one point.** `bs_diag:descriptor/2` is
now a wrapper over the 84 clauses that build a descriptor, and `place/1` at
its exit splits a `{Line, Column}` in `line` into `line` and `column`. A new
descriptor clause cannot forget to do it, because it never does it.

**A lex error needed a build option, not code.** leex's rule actions and its
ERROR tuples are governed separately, and the error location defaults to
`line`. Without `{xrl_opts, [{error_location, column}]}` a lex error was the
one diagnostic reaching `bs_diag` with half a position — and `message/1` has
no catch-all, so it did not print half a position, it crashed. Measured:
`F(n) -> n !x` printed a stack trace.

**The six get their position from the declaration they were found in.**
`bs_check:at_loc/2` wraps the resolution of a signature, a foreign signature
and a type-environment entry, catches a condition from the closed
`positionless/1` set, and re-raises it as `{at, Loc, Reason}`. `bs_diag`
unwraps that into the position and leaves the tag, payload and prose alone.
Their message clauses build the header through `placed/1` rather than writing
it, because an unwrapped path is still possible and `file: error:` is the
honest rendering when no position is known.

## The scenarios

| | what is exercised | what it establishes |
|---|---|---|
| F35.1 | the descriptor of an inexhaustive function carries `column` at a named value | the column reaches the term at all |
| F35.2 | **the same program twice, the second indented four spaces** | the column is READ OFF THE TEXT. This is the discriminating one: a descriptor that hardcodes `column => 1` passes F35.1 and fails here, and that is the exact wrong fix available — swapping `TokenLine` for `TokenLoc` and never carrying the loc into the term |
| F35.3 | the prose header names the column too | prose is a pure function of the term (ticket 23 §1), so a column in the term that the prose drops leaves the two disagreeing about what the compiler knows |
| F35.4 | `unknown_type` on `public int F(Missing m)` | a resolve-time condition has a position at all — and column 12, not 14, is what says the position is the DECLARATION's. See *Leaves* |
| F35.5 | a warning's descriptor carries both halves | the invariant at the boundary for a second raising path: a line and a column travel together |

**Why F35.2 is a scenario and not another case of F35.1.** Every assertion
that names one column is satisfied by a constant. The indent is the only
assertion in the file that a constant cannot pass, so it is the one that
proves the lexer's loc reached the term rather than being read off a variable
that always held the same thing.

## What the gate checks, and what it caught

`check-diagnostics.sh` gained one check: **no format string in `bs_diag` may
print a line without a column**, tested by grepping for the pre-F35 two-part
prefix. Its stray detector — which refuses a diagnostic-shaped message written
outside `bs_diag` — learned the three-part spelling, so a stray copied from
the file as it stands today is caught as well as one copied from an older
neighbour. Both are controls in the self-test, and the new check was seen to
fail on the committed tree before the implementation existed: it named all 69
sites.

**The suite caught two regressions that no gate would have.** Both are worth
recording because both are silent:

1. **The `not` teaching degraded to a raw parse error.** Ticket 63's hint fires
   by comparing where `not` sits with where yecc stopped. Those are two
   different positions on the same line, so an equality that held between line
   integers matched nothing between `{Line, Column}` pairs, and
   `bsc` went back to printing `syntax error before: '('` — the message that
   hint exists to replace. `line_of/1` compares the line alone.
2. **`bsc --api` crashed on a module-path mismatch.** Two sites minted a bare
   `1` as the position of a file with no `module` line. A bare integer reaches
   `bs_diag` as a line with no column, and `message/1` has no catch-all. The
   fallback is now `{1, 1}` — the top of a file is a position, not a line.

## What moved that was already wrong

`TOUR.md`'s field-set-mismatch transcript read `examples/Shop/shop.bs:37`; the
compiler reports it at **45**. That fence sits inside an indented block, which
`check-tour.sh` does not replay for the same reason `check-language.sh` cannot
see one ([ENG-238](https://linear.app/davewil/issue/ENG-238)), so it had gone
eight lines stale unseen. It was re-measured against the real compiler and
corrected here rather than left for the column to make it wrong twice.
