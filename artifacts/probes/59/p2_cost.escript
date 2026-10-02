#!/usr/bin/env escript
%% P2 - what a tag test costs: Code bytes, instructions, term size, call time.
%% usage: p2_cost.escript WorkDir [Calls Runs]
main([W | Rest]) ->
    {Calls, Runs} = case Rest of [Cs, Rs] -> {list_to_integer(Cs), list_to_integer(Rs)}; _ -> {10000000, 15} end,
    ok = filelib:ensure_dir(filename:join(W, "x")),
    true = code:add_patha(W),
    mk_driver(W),
    io:format("emu flavor: ~p, OTP ~s, ~p schedulers~n",
              [erlang:system_info(emu_flavor), erlang:system_info(otp_release), erlang:system_info(schedulers)]),
    %% ---- sizes -------------------------------------------------------------
    io:format("~n== Code size: one function projecting the LAST of N fields~n"),
    io:format("~-10s ~-8s ~6s ~6s ~7s ~7s ~6s~n", ["variant","N","file","Code","instrs","dCode","dInstr"]),
    Ns = [1, 5, 20],
    Res = [{N, V, build(W, V, N)} || N <- Ns, V <- [u, g, p, e, i, ig]],
    Get = fun(N, V) -> {_, _, T} = lists:keyfind(V, 2, [X || X = {N0, _, _} <- Res, N0 =:= N]), T end,
    [begin
        {F, C, I} = Get(N, V),
        {_, BC, BI} = case V of ig -> Get(N, i); i -> Get(N, i); _ -> Get(N, u) end,
        io:format("~-10s ~-8w ~6w ~6w ~7w ~7s ~6s~n", [vname(V), N, F, C, I, sgn(C - BC), sgn(I - BI)])
     end || {N, V, _} <- Res],
    %% ---- term size ---------------------------------------------------------
    io:format("~n== Term size (erts_debug:flat_size, words): map of N fields, with and without the Kind key~n"),
    [begin
        Fs = [{list_to_atom("f" ++ integer_to_list(K)), K} || K <- lists:seq(1, N)],
        Without = maps:from_list(Fs),
        With = Without#{kind => order},
        io:format("N=~-3w without Kind ~4w w   with Kind ~4w w   delta ~w w~n",
                  [N, erts_debug:flat_size(Without), erts_debug:flat_size(With),
                   erts_debug:flat_size(With) - erts_debug:flat_size(Without)])
     end || N <- Ns],
    %% ---- call time ---------------------------------------------------------
    io:format("~n== Call time: ~p remote calls per run, min of ~p runs, ns/call~n", [Calls, Runs]),
    Variants = [{N, V} || N <- [5, 20], V <- [u, g, p]],
    %% noise floor: two byte-identical unguarded modules
    build(W, nx, 5), build(W, ny, 5),
    All = Variants ++ [{0, i}, {0, ig}, {5, nx}, {5, ny}],
    build(W, i, 0), build(W, ig, 0),
    Maps = [{0, 5}] ++ [{N, mapfor(N)} || N <- [5, 20]],
    erlang:system_flag(schedulers_online, 1),
    Times = lists:foldl(fun(_Run, Acc) ->
                lists:foldl(fun({N, V} = Key, A) ->
                    Mod = modname(V, N), M = proplists:get_value(N, Maps),
                    T0 = erlang:monotonic_time(nanosecond),
                    _ = drive(Mod, M, Calls, 0),
                    T1 = erlang:monotonic_time(nanosecond),
                    maps:update_with(Key, fun(L) -> [(T1 - T0) / Calls | L] end, [(T1 - T0) / Calls], A)
                end, Acc, All)
             end, #{}, lists:seq(1, Runs)),
    Mins = fun(K) -> lists:min(maps:get(K, Times)) end,
    [io:format("N=~-3w ~-9s min ~6.2f ns/call   (median ~6.2f)~n",
               [N, vname(V), Mins({N, V}), median(maps:get({N, V}, Times))]) || {N, V} <- All],
    Ident = [Mins({5, u}), Mins({5, nx}), Mins({5, ny})],
    Noise = lists:max(Ident) - lists:min(Ident),
    io:format("noise floor = range over three byte-identical-code modules (u, noise-x, noise-y) = ~.2f ns/call~n", [Noise]),
    io:format("N=0   is_integer - int-none (arg is an integer) = ~s ns/call~n", [fsgn(Mins({0, ig}) - Mins({0, i}))]),
    [io:format("N=~-3w guard delta (~s - unguarded) = ~s ns/call   ~s~n",
        [N, vname(V), fsgn(Mins({N, V}) - Mins({N, u})),
         case abs(Mins({N, V}) - Mins({N, u})) =< Noise of true -> "(<= noise floor: not resolved)"; false -> "(above noise floor)" end])
     || N <- [5, 20], V <- [g, p]],
    halt(0).

sgn(X) when X >= 0 -> [$+ | integer_to_list(X)];
sgn(X) -> integer_to_list(X).
fsgn(X) when X >= 0 -> lists:flatten(io_lib:format("+~.2f", [X]));
fsgn(X) -> lists:flatten(io_lib:format("~.2f", [X])).
median(L) -> lists:nth((length(L) + 1) div 2, lists:sort(L)).
vname(u) -> "unguarded"; vname(g) -> "map_get=="; vname(p) -> "pattern";
vname(e) -> "exact-set"; vname(i) -> "int-none"; vname(ig) -> "is_integer"; vname(nx) -> "noise-x"; vname(ny) -> "noise-y".
modname(V, N) -> list_to_atom(lists:flatten(io_lib:format("c_~s_~2..0w", [abbr(V), N]))).
abbr(u) -> "u"; abbr(g) -> "g"; abbr(p) -> "p"; abbr(i) -> "i"; abbr(e) -> "e"; abbr(ig) -> "j"; abbr(nx) -> "x"; abbr(ny) -> "y".
mapfor(N) -> maps:from_list([{fld(K), K} || K <- lists:seq(1, N)] ++ [{kind, order}]).
fld(K) -> list_to_atom("f" ++ integer_to_list(K)).

%% The driver must be COMPILED: an escript body is interpreted by erl_eval.
drive(Mod, M, N, Acc) -> p2_drv:loop(Mod, M, N, Acc).
mk_driver(W) ->
    File = filename:join(W, "p2_drv.erl"),
    ok = file:write_file(File,
        "-module(p2_drv).\n-export([loop/4]).\n"
        "loop(_Mod, _M, 0, Acc) -> Acc;\n"
        "loop(Mod, M, N, Acc) -> loop(Mod, M, N - 1, Acc + Mod:f(M)).\n"),
    {ok, _} = compile:file(File, [{outdir, W}, report]).

%% write, compile (to .beam and to .S), return {FileBytes, CodeBytes, Instrs}
build(W, V, N) ->
    Mod = modname(V, N), Last = atom_to_list(fld(N)),
    Head = case V of
        u  -> "f(M) -> map_get(" ++ Last ++ ", M).";
        nx -> "f(M) -> map_get(" ++ Last ++ ", M).";
        ny -> "f(M) -> map_get(" ++ Last ++ ", M).";
        g  -> "f(M) when map_get(kind, M) == order -> map_get(" ++ Last ++ ", M).";
        p  -> "f(#{kind := order} = M) -> map_get(" ++ Last ++ ", M).";
        e  -> "f(#{kind := order, " ++ string:join([atom_to_list(fld(K)) ++ " := _" || K <- lists:seq(1, N)], ", ") ++ "} = M) -> map_get(" ++ Last ++ ", M).";
        i  -> "f(X) -> X + 1.";
        ig -> "f(X) when is_integer(X) -> X + 1."
    end,
    Src = io_lib:format("-module(~s).~n-export([f/1]).~n~s~n", [Mod, Head]),
    File = filename:join(W, atom_to_list(Mod) ++ ".erl"),
    ok = file:write_file(File, Src),
    {ok, Mod, Bin} = compile:file(File, [binary, deterministic, report]),
    ok = file:write_file(filename:join(W, atom_to_list(Mod) ++ ".beam"), Bin),
    {ok, _} = compile:file(File, ['S', deterministic, {outdir, W}, report]),
    {ok, Terms} = file:consult(filename:join(W, atom_to_list(Mod) ++ ".S")),
    {ok, {_, [{"Code", Code}]}} = beam_lib:chunks(Bin, ["Code"]),
    {byte_size(Bin), byte_size(Code), fn_instrs(Terms, f, 1)}.

fn_instrs(Terms, F, A) ->
    Is = take(Terms, F, A),
    length([I || I <- Is, not is_tuple(I) orelse not lists:member(element(1, I), [label, line, '%', func_info])]).
take([{function, F, A, _} | T], F, A) -> until(T);
take([_ | T], F, A) -> take(T, F, A).
until([{function, _, _, _} | _]) -> [];
until([H | T]) -> [H | until(T)];
until([]) -> [].
