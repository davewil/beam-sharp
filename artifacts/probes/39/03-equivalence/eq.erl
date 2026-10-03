-module(eq).
-export([main/1]).
%% .S files are consultable terms. Normalise: drop line/func_info, rename local labels by first
%% appearance, replace call targets by the callee's role name. {tr,..} and var_info are KEPT.
main([SA, SB, BeamA, BeamB]) ->
    A = fns(SA, #{wrap=>wrap,hit=>hit,spin=>spin,sign=>sign,size_=>size,clicks=>clicks,part_two=>pt}),
    B = fns(SB, #{'Wrap'=>wrap,'Hit'=>hit,'Spin'=>spin,'Sign'=>sign,'Size'=>size,'Clicks'=>clicks,'PartTwo'=>pt}),
    [begin
        FA = maps:get(K, A), FB = maps:get(K, B),
        io:format("~-7s instrs erlang=~-3w beam-sharp=~-3w  identical=~p~n", [K, length(FA), length(FB), FA =:= FB]),
        case FA =:= FB orelse length(FA) =/= length(FB) of true -> ok;
             false -> [io:format("    differs: ~w  vs  ~w~n", [X, Y]) || {X,Y} <- lists:zip(FA, FB), X =/= Y] end
     end || K <- [wrap,hit,spin,sign,size,clicks,pt]],
    io:format("(sign differs by SOURCE: bench_erl.erl's sign/1 has a third clause, bench_bs.bs's has two)~n"),
    io:format("~n-- raw chunks (Type chunk = what the loader reads for {tr,..}/var_info)~n"),
    [begin {ok,_,Cs} = beam_lib:all_chunks(F),
           io:format("~-10s Code=~p bytes  Type=~s~n", [N, byte_size(proplists:get_value("Code",Cs)),
                      binary:encode_hex(proplists:get_value("Type",Cs))])
     end || {N,F} <- [{erlang,BeamA},{'beam-sharp',BeamB}]],
    halt().
fns(File, Names) ->
    {ok, Ts} = file:consult(File),
    Gs = groups(Ts, none, []),
    Entry = maps:from_list([{E, maps:get(N, Names)} || {function,N,_,E} <- Ts, maps:is_key(N, Names)]),
    maps:from_list([{maps:get(N, Names), norm(Body, Entry)} || {N,Body} <- Gs, maps:is_key(N, Names)]).
groups([], Cur, Acc) -> fin(Cur, Acc);
groups([{function,N,_,_}|T], Cur, Acc) -> groups(T, {N,[]}, fin(Cur, Acc));
groups([I|T], {N,B}, Acc) -> groups(T, {N,[I|B]}, Acc);
groups([_|T], none, Acc) -> groups(T, none, Acc).
fin(none, Acc) -> Acc; fin({N,B}, Acc) -> [{N,lists:reverse(B)}|Acc].
norm(Body, Entry) ->
    Ls = lists:usort(lists:flatten([ls(I) || I <- Body])),
    M = maps:from_list(lists:zip(Ls, lists:seq(1, length(Ls)))),
    [relabel(I, M, Entry) || I <- Body, not skip(I)].
skip({line,_}) -> true; skip({func_info,_,_,_}) -> true; skip(_) -> false.
ls({label,N}) -> [N]; ls(T) when is_tuple(T) -> lists:flatten([ls(E) || E <- tuple_to_list(T)]);
ls(L) when is_list(L) -> lists:flatten([ls(E) || E <- L]); ls(_) -> [].
relabel({label,N}, M, _) -> {label, maps:get(N,M)};
relabel({call,A,{f,L}}, _, E) when is_map_key(L, E) -> {call,A,{fn,maps:get(L,E)}};
relabel({call_last,A,{f,L},D}, _, E) when is_map_key(L, E) -> {call_last,A,{fn,maps:get(L,E)},D};
relabel({call_only,A,{f,L}}, _, E) when is_map_key(L, E) -> {call_only,A,{fn,maps:get(L,E)}};
relabel({f,N}, M, _) when is_integer(N), N > 0 -> {f, maps:get(N,M,N)};
relabel(T, M, E) when is_tuple(T) -> list_to_tuple([relabel(X,M,E) || X <- tuple_to_list(T)]);
relabel(L, M, E) when is_list(L) -> [relabel(X,M,E) || X <- L];
relabel(X,_,_) -> X.
