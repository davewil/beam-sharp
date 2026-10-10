-module(tbench).
-export([main/1]).
%% usage: tbench:main([Dir0, Dir1...]) where each is a label=path to Bench.abstr.
-define(N, 2000000).
-define(RUNS, 25).

load(Label, Abstr, Opts) ->
    {ok, Forms0} = file:consult(Abstr),
    Mod = list_to_atom("bench_" ++ Label),
    Forms = [case F of {attribute,L,module,_} -> {attribute,L,module,Mod}; _ -> F end || F <- Forms0],
    {ok, Mod, Bin} = compile:forms(Forms, [debug_info, return_errors | Opts]),
    {module, Mod} = code:load_binary(Mod, atom_to_list(Mod)++".beam", Bin),
    Mod.

loop(0, _M, _F, _A) -> ok;
loop(N, M, F, A) -> M:F(A), loop(N-1, M, F, A).

time(M, F, A) ->
    erlang:garbage_collect(),
    T0 = erlang:monotonic_time(nanosecond),
    loop(?N, M, F, A),
    (erlang:monotonic_time(nanosecond) - T0) / ?N.

stats(Xs) ->
    S = lists:sort(Xs), Min = hd(S), Med = lists:nth((length(S)+1) div 2, S),
    Mad = lists:nth((length(S)+1) div 2, lists:sort([abs(X-Med) || X <- S])),
    {Min, Med, Mad}.

main([Out | Specs]) ->
    %% Specs: "label:plain|inline:path"
    Vs = [begin [L, K, P] = string:split(S, ":", all),
                Opts = case K of "inline" -> [{inline, [{'Step',1},{'Inc',1}]}]; _ -> [] end,
                {L ++ "_" ++ K, load(L ++ "_" ++ K, P, Opts)} end || S <- Specs],
    Ord = #{'Kind'=>'Bench.Order','Id'=>1,'Total'=>7},
    Cases = [{'RunRec', Ord}, {'Run8Rec', Ord}, {'Run8RecPub', Ord}, {'Run8Direct', Ord}, {'Run8Int', 5}, {'Run8IntPub', 5}],
    %% warm every function once
    [loop(200000, M, F, A) || {_, M} <- Vs, {F, A} <- Cases],
    Res = lists:foldl(fun(_Run, Acc) ->
        lists:foldl(fun({F, A}, Acc1) ->
            lists:foldl(fun({Lbl, M}, Acc2) ->
                T = time(M, F, A),
                maps:update_with({F, Lbl}, fun(L) -> [T|L] end, [T], Acc2)
            end, Acc1, Vs)
        end, Acc, Cases)
    end, #{}, lists:seq(1, ?RUNS)),
    {ok, Fd} = file:open(Out, [write]),
    [begin {Min, Med, Mad} = stats(maps:get({F, Lbl}, Res)),
           io:format(Fd, "~-12s ~-14s min=~7.3f median=~7.3f mad=~6.3f ns/call (n=~p x ~p calls)~n",
                     [F, Lbl, Min, Med, Mad, ?RUNS, ?N])
     end || {F, _} <- Cases, {Lbl, _} <- Vs],
    file:close(Fd), halt().
