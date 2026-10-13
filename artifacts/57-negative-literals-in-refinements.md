# Decision brief — ticket 57 (ENG-239): a refinement cannot say `-5`, though a pattern can

**Status: OPEN. Nothing is resolved.** Prepared autonomously 2026-10-13 for David's review. Every
number below was produced by a script in [`probes/57/`](probes/57/); the verifier section at the
end says which a second agent re-ran.

## The one question

**Should `-5` be one integer literal everywhere an expression is read, or stay a negation node that
the checker folds where it needs a constant?**

The ticket asked "grammar or checker". Measured, that is the right axis but the wrong boundary: the
refinement is not the only reader. A guard reads the same literal through the same
`alternatives/1`, and an argument position reads it through `type_of/3`. Whichever answer is chosen
has to cover all three, and that is what separates the options below.

## What the ticket got wrong or left unmeasured

| Ticket says | Measured 2026-10-13 at HEAD | Probe |
|---|---|---|
| unary minus "desugars to a subtraction" `0 - e` | stale since F51: it is an `e_neg` node (`bs_parser.yrl:591` → `negate/2`, `bs_parser.yrl:947-948`) | P3 |
| the grammar would have to *mirror `int_lit`* | the parser **already folds a negated float literal** in the same `negate/2`; the integer case is the one missing clause | `bs_parser.yrl:945-948` |
| refinement-only defect | **a guard is refused identically**: `Sign(n) when n <= -1 -> :neg` beside `n >= 1` and `0` is reported `Sign is not exhaustive`, residual `Sign(<= -1)` — the compiler hands back the pattern spelling of the clause the author just wrote | P2 |
| the diagnostic recommends the refused form | confirmed; it fires for `value != -1`, `-5 <= value`, `-(-5)`, `-0`, `value == -3` too | P1 |

## Evidence

Baseline matrix (P1, `bsc` built from HEAD; note `value == -3` passes the checker under A/B/B2 and then fails in the backend with `bad range type`, the P5 defect, so it is not a clean "accepted"): refused — `>= -5`, `>= -5 and <= 5`, `>= 1 or <= -1`,
`!= -1`, `== -3`, `-5 <= value`, `>= -(-5)`, `>= -0`, `> -1.5`, `>= 2 + 3`. Accepted — `<= 3 or >= 10`,
`!= 0`.

