#!/usr/bin/env escript
%% Cost side of `-compile(inline)`: compile time (median of 7) and beam size, on large installed OTP modules.
main([]) ->
    Root = code:root_dir(),
    Mods = ["lib/stdlib-*/src/lists.erl", "lib/stdlib-*/src/string.erl", "lib/stdlib-*/src/erl_scan.erl"],
    io:format("~-24s ~-8s ~10s ~10s~n", ["module","opts","median ms","bytes"]),
    [begin
         [F] = filelib:wildcard(filename:join(Root, M)),
         [begin
              Ts = lists:sort([begin {T,{ok,_,Bin,_}} = timer:tc(fun() ->
                        compile:file(F, [binary, return, nowarn_unused_function | O]) end), {T,Bin} end
                        || _ <- lists:seq(1, 7)]),
              {T, Bin} = lists:nth(4, Ts),
              io:format("~-24s ~-8s ~10.1f ~10w~n", [filename:basename(M), Tag, T/1000, byte_size(Bin)])
          end || {Tag, O} <- [{"default", []}, {"inline", [inline]}]]
     end || M <- Mods].
