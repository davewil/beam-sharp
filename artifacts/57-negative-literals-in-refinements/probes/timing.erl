%% timing.erl  --  run: erl -noshell -pa EBIN -pa PROBES -eval 'timing:main(Runs),halt().'
%% Times (a) lex+parse of every compiler/examples/*/*.bs, (b) bs_check:check on the ones that
%% check standalone, (c) a synthetic 300-declaration refinement file (negatives only if the
%% build accepts them). Prints microsecond medians over Runs runs after a 10-run warm-up.
-module(timing).
-export([main/1]).

main(Runs) ->
    Files = filelib:wildcard("/home/user/beam-sharp/compiler/examples/*/*.bs"),
    Srcs = [begin {ok, B} = file:read_file(F), binary_to_list(B) end || F <- Files],
    Parse = fun(Src) -> {ok, T, _} = bs_lexer:string(Src), bs_parser:parse(T) end,
    Parsed = [{S, D} || S <- Srcs, {ok, D} <- [Parse(S)]],
    Checkable = [D || {_, D} <- Parsed, is_ok(catch_check(D))],
    Synth = synth(300, "-"),
    Pos = synth(300, ""),
    io:format("files=~p parsed=~p checkable_standalone=~p~n", [length(Srcs), length(Parsed), length(Checkable)]),
    SynthOk = case Parse(Synth) of {ok, D1} -> case catch_check(D1) of {ok, _, _} -> ok; _ -> refused end; _ -> parse_error end,
    io:format("synthetic_negative_file=~p~n", [SynthOk]),
    t("parse examples", Runs, fun() -> [Parse(S) || S <- Srcs] end),
    t("check examples", Runs, fun() -> [bs_check:check(D) || D <- Checkable] end),
    t("parse synth-pos", Runs, fun() -> Parse(Pos) end),
    t("check synth-pos", Runs, fun() -> {ok, D} = Parse(Pos), bs_check:check(D) end),
    t("parse synth-neg", Runs, fun() -> Parse(Synth) end),
    t("check synth-neg", Runs, fun() -> {ok, D} = Parse(Synth), catch bs_check:check(D) end).

is_ok(T) when is_tuple(T) -> element(1, T) =:= ok;
is_ok(_) -> false.

catch_check(D) -> try bs_check:check(D) catch _:_ -> error end.

synth(N, Sign) ->
    lists:flatten(["module Synth\n",
      [io_lib:format("type T~p = int where value >= ~s~p and value <= ~p\n", [I, Sign, I, I + 1000]) || I <- lists:seq(1, N)],
      "public int Id(T1 b)\nId(b) -> b\n"]).

t(Name, Runs, F) ->
    [F() || _ <- lists:seq(1, 10)],
    Us = lists:sort([element(1, timer:tc(F)) || _ <- lists:seq(1, Runs)]),
    Med = lists:nth((Runs + 1) div 2, Us),
    io:format("~-18s runs=~p median=~pus min=~pus p90=~pus max=~pus~n",
              [Name, Runs, Med, hd(Us), lists:nth(max(1, round(Runs * 0.9)), Us), lists:last(Us)]).
