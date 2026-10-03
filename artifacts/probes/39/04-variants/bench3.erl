%% Times named modules in one VM, order rotated each round. Every call is checked against 6770.
-module(bench3).
-export([main/1]).
main([Dir, Input, NStr]) ->
    N = list_to_integer(NStr),
    Mods = lists:sort([list_to_atom(filename:basename(F, ".beam")) || F <- filelib:wildcard(Dir ++ "/*.beam")]),
    [{module,_} = code:load_abs(Dir ++ "/" ++ atom_to_list(M)) || M <- Mods],
    Ds = read(Input),
    Fun = fun(M) -> case erlang:function_exported(M, 'PartTwo', 1) of true -> 'PartTwo'; false -> part_two end end,
    Impls = [{M, fun() -> M:(Fun(M))(Ds) end} || M <- Mods],
    [begin 6770 = F(), [F() || _ <- lists:seq(1,20)] end || {_, F} <- Impls],
    Rounds = [begin {A,B} = lists:split(R rem length(Impls), Impls),
                    [begin {T,6770} = timer:tc(F), {M,T} end || {M,F} <- B ++ A] end || R <- lists:seq(0,N-1)],
    io:format("OTP ~s, ~p runs per variant, rotated order~n", [erlang:system_info(otp_release), N]),
    io:format("~-24s ~8s ~8s ~8s ~8s ~8s ~9s~n", ["variant","min ms","q1","median","q3","IQR","med/e0"]),
    St = [{M, stats([T || R <- Rounds, {Mm,T} <- R, Mm =:= M])} || M <- Mods],
    Base = element(3, proplists:get_value(e0_erlang, St)),
    [io:format("~-24s ~8.2f ~8.2f ~8.2f ~8.2f ~8.2f ~8.2fx~n", [M, A/1000,B/1000,C/1000,D/1000,(D-B)/1000,C/Base])
     || {M,{A,B,C,D}} <- St],
    halt().
stats(L) -> S = lists:sort(L), Len = length(S),
    {hd(S), lists:nth(Len div 4 + 1, S), lists:nth(Len div 2 + 1, S), lists:nth((3*Len) div 4 + 1, S)}.
read(Path) -> {ok, Bin} = file:read_file(Path),
    [parse(L) || L <- string:split(binary_to_list(Bin), "\n", all), L =/= ""].
parse([$L | N]) -> -list_to_integer(N);
parse([$R | N]) -> list_to_integer(N).
