-module(leaf).
-export([total/1, total_guarded/1]).
%% exported `public int Total(list<int> xs)`: no O(1) guard can check the elements (18 §2),
%% so a float element crosses the entry. Private `Bump(int n)` below is what it reaches.
total(Xs) -> lists:sum([bump(X) || X <- Xs]).
bump(N) -> N + 1.
total_guarded(Xs) -> lists:sum([bump_g(X) || X <- Xs]).
bump_g(N) when is_integer(N) -> N + 1.
