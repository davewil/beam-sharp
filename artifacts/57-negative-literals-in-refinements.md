# Decision brief: ticket 57, a refinement cannot say `-5`

Linear: ENG-239. Repo ticket: `wayfinder/issues/57-negative-literals-in-refinements.md`.
Status after this brief: **still open**. Nothing here resolves it.

Probes: `artifacts/probes/p57_*.sh`. Prototype patches: `artifacts/probes/patches/57a-*.patch`, `57b-*.patch`.
Toolchain: `artifacts/probes/env.sh` (OTP 28, Elixir 1.20.4, Gleam 1.19.1). Elm 0.19.3 is installed but cannot compile a project here, because `package.elm-lang.org` is unreachable from the sandbox, so Elm was not probed.

## The one question

The ticket asks where the fold of `-5` belongs, the grammar or the checker. Only that question gates anything. The other two items in the ticket (does `2 + 3` count, does `value >= n` ever count) follow from it.

## What I measured

**The bug reproduces unchanged on today's compiler** (`p57_negative_refinement.sh`, base column):

| source | today |
|---|---|
| `int where value >= -5` | refused |
| `int where value >= -5 and value <= 5` | refused |
| `int where value >= 1 or value <= -1` | refused |
| `int where value <= 3 or value >= 10` | accepted |
| `int where value != 0` | accepted |
| `int where value >= 2 + 3` | refused |
| `int where value >= 0 - 5` | refused |
| pattern `Sign(<= -1)` | accepted |

**Two facts the ticket does not have.**

1. The grammar already folds one negated literal. `bs_parser.yrl:947`, `negate/2`, turns `-<float literal>` into the float literal. F51 put it there so that `-0.0` is negative zero. Integer literals fall through to `{e_neg, L, E}` on the next line. So "fold in the grammar" is not a new kind of change for this parser, and it does not narrow the grammar "at one site": `negate/2` sits under `expr_low`, the production a refinement and a guard both use. They stay in agreement by construction.
2. The bug is not only a refinement bug. A guard goes through the same `alternatives/1`, so a guard holding `-1` is read as unknown and credits no coverage. `p57_guard_reach.sh`: this function is refused today as "Sign is not exhaustive", although the two guards cover every int.

```csharp
public atom Sign(int n)
Sign(n) when n < -1 -> :neg
Sign(n) when n >= -1 -> :nonneg
```

The same function with `1` instead of `-1` is accepted. So the false refusal reaches the language's defining feature, not just the type syntax.

## The two programs, and what each compiler change accepts

```csharp
type Delta = int where value >= -100 and value <= 100     // A: accepted   B: accepted
type Gap   = int where value >= 2 + 3                      // A: refused    B: accepted
public atom Sign(int n)
Sign(n) when n < -1 -> :neg                                // A: accepted   B: accepted
Sign(n) when n >= -1 -> :nonneg
```

**A. Fold in the grammar.** One line in `negate/2`: `negate(_L, {e_int, IL, N}) -> {e_int, IL, -N};`. Measured against the unchanged probe: every negative-literal row flips to accepted. `2 + 3` and `0 - 5` stay refused. Patch: `patches/57a-grammar-fold.patch` (1 added line).
Emitted code: the printed Erlang is identical (`X - -5`, `-5`). The `.beam` for the two-site probe is 960 bytes against 964 for base and B (the verifier measured this; my own first run showed 968 and 960, which I could not reproduce), because the abstract form carries `{integer,_,-5}` instead of `{op,'-',…}` (`p57_emit.sh`).
Strongest counterargument: it folds only a negated literal. Anyone who writes `value >= 2 + 3` or `value >= -(5)` meets the same `opaque_refinement` text, which again tells them to write a comparison on `value`. The text is true but unhelpful.

**B. Fold in the checker.** A `fold_int/1` over `e_neg` and `+ - *` of literal ints, applied to both operands before `comparison/1`. Patch: `patches/57b-checker-fold.patch` (33 changed lines in `bs_check.erl`, one file). Every row in the probe flips to accepted, including `2 + 3` and `0 - 5`. Emitted code identical.
Strongest counterargument: it is a second constant folder inside a checker that already has a parser-level folder for floats, so the codebase now has two places that decide what a literal is. `value >= n` still has to be refused, and the fold function is where someone will next ask for `n` to be a named constant.

**Regression check.** Existing suite (`compiler/test/*.erl`, 73 modules, run with `rebar3` replaced by `escript:create`): baseline 1442 pass, 6 fail. Those 6 are two tests that need a UTF-8 locale, my shell had latin1. A: 1442 pass, the same 6 fail. B: 1442 pass, the same 6 fail.

**A third fact the verifier found (`verification/57-extra.sh`).** A call-site `-5` is also parsed as `e_neg` and typed as a widened range. With `type T = int where value >= 100`, `Id(-5)` reports the argument as `int <= 99` on base and under B, and as `-5` under A. So under B alone a refinement with a negative bound still cannot be handed a negative literal argument: `Id(-5)` into `value >= -5` and `Id(-1)` into `value <= -1` are wrongly refused (2 of 9 extra rows fail under B, 0 under A, 7 fail on base). That typing imprecision exists today and favours A. A is also a global parse change (every `expr_low` context folds `-N`), though the emitted Erlang text is unchanged.

## How the neighbours treat the same literal

Run by `p57_neighbours.sh`.

- Erlang keeps `-5` as a node: `{op,1,'-',{integer,1,5}}` in a guard and in a pattern (`stdlib-7.3/src/erl_parse.yrl:269` for `expr`, `:301` for `pat_expr`). Folding happens later, in `erl_eval:partial_eval/1`, which `erl_lint.erl:2140` calls. That is option B's shape.
- Elixir keeps it as `{:-, [line: 1], [5]}`. I did not find where it folds, so I claim nothing about it.
- Gleam 1.19.1 folds early. Its emitted guard for `m if m >= -5` contains `{op,4,'>=',{var,4,'M'},{integer,4,-5}}`. Only the binary is installed, no Gleam source, so this is observed output, not a file and line. That is option A's shape.
- Elm: not probed (see top).

So the two options each have one working neighbour, and the BEAM's own compiler chose B's layout for historical reasons the Erlang sources do not state.

## Recommendation

Take A now, and say in the ticket that `2 + 3` stays refused on purpose. A also fixes the call-site typing of `-5`, which B does not. A is one line, it mirrors a fold the parser already has, and it removes the guard false-refusal as well. If a later session meets a real program that needs `value >= 2 + 3`, B is a 33-line follow-up that does not conflict with A. The one thing I would not do is leave it as is: the diagnostic recommends the form it refuses.

This is a recommendation. The ticket is not resolved.

## Limits of this evidence

- I did not search the exemplar corpus for programs that would use a signed refinement. The ticket's own examples (`Delta`, temperature, balance) are the only demand evidence.
- My probes only test acceptance. The verifier added rows that check an admitted value is in range; out-of-range arguments (`-6` into `value >= -5`) stay refused under both options.
- The suite ran with a shell locale of latin1, which accounts for the 6 baseline failures. They are identical across base, A and B.
