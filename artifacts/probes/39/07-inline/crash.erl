%% Does inlining change what a crash inside a private function looks like?
-module(crash).
-export([run/0]).
run() ->
    {ok, Fs} = epp:parse_file("crash_src.erl", []),
    [begin {ok, M, Bin} = compile:noenv_forms(rn(Fs, N), [binary, debug_info | O]),
           {module, M} = code:load_binary(M, "x", Bin),
           io:format("~-12s ~p~n", [N, try M:go(2) catch C:R:St -> {C, R, [{F,A} || {_,F,A,_} <- St]} end])
     end || {N, O} <- [{plain,[]}, {inlined,[inline]}]],
    halt().
rn(Fs, N) -> [case F of {attribute,A,module,_} -> {attribute,A,module,N}; _ -> F end || F <- Fs].
