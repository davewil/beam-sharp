-module(survive).
-export([main/0]).
%% Probe 59i2: of the is_integer/is_float tests the widening (B) adds to the emitted abstract code of the compiling
%% corpus, how many are still in the OPTIMISED beam (not elided by erlc)?
n(Dir, M, Pat) ->
    {beam_file, _, _, _, _, Fs} = beam_disasm:file(Dir ++ "/" ++ M ++ ".beam"),
    length([I || {function, _, _, _, Is} <- Fs, I <- Is, is_tuple(I), element(1, I) =:= test, lists:member(element(2, I), Pat)]).
main() ->
    Ms = lists:sort([filename:basename(F, ".beam") || F <- filelib:wildcard("base/*.beam")]),
    Rows = [{M, n("base", M, [is_integer, is_float]), n("B", M, [is_integer, is_float])} || M <- Ms],
    [io:format("~-24s base=~-3w B=~-3w added=~w~n", [M, A, B, B - A]) || {M, A, B} <- Rows, B =/= A],
    io:format("TOTAL optimised-beam is_integer/is_float tests: base=~w B=~w added=~w (abstract-code added: 19, see corpus.out)~n",
              [lists:sum([A || {_, A, _} <- Rows]), lists:sum([B || {_, _, B} <- Rows]), lists:sum([B - A || {_, A, B} <- Rows])]),
    halt().
