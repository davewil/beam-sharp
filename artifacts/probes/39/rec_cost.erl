%% Ticket 39 §3 leftover: "the boundary tag guard has never been measured".
%% Times summing a field over 200k record-maps through
%%   'Rec'   : bsc output; each element passes through WeightOf/WeightP, which
%%             carry the Kind-tag clause guard (F3)
%%   'RecNG' : the same forms with ONLY that guard removed (rec_noguard.escript)
%% usage: erl -noshell -pa EBIN_WITH_Rec_AND_RecNG -run rec_cost main
-module(rec_cost).
-export([main/0]).
-define(RUNS, 41).
main() ->
    Ts = [#{'Kind' => 'Rec.Tag', 'Name' => <<"x">>, 'Weight' => I rem 1000} || I <- lists:seq(1, 200000)],
    Fs = [{tag_pub,   fun() -> 'Rec':'SumPub'(Ts, 0) end},
          {notag_pub, fun() -> 'RecNG':'SumPub'(Ts, 0) end},
          {tag_priv,  fun() -> 'Rec':'SumPriv'(Ts, 0) end},
          {notag_priv,fun() -> 'RecNG':'SumPriv'(Ts, 0) end}],
    As = [F() || {_, F} <- Fs], 1 = length(lists:usort(As)),
    io:format("OTP ~s answer ~p~n", [erlang:system_info(otp_release), hd(As)]),
    T = lists:foldl(fun(_, Acc) ->
            lists:foldl(fun({N, F}, A) -> erlang:garbage_collect(),
                {Us, _} = timer:tc(F), maps:update_with(N, fun(L) -> [Us|L] end, [Us], A) end, Acc, Fs)
        end, #{}, lists:seq(1, ?RUNS)),
    Base = lists:min([lists:min(L) || L <- maps:values(T)]),
    [begin S = lists:sort(maps:get(N, T)),
           io:format("~-9s min ~6.3f ms  med ~6.3f ms  rel ~.3f~n",
                     [N, hd(S)/1000, lists:nth(?RUNS div 2 + 1, S)/1000, hd(S)/Base]) end
     || {N, _} <- Fs],
    halt().
