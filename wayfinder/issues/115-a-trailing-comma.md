# 115 — A trailing comma in a list in braces or brackets

Type: grilling
Status: open — [ENG-574](https://linear.app/davewil/issue/ENG-574). Raised 2026-09-29 by David,
reviewing F63 ([ENG-550](https://linear.app/davewil/issue/ENG-550)). It takes up the trailing comma
[110](110-an-optional-clause-block.md) left open, for every list rather than for the block and
`switch` alone
Blocked by: —

## Why this is raised

Ticket 110 put commas between a clause block's arms and no trailing comma, *"exactly as between
`switch` arms"*, and left the trailing comma open as *"one question for both"*. Measured on
`9f2ace2`, it is one question for every comma list in the language, because B# refuses a trailing
comma in all of them:

| B# form | B# today | C# (ECMA draft v8) |
|---|---|---|
| clause block arms, `(Stop s) -> :brain, }` | `syntax error before: '}'` | no clause block |
| `switch` arms, `_ => :unknown, }` | `syntax error before: '}'` | taken: `switch_expression_arms : … ','?` |
| list literal, `[80, 443, 8080,]` | `syntax error before: ']'` | taken in array and collection initializers, `{ a, b, }` |
| record literal, `Response{ Code = 429, Body = :too_many, }` | `syntax error before: '}'` | taken in an object initializer |
| map literal, `{ Burst = 20, Sustained = 5, }` | `syntax error before: '}'` | as the object initializer |
| record declaration, `record Response { Code: int, Body: atom, }` | `syntax error before: '}'` | no braced member list; an enum body, the nearest, takes one |
| call arguments, `Retry(1, 2,)` | `syntax error before: ')'` | refused: `argument (',' argument)*` |
| tuple, `(:ok, 42,)` | `syntax error before: ')'` | refused: `'(' tuple_element (',' tuple_element)+ ')'` |

In every C# production checked here, the line is drawn by bracket: a list in braces may end in a
comma and a list in parentheses may not. The productions are in the standard's `expressions.md`
(switch expression, object, collection and anonymous-object initializers, argument list, tuple
literal), `arrays.md` (array initializer) and `enums.md` (enum body). Erlang refuses a trailing
separator everywhere: `erl_parse` on OTP 28.5 refuses `[80, 443, 8080,]`, `case X of 1 -> a; 2 ->
b; end` and `#{a => 1,}`. B# today follows Erlang.

## The program

F63's message router, with a case added at the end:

```csharp
public atom Direction(Message message) {
    (Hello h)      -> :hands,
    (Task t)       -> :brain,
    (ToolResult r) -> :brain,
    (Stop s)       -> :brain,
}
```

Under **no**, adding `Stop` touches two lines: the new arm, and a comma on the `ToolResult` arm
above it. That is the splice F63.7's test makes when it pastes a printed arm, `(Stop s) -> ...`,
back into a block. Under **yes**, an arm written with its comma is added, moved or deleted as one
line, as a C# switch arm is.

## Round 1

**Q1. May a list in braces or square brackets end in a comma, as C#'s braced lists may, while a
list in parentheses stays as it is?**

Under yes, every row above written in `{ }` or `[ ]` compiles, and the call and the tuple are
still refused. Under no, B# keeps Erlang's rule, and a comma before `}` stays `syntax error
before: '}'`.

Compiler delta under yes: `bs_parser.yrl` takes an optional `','` before the closing token of the
clause block, `switch`, list literal, record and map literal, and record declaration rules, with
yecc's conflicts measured on the grammar before and after.
`editor/tree-sitter-beam-sharp/grammar.js` mirrors it, and a scratch file holding each form
parses with no `ERROR` node. LANGUAGE.md says it once, with a gated block. The parser drops the
comma, so no emitted code changes.

Under yes, and asked after it rather than beside it: whether a diagnostic that prints an arm to
paste prints it with its comma.
