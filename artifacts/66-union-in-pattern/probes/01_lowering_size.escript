#!/usr/bin/env escript
%% Probe 01: size of the four lowerings as the union grows 2/5/10/20, at three
%% body sizes. Command:  escript 01_lowering_size.escript   (run from this dir)
%% Asserts: (a) every variant compiles, (b) every variant returns the same
%% result as `dup` on every member AND on a non-member (differential), (c) the
%% fitted slopes are computed from the data; verdict lines are derived, so a
%% different toolchain can flip them.
main(_) ->
    {ok, lib_gen, B0} = compile:file("lib_gen.erl", [binary, return_errors]),
    {module, lib_gen} = code:load_binary(lib_gen, "lib_gen.erl", B0),
    Ns = [2, 5, 10, 20], Bs = [1, 8, 32],
    Rows = [{B, V, N, measure(V, N, B, [])} || B <- Bs, V <- lib_gen:variants(), N <- Ns],
    NoShare = [{B, V, N, measure(V, N, B, [no_share_opt])} || B <- Bs, V <- [dup], N <- Ns],
    io:format("~-4s ~-13s ~3s | ~8s ~8s ~8s ~8s ~7s ~9s~n",
              ["B","variant","N","beam","stripped","asm_ins","core_ln","sel_val","opts"]),
    [row(R, "default") || R <- Rows], [row(R, "no_share") || R <- NoShare],
    io:format("~nLEAST-SQUARES SLOPE per added union member (bytes of stripped .beam | asm instructions)~n"),
    Slopes = [begin
        Pts = [{N, S, I} || {B1, V1, N, #{stripped := S, ins := I}} <- Rows, B1 =:= B, V1 =:= V],
        {B, V, slope([{N, S} || {N, S, _} <- Pts]), slope([{N, I} || {N, _, I} <- Pts])}
      end || B <- Bs, V <- lib_gen:variants()],
    [io:format("B=~-3w ~-13s ~8.1f bytes/member  ~7.2f ins/member~n", [B, V, Sb, Si]) || {B, V, Sb, Si} <- Slopes],
    NS = [begin
        Pts = [{N, S, I} || {B1, _, N, #{stripped := S, ins := I}} <- NoShare, B1 =:= B],
        {B, slope([{N, S} || {N, S, _} <- Pts]), slope([{N, I} || {N, _, I} <- Pts])}
      end || B <- Bs],
    [io:format("B=~-3w dup+no_share_opt ~8.1f bytes/member  ~7.2f ins/member~n", [B, Sb, Si]) || {B, Sb, Si} <- NS],
    io:format("~nDERIVED VERDICTS (computed from the numbers above)~n"),
    [begin
        {_, _, SbDup, _} = lists:keyfind(dup, 2, [S || S = {B1,_,_,_} <- Slopes, B1 =:= B]),
        {_, _, SbG, _} = lists:keyfind(guard_semi, 2, [S || S = {B1,_,_,_} <- Slopes, B1 =:= B]),
        {_, SbNS, _} = lists:keyfind(B, 1, NS),
        io:format("B=~-3w dup slope ~.1f vs guard_semi ~.1f: dup ~s guard_semi; dup compiled with no_share_opt ~.1f: ~s~n",
          [B, SbDup, SbG, if SbDup > SbG + 1 -> "COSTS MORE THAN"; true -> "does NOT cost more than" end,
           SbNS, if abs(SbNS - SbDup) =< 1 -> "identical, so erlc's own block-sharing (beam_ssa_share) does NOT rescue the duplicated clause bodies here";
                          true -> "differs, so beam_ssa_share absorbs part of the duplication" end])
     end || B <- Bs],
    ok.

measure(V, N, B, Extra) ->
    Src = lib_gen:source(V, N, B),
    Dir = "/tmp/p66_gen_" ++ atom_to_list(V), ok = filelib:ensure_dir(Dir ++ "/x"),
    F = Dir ++ "/m.erl", ok = file:write_file(F, Src),
    {ok, m, Beam} = compile:file(F, [binary, return_errors] ++ Extra),
    {ok, m, {m, _, _, Asm, _}} = compile:file(F, [to_asm, binary, return_errors] ++ Extra),
    {ok, m, Core} = compile:file(F, [to_core, binary, return_errors] ++ Extra),
    {ok, {m, Stripped}} = beam_lib:strip(Beam),
    Ins = lists:sum([length([I || I <- Is, not lists:member(opname(I), [label, line])])
                     || {function, _, _, _, Is} <- Asm]),
    AsmTxt = lists:flatten(io_lib:format("~p", [Asm])),
    SelVal = count("select_val", AsmTxt),
    CoreLn = length(string:split(lists:flatten(core_pp:format(Core)), "\n", all)),
    %% differential: same answers as the `dup` lowering on all members + a non-member
    check_behaviour(V, N, B, Beam),
    #{beam => byte_size(Beam), stripped => byte_size(Stripped), ins => Ins,
      core => CoreLn, sel => SelVal}.

check_behaviour(V, N, B, Beam) ->
    {ok, m, Ref} = compile:file(ref_src(N, B), [binary, return_errors]),
    Inputs = lib_gen:input(N) ++ [none, #{'Kind' => 'T.E', 'Id' => 1}],
    Run = fun(Bin) ->
              code:purge(m), code:delete(m), {module, m} = code:load_binary(m, "m.beam", Bin),
              [try m:handle(X) catch error:R -> {err, opname(R)} end || X <- Inputs]
          end,
    Expected = Run(Ref), Got = Run(Beam),
    case Expected =:= Got of
        true -> ok;
        false -> io:format("BEHAVIOUR MISMATCH ~p N=~p B=~p~n~p~n~p~n", [V, N, B, Expected, Got]), halt(1)
    end.

ref_src(N, B) ->
    F = "/tmp/p66_gen_ref/m.erl", ok = filelib:ensure_dir(F),
    ok = file:write_file(F, lib_gen:source(dup, N, B)), F.

opname(I) when is_tuple(I) -> element(1, I);
opname(I) -> I.

count(Pat, Txt) -> length(string:split(Txt, Pat, all)) - 1.

row({B, V, N, #{beam := Be, stripped := S, ins := I, core := C, sel := Sv}}, Opt) ->
    io:format("~-4w ~-13s ~3w | ~8w ~8w ~8w ~8w ~7w ~9s~n", [B, V, N, Be, S, I, C, Sv, Opt]).

slope(Pts) ->
    N = length(Pts), Sx = lists:sum([X || {X,_} <- Pts]), Sy = lists:sum([Y || {_,Y} <- Pts]),
    Sxy = lists:sum([X*Y || {X,Y} <- Pts]), Sxx = lists:sum([X*X || {X,_} <- Pts]),
    (N*Sxy - Sx*Sy) / (N*Sxx - Sx*Sx).
