-module(rc2).
-export([time/1, b/3, t/3]).
-compile({no_inline,[fb/1, ft/1]}).
fb(V) -> V.
ft(V) -> {some, V}.
b(0, _, A) -> A;
b(N, V, A) -> X = fb(V), b(N-1, V, A + X).
t(0, _, A) -> A;
t(N, V, A) -> case ft(V) of {some, X} -> t(N-1, V, A + X) end.
time(N) ->
  V = erlang:phash2(make_ref(), 100) + 1000,
  Best = fun(F) -> lists:min([element(1, timer:tc(?MODULE, F, [N, V, 0])) || _ <- lists:seq(1,7)]) end,
  B = Best(b), T = Best(t),
  io:format("returned-and-matched (not escaping): bare ~p ms, tagged ~p ms, delta ~.3f ns/op~n", [B div 1000, T div 1000, (T-B)*1000/N]).
