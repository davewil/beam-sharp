%% Guards and switch arms over an int, every pair covering all ints; only the literal's spelling varies.
-module(guards).
-export([main/0, brief/1]).
head(G1, G2) -> "module M\npublic atom S(int n)\nS(n) when " ++ G1 ++ " -> :a\nS(n) when " ++ G2 ++ " -> :b\n".
arm(G1, G2) -> "module M\npublic atom S(int n)\nS(m) -> m switch {\n  n when " ++ G1 ++ " => :a,\n  n when " ++ G2 ++ " => :b\n}\n".
rows() ->
  [{"head: n >= 0 / n < 0",        head("n >= 0", "n < 0")},
   {"head: n >= -1 / n < -1",      head("n >= -1", "n < -1")},
   {"head: n != -1 / n == -1",     head("n != -1", "n == -1")},
   {"head: n >= 1 - 2 / n < 1 - 2",head("n >= 1 - 2", "n < 1 - 2")},
   {"head: n >= 2 + 3 / n < 2 + 3",head("n >= 2 + 3", "n < 2 + 3")},
   {"arm : n >= 0 / n < 0",        arm("n >= 0", "n < 0")},
   {"arm : n >= -1 / n < -1",      arm("n >= -1", "n < -1")}].
main() -> [begin io:format("~-32s ~p~n", [L, brief(drv:run(S))]) end || {L, S} <- rows()], ok.
brief({refused, Es}) -> {refused, [element(1, element(4, E)) || E <- Es]};
brief(X) -> X.
