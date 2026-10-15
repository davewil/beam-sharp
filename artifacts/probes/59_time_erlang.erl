%% 59_time_erlang.erl -- independent control for 59_time.sh: the same loops written directly in Erlang
%% (no B# in the path), guarded vs unguarded. Claim: a map_get tag test on the hot path of a
%% self-recursive function costs several ns per call; is_integer is within noise. REFUTED if the
%% tag-test gap is under the max-min spread of the unguarded loop. Run:
%%   erlc 59_time_erlang.erl && erl -noshell -s '59_time_erlang' go -s init stop   (see 59_time_erlang.sh)
-module('59_time_erlang').
-export([go/0]).
-define(IT, 10000000).
-define(N, 15).

lr_u(0, _, A) -> A;
lr_u(N, R, A) -> lr_u(N - 1, R, A + map_get('A', R)).
lr_g(0, _, A) -> A;
lr_g(N, R, A) when map_get('Kind', R) =:= 'T.R' -> lr_g(N - 1, R, A + map_get('A', R)).
li_u(0, A) -> A;
li_u(N, A) -> li_u(N - 1, A + N).
li_g(0, A) when is_integer(A) -> A;
li_g(N, A) when is_integer(N), is_integer(A) -> li_g(N - 1, A + N).

go() ->
    R = #{'Kind' => 'T.R', 'A' => 1, 'B' => 2, 'C' => 3},
    Fs = [{"record unguarded", fun() -> lr_u(?IT, R, 0) end},
          {"record tag-guarded", fun() -> lr_g(?IT, R, 0) end},
          {"int unguarded", fun() -> li_u(?IT, 0) end},
          {"int is_integer-guarded", fun() -> li_g(?IT, 0) end}],
    [F() || {_, F} <- Fs],
    Res = lists:foldl(fun(_, Acc) ->
            lists:foldl(fun({L, F}, A2) -> {Us, _} = timer:tc(F), T = Us * 1000 / ?IT,
                                           maps:update_with(L, fun(X) -> [T|X] end, [T], A2) end, Acc, Fs) end,
            #{}, lists:seq(1, ?N)),
    io:format("n=~p runs, ~p iterations each, ns/iteration~n", [?N, ?IT]),
    [begin Ts = lists:sort(maps:get(L, Res)),
           io:format("~-24s min=~7.3f median=~7.3f max=~7.3f~n", [L, hd(Ts), lists:nth(8, Ts), lists:last(Ts)]) end || {L, _} <- Fs].
