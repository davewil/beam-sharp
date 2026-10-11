-module(probe_c_cost).
-export([main/1]).
-define(N, 10000000).
-define(RUNS, 15).

main(Dir) ->
    io:format("OTP ~s, erts ~s, JIT=~p~n", [erlang:system_info(otp_release), erlang:system_info(version),
              erlang:system_info(emu_flavor)]),
    sizes(Dir),
    time(Dir).

beam(Dir, V, M) -> filename:join([Dir, "out_" ++ V, M ++ ".beam"]).

code_size(F) ->
    {ok, _, Chunks} = beam_lib:all_chunks(F),
    {byte_size(proplists:get_value("Code", Chunks)), filelib:file_size(F), stripped(F)}.
stripped(F) ->
    {ok, Bin} = file:read_file(F),
    {ok, {_, B}} = beam_lib:strip(Bin), byte_size(B).

sizes(Dir) ->
    io:format("~n== bytes  (Code chunk / .beam file / .beam stripped of debug_info)~n"),
    io:format("   One module = 1 public fn calling 1 private fn (+ 1 public/private int pair in Scope)~n"),
    [begin
         [begin
              {C, F, S} = code_size(beam(Dir, V, M)),
              io:format("   ~-7s ~-7s Code=~p file=~p stripped=~p~n", [M, V, C, F, S])
          end || V <- ["base", "notag", "widen"]],
         {Cb,_,Sb} = code_size(beam(Dir, "base", M)),
         {Cn,_,Sn} = code_size(beam(Dir, "notag", M)),
         {Cw,_,Sw} = code_size(beam(Dir, "widen", M)),
         io:format("   ~s: private TAG test = ~p Code bytes (stripped file ~p);  private KIND test = ~p Code bytes (stripped file ~p)~n",
                   [M, Cb - Cn, Sb - Sn, Cw - Cb, Sw - Sb])
     end || M <- ["Scope", "Scope8", "ScopeI"]],
    %% negative control: base vs base must be 0
    {C1,_,_} = code_size(beam(Dir, "base", "Scope")),
    {C2,_,_} = code_size(beam(Dir, "base", "Scope")),
    io:format("   control (same beam twice): delta = ~p~n", [C1 - C2]).

%% ---- time ------------------------------------------------------------------
load(Dir, V, M) ->
    Mod = list_to_atom(M),
    code:purge(Mod), code:delete(Mod), code:purge(Mod),
    {ok, Bin} = file:read_file(beam(Dir, V, M)),
    {module, Mod} = code:load_binary(Mod, "x.beam", Bin).

driver(Name, Mod, Fun, ArgSrc) ->
    Src = lists:flatten(io_lib:format(
        "-module(~s).~n-export([loop/3]).~n"
        "loop(0, _A, Acc) -> Acc;~n"
        "loop(N, A, Acc) -> loop(N - 1, A, (Acc + '~s':'~s'(~s)) band 16#FFFF).~n", [Name, Mod, Fun, ArgSrc])),
    {ok, Toks, _} = erl_scan:string("x"), _ = Toks,
    Dir = filename:join(os:getenv("HOME", "/tmp"), ".probe_c_drv"),
    ok = filelib:ensure_dir(filename:join(Dir, "x")),
    File = filename:join(Dir, atom_to_list(Name) ++ ".erl"),
    ok = file:write_file(File, Src),
    {ok, _} = compile:file(File, [{outdir, Dir}]),
    {module, Name} = code:load_abs(filename:join(Dir, atom_to_list(Name))),
    ok.

run(Drv, Arg) ->
    {T, _} = timer:tc(Drv, loop, [?N, Arg, 0]),
    T * 1000 / ?N.      %% ns per call

order(_M, Kind) -> #{'Id' => 1, 'Total' => 2, 'Kind' => Kind, 'A'=>1,'B'=>2,'C'=>3,'D'=>4,'E'=>5,'F'=>6,'G'=>7,'H'=>8}.

time(Dir) ->
    io:format("~n== call time, ns/call: ~p calls per run, ~p runs, runs of the variants INTERLEAVED~n", [?N, ?RUNS]),
    io:format("   timer:tc resolution: 1 us per run => 1e-6 s / ~p calls = ~.4f ns/call (quantisation floor)~n",
              [?N, 1000 / ?N]),
    ok = driver(drv_rec, 'Scope', 'PubRec', "A"),
    ok = driver(drv_int, 'Scope', 'PubInt', "A"),
    ok = driver(drv_rec8, 'Scope8', 'PubRec', "A"),
    ok = driver(drv_sum, 'ScopeI', 'Sum', "A"),
    Ord3 = #{'Id' => 1, 'Total' => 2, 'Kind' => 'Scope.Order'},
    Ord8 = #{'A'=>1,'B'=>2,'C'=>3,'D'=>4,'E'=>5,'F'=>6,'G'=>7,'H'=>8,'Kind'=>'Scope8.Order8'},
    Cases = [{"record(3 fields): PubRec -> private PrivRec (tag test lives in PrivRec)", "Scope", drv_rec, Ord3, ["base","notag"]},
             {"record(8 fields): PubRec -> private PrivRec", "Scope8", drv_rec8, Ord8, ["base","notag"]},
             {"int, erlc can prove the arg: PubInt -> private PrivInt", "Scope", drv_int, 7, ["base","widen"]},
             {"int, erlc cannot prove the arg: Sum(list of 8 ints) -> private Bump(h) per element", "ScopeI", drv_sum, lists:seq(1,8), ["base","widen"]}],
    [begin
         Res = [{V, []} || V <- Vs],
         Acc = lists:foldl(fun(_, A) ->
                   lists:foldl(fun(V, A2) ->
                       load(Dir, V, M),
                       %% warm
                       _ = run(Drv, Arg),
                       T = run(Drv, Arg),
                       lists:keystore(V, 1, A2, {V, [T | proplists:get_value(V, A2)]})
                   end, A, Vs)
               end, Res, lists:seq(1, ?RUNS)),
         io:format("~n   ~s~n", [Cap]),
         [begin
              S = lists:sort(Ts),
              io:format("     ~-6s min=~.3f  median=~.3f  max=~.3f  ns/call~n",
                        [V, hd(S), lists:nth(?RUNS div 2 + 1, S), lists:last(S)])
          end || {V, Ts} <- Acc],
         %% noise floor: base against base (reload same beam, alternate)
         load(Dir, "base", M), _ = run(Drv, Arg),
         Nz = [begin load(Dir, "base", M), run(Drv, Arg) end || _ <- lists:seq(1, ?RUNS)],
         NS = lists:sort(Nz),
         io:format("     noise floor (base re-loaded, same beam) min=~.3f median=~.3f max=~.3f~n",
                   [hd(NS), lists:nth(?RUNS div 2 + 1, NS), lists:last(NS)])
     end || {Cap, M, Drv, Arg, Vs} <- Cases],
    ok.
