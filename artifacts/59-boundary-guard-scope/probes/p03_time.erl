%%% p03_time -- per-call / per-iteration time of the guard shapes, exported vs private.
%%%
%%% LABEL: MEASURED-on-a-hand-written-analogue (NOT bsc). Same analogue assumptions as p01_shapes.erl.
%%% The machine is a shared 4-core sandbox VM, so absolute ns are noisy; only same-run deltas
%%% against the noise-floor twins mean anything. Variants are interleaved round-robin, one rep of
%%% each per round, so drift hits all variants alike.
%%%
%%% PREDICTIONS (written before the first run):
%%%   T1. Single exported call, one guard (tag or is_integer): delta vs unguarded within noise
%%%       (ticket 18 RECORDED <= 0.09 ns resolution on arm64/28.5; I expect OTP 25 x86-64 to give
%%%       a delta of 0..1 ns that is at or near my own noise floor).
%%%   T2. Private recursive int loop, caller proves integers: guarded == unguarded (test elided),
%%%       so widening the KIND test to private costs nothing in time there.
%%%   T3. Private recursive int loop, caller unknown: guard kept -> small positive delta per iteration.
%%%   T4. Exported recursive int loop: every self call re-enters the labelled entry, so the guard
%%%       is paid per iteration -> small positive delta.
%%%   T5. Private recursive RECORD loop: tag test is NOT elided (p01 P3), so it is paid per iteration
%%%       per clause -> small positive delta, present even though the caller ran the same test.
-module(p03_time).
-export([go/0, drive/3, calls/3]).

-define(TAG, "erlang:map_get('Kind', O) =:= 'Order'").
-define(ROUNDS, 25).
-define(ITERS, 2000000).

variants() ->
    [%% ---- single exported function: entry cost --------------------------------------------
     {"s_tag_u",  call, "-export([f/1]).\nf(O) -> erlang:map_get(total, O)."},
     {"s_tag_g",  call, "-export([f/1]).\nf(O) when " ?TAG " -> erlang:map_get(total, O)."},
     {"s_tag_u2", call, "-export([f/1]).\nf(O) -> erlang:map_get(total, O)."},           % noise twin
     {"s_int_u",  callint, "-export([f/1]).\nf(N) -> N + 1."},
     {"s_int_g",  callint, "-export([f/1]).\nf(N) when erlang:is_integer(N) -> N + 1."},
     {"s_int_u2", callint, "-export([f/1]).\nf(N) -> N + 1."},                            % noise twin
     %% ---- private recursive INT loop. run/2 is the exported entry -------------------------
     %% run guarded = B# exported int params (caller proves integer). loop guarded per clause as
     %% bs_emit would (clause 1: literal 0 pins N, so only A is tested).
     {"i_priv_u",  run, "-export([run/2]).\n"
        "run(N, A) when erlang:is_integer(N) andalso erlang:is_integer(A) -> loop(N, A).\n"
        "loop(0, A) -> A;\nloop(N, A) -> loop(N - 1, A + N)."},
     {"i_priv_g",  run, "-export([run/2]).\n"
        "run(N, A) when erlang:is_integer(N) andalso erlang:is_integer(A) -> loop(N, A).\n"
        "loop(0, A) when erlang:is_integer(A) -> A;\n"
        "loop(N, A) when erlang:is_integer(N) andalso erlang:is_integer(A) -> loop(N - 1, A + N)."},
     {"i_priv_gU", run, "-export([run/2]).\n"          % caller does NOT prove integers
        "run(N, A) -> loop(N, A).\n"
        "loop(0, A) when erlang:is_integer(A) -> A;\n"
        "loop(N, A) when erlang:is_integer(N) andalso erlang:is_integer(A) -> loop(N - 1, A + N)."},
     {"i_priv_uU", run, "-export([run/2]).\n"
        "run(N, A) -> loop(N, A).\n"
        "loop(0, A) -> A;\nloop(N, A) -> loop(N - 1, A + N)."},
     {"i_ex_u",    loop, "-export([loop/2]).\n"
        "loop(0, A) -> A;\nloop(N, A) -> loop(N - 1, A + N)."},
     {"i_ex_g",    loop, "-export([loop/2]).\n"
        "loop(0, A) when erlang:is_integer(A) -> A;\n"
        "loop(N, A) when erlang:is_integer(N) andalso erlang:is_integer(A) -> loop(N - 1, A + N)."},
     {"i_ex_u2",   loop, "-export([loop/2]).\n"
        "loop(0, A) -> A;\nloop(N, A) -> loop(N - 1, A + N)."},
     %% ---- private recursive RECORD loop, read-only (no allocation): guard cost isolated ----
     {"r_priv_u",  runr, "-export([run/2]).\n"
        "run(N, O) when " ?TAG " -> loop(N, O, 0).\n"
        "loop(0, _O, A) -> A;\nloop(N, O, A) -> loop(N - 1, O, A + erlang:map_get(total, O))."},
     {"r_priv_g",  runr, "-export([run/2]).\n"
        "run(N, O) when " ?TAG " -> loop(N, O, 0).\n"
        "loop(0, O, A) when " ?TAG " -> A;\n"
        "loop(N, O, A) when " ?TAG " -> loop(N - 1, O, A + erlang:map_get(total, O))."},
     {"r_priv_u2", runr, "-export([run/2]).\n"
        "run(N, O) when " ?TAG " -> loop(N, O, 0).\n"
        "loop(0, _O, A) -> A;\nloop(N, O, A) -> loop(N - 1, O, A + erlang:map_get(total, O))."},
     %% ---- private recursive RECORD loop that rebuilds the record each turn (allocates) -----
     {"u_priv_u",  runr, "-export([run/2]).\n"
        "run(N, O) when " ?TAG " -> loop(N, O, 0).\n"
        "loop(0, _O, A) -> A;\n"
        "loop(N, O, A) -> loop(N - 1, O#{total := erlang:map_get(total, O) + 1}, A + 1)."},
     {"u_priv_g",  runr, "-export([run/2]).\n"
        "run(N, O) when " ?TAG " -> loop(N, O, 0).\n"
        "loop(0, O, A) when " ?TAG " -> A;\n"
        "loop(N, O, A) when " ?TAG " -> loop(N - 1, O#{total := erlang:map_get(total, O) + 1}, A + 1)."}
    ].