| | baseline | **A** fold in `negate/2` | **B** fold in `comparison/1` only | **B2** `comparison/1` + `type_of/3` |
|---|---|---|---|---|
| `value >= -5` (and the other seven negative-literal rows) | refused | **accepted** | **accepted** | **accepted** |
| `value >= 2 + 3` | refused | refused | refused | refused |
| guard `n <= -1` credits coverage (P2) | no | **yes** | **yes** | **yes** |
| `Pass(-3)` into `Delta = -5..5` (P4a) | n/a (type unwritable) | **accepted** | **refused** — `-3` is typed `int` | **accepted** |
| `Pass(-d)` for a `Delta d` (P4b, must stay refused) | n/a | refused | refused | refused |
| patch size, `diff -u` of non-generated source | — | 1 file, **+1 −0** | 1 file, +7 −2 | 1 file, +8 −2 |
| sites that must agree | — | **1** | 2 `comparison/1` clauses + `const_int/1` | those + `type_of/3` |
| AST words for one written `-5` (P3, `erts_debug:flat_size`, hand-built terms not A's parser output) | 8 | **4** | 8 | 8 |
| eunit, 1448 tests | 1448 pass (291 s) | **1448 pass** (293 s, full layout) | not run | the two layout-dependent modules pass; full suite not reported |

**The row that matters is `Pass(-3)`.** Option B alone makes `Delta` writable and then refuses
`Pass(-3)`, because the literal is still typed `int`. That is the ticket's own defect again, one
level down: a type you can write and cannot use. It would pass a gate that only tests the
declaration.

*Eunit note.* My first run of A showed 2 failures; they were my scratch copy lacking `bin/`, `examples/` and `../aoc`. With that layout restored, A passes all 1448.

## Neighbours

| | what the parser keeps for `-5` | evidence |
|---|---|---|
| Erlang | a node: `{op,L,'-',{integer,L,5}}`, in a guard and in a pattern | `erl_parse.yrl:269,301` (`prefix_op expr` → `?mkop1`); P-neighbours `erl_neg.erl` printed it |
| Elixir | a node: `{:-, [line: 1], [5]}`; folds later | `neg.exs` |
| Gleam 1.19.0 | **a literal**: emitted `{integer,4,-5}` in both a guard and an expression | `neighbours/gl`, abstract code dump. Compiler source is not installed; this is the output shape, not a file:line |
| Elm 0.19.2 | not run — the package registry is unreachable from this sandbox (`package.elm-lang.org` returned no connection) | — |

So the neighbours split 2–1 on "node, folded later" versus "literal". Erlang's node-and-fold works
because OTP has one constant-folding pass that every reader sits behind. B# has three readers and
no such pass, which is why B needed a third site.

## Options

### A — the integer literal is one token-pair at parse time (recommended)

```erlang
%% bs_parser.yrl, beside the float clause that is already there
negate(_L, {e_float, FL, F}) -> {e_float, FL, -F};
negate(_L, {e_int,   IL, I}) -> {e_int,   IL, -I};     %% +1 line
negate(L, E)                 -> {e_neg, L, E}.
```

```csharp
type Delta = int where value >= -100 and value <= 100   // accepted
Sign(n) when n <= -1 -> :neg                            // credits coverage
Pass(-3)                                                // typed -3..-3, accepted
```

Compiler delta: one clause. `type_of({e_int,…})` already yields the singleton range, so a literal
`-3` becomes the singleton `-3..-3` with no further work. Refinements, guards and argument checking
agree by construction because the node never exists.

**Strongest counterargument.** `bs_check.erl` says a refinement is an `expr` precisely so that it
and a guard cannot disagree, and the ticket reads that as a reason to keep the grammar wide. A
parser fold is a *grammar-side* answer to a question the checker was designed to own. Against it:
the parser already makes that exact choice for floats, so the principle is already spent; and it
costs no generality, because `-x` and `-(a+b)` still reach the checker as `e_neg`.

**Second counterargument, unrefuted.** `2 + 3` stays refused (P1). A fold in the parser can never
reach it. If David wants "a refinement bound is any constant expression", A is the wrong shape and
B2 is the seed of the right one.

### B2 — the checker folds, in both places that read a constant

```erlang
const_int({e_int, _, K}) -> {ok, K};
const_int({e_neg, _, E}) -> case const_int(E) of {ok, K} -> {ok, -K}; error -> error end;
const_int(_)             -> error.
%% used by comparison/1 (both operand orders) AND by type_of({e_neg,…}) for a constant operand
```

Compiler delta: `const_int/1`, two `comparison/1` clauses, one `type_of/3` clause. Handles `-(-5)` for
free. Extending it to `+`, `*` and `2 + 3` is a few lines more, and that is the open scope question
the ticket named ("where it stops").

**Strongest counterargument.** It leaves a node in the tree that every later pass must remember to
fold, and the failure mode for forgetting is silent: B (without the `type_of/3` clause) passed the
whole refinement matrix and still refused `Pass(-3)`. Two sites became three in the course of one
afternoon, and a fourth reader (a future constant-pattern bound, a `match` token) will be the next
to forget.

### C — narrow the refinement grammar to a literal comparand (the ticket's first bullet)

Not built, and eliminated by P2 rather than by taste: it repairs the declaration and leaves
`when n <= -1` non-exhaustive, so the same literal is readable in a refinement and refused in a
guard — the exact split the `refinement -> expr` comment exists to prevent.

## Recommendation

**A**, decided together with one sentence on scope: *"a refinement bound is an integer literal;
folding arithmetic is not offered."* A is one line, fixes all three readers, and shrinks the tree.
If David's answer to "how far does folding go" is "any constant expression", take B2 instead and
accept the third site.

Independent of the choice, two things surfaced that are not this ticket's to decide but should not be
lost:

1. **The diagnostic still recommends the form it refuses** (`opaque_refinement` text). Whatever is
   chosen, `value >= 2 + 3` will still hit it.
2. **A positive singleton refinement does not compile.** `type Three = int where value == 3` passes
   the checker and fails in the Erlang compile step with `compile: D/D.bs:0: bad range type` (P5,
   baseline, no variant involved). `value >= 2 and value <= 3` is fine. A grep for "bad range type"
   in the repo finds nothing, so it has no ticket. One occurrence, so by the repo's own rule it is
   a sentence here and not a gate.

## Reproduce

```
export BSC=compiler/_build/default/bin/bsc
artifacts/probes/57/run.sh           # P1 matrix, P2 guard, P3 AST words
artifacts/probes/57/run4.sh          # P4/P5/P6 call-site and singleton rows
# variants: artifacts/probes/57/variant-vA.diff, variant-vB.diff, variant-vB2.diff
#   apply to a COPY of compiler/ with the generated src/bs_parser.erl and src/bs_lexer.erl deleted,
#   or rebar3 will reuse the stale parser (this cost me one false "A changes nothing" result)
```

## Verifier result

(filled in below by the independent re-run)
