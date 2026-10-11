#!/usr/bin/env escript
%% usage: 05_alias_cost.escript PATCHED_EBIN WORKDIR
%% For N in 1,10,50,200 public functions and each alias mode: .beam size, export table, code chunk,
%% atom table, loaded code memory, and compile time (median/min/max of 21 in-VM runs after 1 warm-up).
main([Ebin, Work]) ->
    true = code:add_patha(Ebin),
    io:format("OTP ~s, compiler ebin ~s~n", [erlang:system_info(otp_release), Ebin]),
    io:format("~-5s ~-15s ~8s ~7s ~8s ~8s ~8s | compile ms: ~7s ~7s ~7s~n",
              ["N", "mode", "beam B", "exports", "ExpT B", "Code B", "AtU8 B", "median", "min", "max"]),
    [row(N, Mode, Work) || N <- [1, 10, 50, 200], Mode <- [none, forward, forward_nospec, dup]].

gen(N, Work) ->
    Mod = "Gen" ++ integer_to_list(N),
    Dir = filename:join([Work, "gen", Mod]),
    ok = filelib:ensure_dir(filename:join(Dir, "x")),
    Fns = [io_lib:format("public int ComputeTotal~w(int n)~n~nComputeTotal~w(n) -> n + ~w~n~n", [K, K, K])
           || K <- lists:seq(1, N)],
    ok = file:write_file(filename:join(Dir, string:lowercase(Mod) ++ ".bs"),
                         ["module ", Mod, "\n\n", Fns]),
    {Mod, Dir}.

row(N, Mode, Work) ->
    {Mod, Dir} = gen(N, Work),
    Out = filename:join([Work, "out", atom_to_list(Mode), integer_to_list(N)]),
    ok = filelib:ensure_dir(filename:join(Out, "x")),
    true = os:putenv("BS_ALIAS_MODE", atom_to_list(Mode)),
    Run = fun() -> {T, R} = timer:tc(fun() -> bsc:file_to_dir(Dir, Out) end), {T, R} end,
    _ = Run(),                                   % warm-up, discarded
    Ts = [element(1, Run()) || _ <- lists:seq(1, 21)],
    Beam = filename:join(Out, Mod ++ ".beam"),
    {ok, Bin} = file:read_file(Beam),
    {ok, _, Chunks} = beam_lib:all_chunks(Bin),
    Sz = fun(Id) -> case lists:keyfind(Id, 1, Chunks) of {_, B} -> byte_size(B); false -> 0 end end,
    {ok, {_, [{exports, Ex}]}} = beam_lib:chunks(Bin, [exports]),
    M0 = erlang:memory(code),
    {module, M} = code:load_binary(list_to_atom(Mod), Beam, Bin),
    M1 = erlang:memory(code),
    code:purge(M), code:delete(M), code:purge(M),
    Sorted = lists:sort(Ts), Med = lists:nth(11, Sorted),
    io:format("~-5w ~-15w ~8w ~7w ~8w ~8w ~8w | compile ms: ~7.1f ~7.1f ~7.1f   (code mem +~w B)~n",
              [N, Mode, byte_size(Bin), length(Ex), Sz("ExpT"), Sz("Code"), Sz("AtU8"),
               Med / 1000, hd(Sorted) / 1000, lists:last(Sorted) / 1000, M1 - M0]).
