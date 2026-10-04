-module(loop09).
-export([plain/1, guard_int/1, guard_range/1, bench/2]).
%% Same body each time; only the post-call test differs. lib08:wrap/1 is a remote call, so its return type is `any`.
plain(N)       -> plain(N, 0).
plain(0, A)    -> A;
plain(N, A)    -> R = lib08:wrap(N), plain(N-1, A + (R + 1)).
guard_int(N)   -> guard_int(N, 0).
guard_int(0,A) -> A;
guard_int(N,A) -> case lib08:wrap(N) of R when is_integer(R) -> guard_int(N-1, A + (R+1)) end.
guard_range(N)   -> guard_range(N, 0).
guard_range(0,A) -> A;
guard_range(N,A) -> case lib08:wrap(N) of R when is_integer(R), R >= 0, R =< 99 -> guard_range(N-1, A + (R+1)) end.
%% interleaved timing: Rounds rounds, each runs every variant once with N iterations
bench(N, Rounds) ->
    Fs = [plain, guard_int, guard_range],
    Acc = lists:foldl(fun(R, A) ->
            Rot = rot(Fs, R rem 3),
            lists:foldl(fun(F, A1) -> {T,V} = timer:tc(?MODULE, F, [N]),
                  maps:update_with(F, fun({Ts,_}) -> {[T|Ts],V} end, A1) end, A, Rot) end,
          maps:from_list([{F,{[],0}} || F <- Fs]), lists:seq(1,Rounds)),
    [begin {Ts,V} = maps:get(F,Acc), S = lists:sort(Ts),
       io:format("~-12s result=~p min=~.2f ms med=~.2f ms~n",[F,V,hd(S)/1000, lists:nth(length(S) div 2+1,S)/1000]) end || F <- Fs].
rot(L,0)->L; rot([H|T],N)->rot(T++[H],N-1).
