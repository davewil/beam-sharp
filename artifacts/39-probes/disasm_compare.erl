%%% Probe for ticket 39: disassembles the REAL, actually-compiled .beam files
%%% from a build.sh run (Day01.beam from bsc, bench_erl.beam from erlc) with
%%% beam_disasm:file/1 -- the module OTP's own compiler app ships for exactly
%%% this purpose -- and prints Wrap/wrap and Spin/spin side by side so the
%%% {tr,...} JIT type annotations can be compared directly on the ACTUAL
%%% shipped bytecode, not a re-derived approximation.
-module(disasm_compare).
-export([main/1]).

main([Dir]) ->
    show(filename:join(Dir, "Day01.beam"), 'Wrap', 1),
    show(filename:join(Dir, "Day01.beam"), 'Spin', 4),
    show(filename:join(Dir, "bench_erl.beam"), wrap, 1),
    show(filename:join(Dir, "bench_erl.beam"), spin, 4),
    halt().

show(Beam, Name, Arity) ->
    {beam_file, _, _, _, _, Fns} = beam_disasm:file(Beam),
    io:format("=== ~s ~p/~p ===~n", [Beam, Name, Arity]),
    [io:format("~p~n~n", [F])
     || {function, N, A, _, _} = F <- Fns, N =:= Name, A =:= Arity].
