#!/usr/bin/env escript
main(Dirs) ->
    [begin
         code:purge('T'), code:delete('T'), code:add_patha(D), {module,'T'} = code:load_file('T'),
         Xs = lists:duplicate(1000, 7), R2 = fun(F) -> S = lists:sort([element(1, timer:tc(fun() -> [F(Xs) || _ <- lists:seq(1,1000)] end)) || _ <- lists:seq(1,9)]), {hd(S), lists:nth(5,S), lists:last(S)} end,
         R = fun(F) -> S = lists:sort([element(1, timer:tc(fun() -> F(1000000) end)) || _ <- lists:seq(1,9)]), {hd(S), lists:nth(5,S), lists:last(S)} end,
         io:format("~-34s SumTo(1e6) us min/med/max ~0p   SumMod(1000 x 1000 elems) ~0p~n", [D, R(fun 'T':'SumTo'/1), R2(fun 'T':'SumMod'/1)]),
         code:del_path(D)
     end || D <- Dirs].