go() ->
    Dir = "p03_out",
    ok = filelib:ensure_dir(filename:join(Dir, "x")),
    true = code:add_patha(Dir),
    io:format("OTP ~s erts ~s emu_flavor=~p schedulers_online=~b~n",
              [erlang:system_info(otp_release), erlang:system_info(version),
               erlang:system_info(emu_flavor), erlang:system_info(schedulers_online)]),
    io:format("rounds=~b, iterations per timed call=~b (single-call variants: ~b calls per rep)~n",
              [?ROUNDS, ?ITERS, ?ITERS]),
    Vs = [{list_to_atom(N), K, build(Dir, N, B)} || {N, K, B} <- variants()],
    %% warm-up round, discarded
    [_ = time_one(M, K) || {M, K, _} <- Vs],
    Rounds = [[{M, time_one(M, K)} || {M, K, _} <- Vs] || _ <- lists:seq(1, ?ROUNDS)],
    Stats = [{M, stats([proplists:get_value(M, R) || R <- Rounds])} || {M, _, _} <- Vs],
    io:format("~n~-12s ~9s ~9s ~9s ~9s   (ns per call or per loop iteration)~n",
              ["variant", "median", "min", "p25", "p75"]),
    [io:format("~-12s ~9.3f ~9.3f ~9.3f ~9.3f~n", [M, Med, Min, P25, P75])
     || {M, {Med, Min, P25, P75}} <- Stats],
    Med = fun(M) -> element(1, proplists:get_value(M, Stats)) end,
    Min = fun(M) -> element(2, proplists:get_value(M, Stats)) end,
    D = fun(A, B) -> io_lib:format("median ~s  min ~s", [sgf(Med(A) - Med(B)), sgf(Min(A) - Min(B))]) end,
    io:format("~nNOISE FLOOR (identical twins), guarded-vs-unguarded deltas below should be read against these:~n"),
    io:format("  s_tag  twin: ~s~n  s_int  twin: ~s~n  i_ex   twin: ~s~n  r_priv twin: ~s~n",
              [D('s_tag_u2', 's_tag_u'), D('s_int_u2', 's_int_u'), D('i_ex_u2', 'i_ex_u'), D('r_priv_u2', 'r_priv_u')]),
    io:format("~nDELTAS (guarded - unguarded), ns per call/iteration:~n"),
    io:format("  single exported, tag test        : ~s~n", [D('s_tag_g', 's_tag_u')]),
    io:format("  single exported, is_integer      : ~s~n", [D('s_int_g', 's_int_u')]),
    io:format("  private loop, int, caller proves : ~s~n", [D('i_priv_g', 'i_priv_u')]),
    io:format("  private loop, int, caller unknown: ~s~n", [D('i_priv_gU', 'i_priv_uU')]),
    io:format("  exported loop, int               : ~s~n", [D('i_ex_g', 'i_ex_u')]),
    io:format("  private loop, record read-only   : ~s~n", [D('r_priv_g', 'r_priv_u')]),
    io:format("  private loop, record rebuilt     : ~s~n", [D('u_priv_g', 'u_priv_u')]),
    [dump_loop(Dir, N) || N <- ["i_priv_g", "i_priv_gU", "i_ex_g", "r_priv_g"]],
    ok.

