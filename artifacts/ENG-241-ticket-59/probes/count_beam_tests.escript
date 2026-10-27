#!/usr/bin/env escript
%% usage: count_beam_tests.escript DIR -- is_integer / is_float / is_eq_exact test INSTRUCTIONS in compiled beams
main([Dir]) ->
    Bs = filelib:wildcard(filename:join(Dir, "**/*.beam")),
    Count = fun(Name, B) ->
        {beam_file, _, _, _, _, Fs} = beam_disasm:file(B),
        lists:sum([length([I || I <- Is, is_tuple(I), element(1, I) =:= test, element(2, I) =:= Name])
                   || {function,_,_,_,Is} <- Fs]) end,
    {I, F, E} = lists:foldl(fun(B, {I0,F0,E0}) -> {I0 + Count(is_integer, B), F0 + Count(is_float, B), E0 + Count(is_eq_exact, B)} end, {0,0,0}, Bs),
    io:format("beams=~p is_integer_insns=~p is_float_insns=~p is_eq_exact_insns=~p~n", [length(Bs), I, F, E]).
