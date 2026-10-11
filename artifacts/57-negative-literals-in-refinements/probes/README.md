# Probes for ticket 57 (ENG-239)

Environment: `source $S/env.sh` where `S=/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad`
(OTP 29, Elixir 1.20.4, Gleam 1.19.1, Elm 0.19.0). Repo rev 019533d.

The patched compilers are built from copies of `compiler/src` in `$S/57/src-{A,B,Barith}`
(`$S/57/build.sh SRC EBIN` builds one). The patches are in `../patch-{A,B,Barith}.diff`.
A = grammar fold (`negate/2` folds an integer literal, as it already folds a float one).
B = checker fold, unary minus only, in `comparison/1`.
Barith = checker fold of `+ - *` and unary minus in `comparison/1`, and `type_of({e_neg, _, {e_int,..}})`.

| probe | one command | shows |
|---|---|---|
| `corpus.sh [EBIN]` | `./corpus.sh` (reference) or `./corpus.sh $S/57/ebin-A` | 34 programs, accepted/refused per build; `want` column is the post-fix wish, N* rows are negative controls that must stay refused. A harness failure exits 2 rather than reading as "refused". |
| `matrix.py` | `python3 -I matrix.py` | joins `corpus.{reference,A,B,Barith}.out` into `corpus.matrix.out` and checks the controls |
| `semantics.sh [EBIN]` | `./semantics.sh $S/57/ebin-A` | literal typing, `n / -0`, runtime values, emitted abstract form, guard exhaustiveness, residual text |
| `arith_diff.sh` | `./arith_diff.sh` | 21 arithmetic expressions with `-N`, reference vs A, run-time values; has a control that must fire |
| `shape.sh` | `./shape.sh` | parsed term and `erts_debug:flat_size`, .beam size, Code-chunk md5 per build |
| `timing.sh` + `timing_summary.py` | `./timing.sh > timing.out; python3 -I timing_summary.py` | 5 interleaved rounds x 40 runs per workload per build |
| `neighbour_erlang.sh` | `./neighbour_erlang.sh` | erl_parse of `-5` in expr/pattern/guard/type, erl_eval:partial_eval, lint control |
| `neighbour_elixir.exs` | `elixir neighbour_elixir.exs` | Code.string_to_quoted of `-5`; control `-x` in a pattern |
| `neighbour_gleam.sh` | `./neighbour_gleam.sh` | `gleam build` on 15 snippets; abstract form of the result |

Known `!!` rows in every build, patched or not: C6, E1, E4 (`value == K`, any K). That is a separate,
pre-existing emission bug: `bs_emit:int_part/1` writes `{type,_,range,[K,K]}` for a one-integer interval and
`erl_lint` refuses it (`bad range type`). `value == 5` fails the same way on the unpatched compiler (E1).