build(Dir, Name, Body) ->
    File = filename:join(Dir, Name ++ ".erl"),
    ok = file:write_file(File, lists:flatten(io_lib:format("-module(~s).\n~s\n", [Name, Body]))),
    {ok, _} = compile:file(File, [debug_info, deterministic, {outdir, Dir}, return_errors]),
    ok.

order() -> #{'Kind' => 'Order', id => 1, total => 3, status => draft}.

%% Returns ns per call / iteration for one timed rep.
time_one(M, call)    -> T = timer:tc(fun() -> calls(M, order(), ?ITERS) end), ns(T, ?ITERS);
time_one(M, callint) -> T = timer:tc(fun() -> calls(M, 41, ?ITERS) end), ns(T, ?ITERS);
time_one(M, run)     -> T = timer:tc(fun() -> M:run(?ITERS, 0) end), ns(T, ?ITERS);
time_one(M, loop)    -> T = timer:tc(fun() -> M:loop(?ITERS, 0) end), ns(T, ?ITERS);
time_one(M, runr)    -> T = timer:tc(fun() -> M:run(?ITERS, order()) end), ns(T, ?ITERS).

ns({Us, _}, N) -> Us * 1000 / N.

%% Remote call through a variable module: the harness cost is the same for every variant.
calls(M, Arg, N) -> calls(M, Arg, N, 0).
calls(_, _, 0, A) -> A;
calls(M, Arg, N, A) -> calls(M, Arg, N - 1, A + M:f(Arg)).

drive(_, _, _) -> ok.

stats(Xs) ->
    S = lists:sort(Xs), N = length(S),
    {lists:nth((N + 1) div 2, S), hd(S), lists:nth(max(1, N div 4), S), lists:nth(min(N, (3 * N) div 4 + 1), S)}.

sgf(X) when X >= 0 -> io_lib:format("+~.3f", [X]);
sgf(X) -> io_lib:format("~.3f", [X]).

%% The loop/3 (or loop/2) asm, so the timing deltas can be read against what was actually emitted.
dump_loop(Dir, Name) ->
    File = filename:join(Dir, Name ++ ".erl"),
    {ok, _} = compile:file(File, [deterministic, 'S', {outdir, Dir}, return_errors]),
    {ok, Bin} = file:read_file(filename:join(Dir, Name ++ ".S")),
    Ls = string:split(binary_to_list(Bin), "\n", all),
    {_, Tail} = lists:splitwith(fun(L) -> not lists:prefix("{function, loop,", L) end, Ls),
    {Fn, _} = lists:splitwith(fun(L) -> not lists:prefix("{function, module_info", L) end, Tail),
    io:format("~n--- asm of loop in ~s (line/func_info/var_info annotations dropped) ---~n", [Name]),
    [io:format("~s~n", [L]) || L <- Fn, not lists:prefix("    {line", L), not lists:prefix("    {'%'", L),
                               not lists:prefix("    {func_info", L), L =/= ""].
