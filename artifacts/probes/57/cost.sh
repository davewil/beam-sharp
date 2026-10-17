#!/usr/bin/env bash
# cost.sh — parse-only time (lexed tokens -> forms, no check, no erlc, no disk) for a module of
# 8 refinements with a negative bound, per variant: warm-up, then the MIN of 7 rounds of 400.
# The checker options A1/A2 do not touch the parser, so base/A1/A2 are the SAME parser and
# their spread is the noise floor; B and C can only be called different if they leave it.
set -uo pipefail
WORK=${WORK:-/tmp/p57work}
for v in base optA1 optA2 optB optC; do
  erl -noshell -pa "$WORK/$v/ebin" -eval '
    Src = "module A\n" ++ lists:flatten([io_lib:format("type T~b = int where value >= -5 and value <= 100\n", [I]) || I <- lists:seq(1, 8)])
          ++ "public int Id(T1 b)\nId(b) -> b\n",
    {ok, Toks, _} = bs_lexer:string(Src),
    One = fun() -> {ok, F} = bs_parser:parse(Toks), F end,
    Round = fun() -> {T, _} = timer:tc(fun() -> [One() || _ <- lists:seq(1, 400)] end), T / 400 end,
    _ = Round(), _ = Round(),
    Min = lists:min([Round() || _ <- lists:seq(1, 7)]),
    io:format("~-6s parse-only min ~.2f us/iter~n", ["'$v'", Min]), halt().' 2>&1 | head -3
done
