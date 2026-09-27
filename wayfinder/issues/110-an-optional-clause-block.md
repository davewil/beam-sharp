# 110 — An optional clause block beside the named equations

Type: grilling
Status: resolved 2026-09-28 — [ENG-549](https://linear.app/davewil/issue/ENG-549). Raised and
answered 2026-09-28 from David's brief, which asked for the block form to be explored against a
concrete program and built if it held up. It amends [01](01-sample-code.md) and
[08](08-head-and-guard-syntax.md)
Blocked by: —

## Why this is raised

[01](01-sample-code.md) chose **Variant A, equations under a signature**, *"as closest to the
intended language"*, over Variant B, a clause block. It weighed two arguments for the block, that
signature and clauses can drift apart and that repeated declarations read as C# overloads, and
judged them *"not sufficient to override the preference"*. It handed both to
[08](08-head-and-guard-syntax.md) to mitigate within Variant A. 08 closed drift as *"impossible
under directory-as-module with one function per file"*.

That assumption no longer holds. One function per file is a convention, and the compiler enforces
only that `index.bs` holds none. `compiler/examples/Pipeline/pipeline.bs` carries eleven signatures,
and `Shop/Collections/Ints/Ints.bs` two arities of one name. The cost 01 accepted is live in the
corpus.

David's brief of 2026-09-28 brought the question back with the Signalbox port's function:

```csharp
public atom Direction(Message message)
Direction(Hello h)      -> :hands
Direction(Demand d)     -> :hands
Direction(Events e)     -> :hands
Direction(ToolCall c)   -> :hands
Direction(Task t)       -> :brain
Direction(Ack a)        -> :brain
Direction(Stop s)       -> :brain
Direction(ToolResult r) -> :brain
```

The name is written nine times and carries no information after the first. The brief proposed an
**optional** block, with the named form kept:

```csharp
public atom Direction(Message message) {
    (Hello h)      -> :hands
    (Demand d)     -> :hands
    ...
}
```

## The grammar problem, measured

A body has no terminator: it ends where the next token cannot continue it. Today the next clause
opens with a name, which never continues an expression. In a block the next clause opens with `(`,
and [75](75-a-function-as-a-value.md)'s call of a function held in a variable,
`call -> lident '(' expr_list ')'`, continues any body that ends in a bare name. Built into a
scratch copy of `bs_parser.yrl` at `7b1ef96`, without separators:

```csharp
public int Pick(int n) {
    (0) -> n
    (1) -> 2
    (m) -> m
}
```

fails with `syntax error before: '->'` on line 4. One token of lookahead reads `n (1)` as the call
`n(1)`, and the `->` after it cannot continue an expression. `Direction` parses, because every body
there is an atom, so whether a clause parses would depend on how the clause *before* it ends. A
body that ends in a bound name (`(Full f) -> f`) is the commonest body there is. yecc reports no new
conflict for this: base already resolves `'('` after a lowercase name as a shift.

With a comma between clauses both programs parse, and the only conflict the block adds is `'{'`
after a signature (base 5 shift/reduce, block 6). That one is benign. Its rival reading is a
signature with no clauses followed by a signature whose return type is a field set, and a signature
with no clauses is already refused: `F has a signature but no clauses`.

A comma is also what B#'s own `switch` puts between arms, and what C#'s switch expression does.
Variant B's `;` terminators are gone from the language, since the 2026-08-15 dialect has no `;`
anywhere.

## Two programs under the block

The flattering one:

```csharp
public atom Direction(Message message) {
    (Hello h)      -> :hands,
    (Demand d)     -> :hands,
    (Events e)     -> :hands,
    (ToolCall c)   -> :hands,
    (Task t)       -> :brain,
    (Ack a)        -> :brain,
    (Stop s)       -> :brain,
    (ToolResult r) -> :brain
}
```

The unflattering one is 01's own example, whose single tuple parameter gives each head doubled
parentheses (the item 01 handed to 08). With no name in front, the outer pair reads as punctuation
rather than as a parameter list:

```csharp
public Verdict Classify(Reading r) {
    ((:ok, n)) when n > 0 -> :positive,
    ((:ok, 0))            -> :zero,
    ((:ok, _))            -> :negative,
    ((:error, _))         -> :unknown
}
```

That is the case where the named form still reads better, and it is one reason the block is an
option rather than a replacement.

## Q1 — Is the optional block sound, and in what form?

**A1 (David's brief, 2026-09-28, with the separator chosen after the measurement above as the brief
allowed):** yes, as an option beside the named form, which stays the default spelling and is
unchanged.

- **Commas between clauses**, and no trailing comma, exactly as between `switch` arms.
- **A block is the whole of its function.** A function written as a block has no named clauses
  anywhere else in the file. The braces exist to tie the clauses to the signature, and a named
  clause for the same function outside them would undo that. Mixing the two forms for one
  function is refused, naming the stray clause.
- **Diagnostics speak the form the author wrote.** A missing case in a block function prints as the
  arm to paste inside the block, `(Stop s) -> ...`, not as a named head that would then be refused
  as a stray clause. The arrow stays `->`, which is what separates a clause from a switch arm's `=>`.
- **Nothing else changes.** A block is sugar. The clauses are the same clauses in the same order,
  under the same signature, so exhaustiveness, the emitted BEAM and the module's public API are
  identical to the named form.

It answers 08's second cost too. Repeated declarations read as C# overloads, and a single braced
declaration with its cases inside reads as what it is, one method.

## The compiler delta

- `bs_parser.yrl`: `signature '{' block_clauses '}'`, with `block_clauses` comma-separated and each
  clause `'(' patterns ')' guard '->' body`. The parser expands a block into the flat declarations
  every consumer already reads, the signature and one named clause per arm, and adds a marker
  declaration recording that the function was written as a block.
- `bs_check`: refuses a named clause of a block function (a new diagnostic). It carries the form
  into the diagnostics that print clause heads, and they print arms for a block function.
- The tree-sitter grammar gains the block. The three regex grammars already colour `(…) ->`.
- Pasting an arm into a block is proven at the boundary. F63's test reads the arms the compiler
  prints, pastes them before the `}` with a comma on the arm above (the splice
  `check-residual-pasteable.sh` makes for a switch arm), and recompiles. The gate itself is not
  extended. A block arm comes from the same head printer as a named head, with the name left out, so
  the gate's roster of residual shapes already covers what the arm can spell. The only new thing is
  where the arm goes, and that is what the test pastes.

## Not decided here

- A trailing comma after the last clause. Neither the block nor `switch` takes one today, and
  changing that is one question for both.
- Whether the block should become the preferred spelling. The corpus stays in the named form.

## Decisions entry

<!-- This ticket's entry. Read whole, here; the map (ENG-165) carries one line. -->

```decisions-entry
- [An optional clause block beside the named equations](issues/110-an-optional-clause-block.md)
  — **a function may write its clauses inside braces after its signature, comma-separated and
  without its name, `public atom Direction(Message m) { (Hello h) -> :hands, (Task t) -> :brain
  }`, as an option beside the named equations, which stay the default.** Raised and resolved
  2026-09-28 from David's brief, amending [01](issues/01-sample-code.md) and
  [08](issues/08-head-and-guard-syntax.md): 08's drift mitigation assumed one function per file,
  and the corpus has eleven in one. The proposal had no separator, and that was measured to fail:
  `(0) -> n` followed by `(1) -> 2` parses as the call `n(1)`
  ([75](issues/75-a-function-as-a-value.md)), so the comma `switch` already uses is required. A
  block is the whole of its function, so a named clause beside it is refused. Its diagnostics print
  arms, `(Stop s) -> ...`. It is sugar, so BEAM, exhaustiveness and the public API are unchanged. Not
  decided: a trailing comma (for `switch` too), and whether the block becomes preferred.
```
