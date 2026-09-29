%% Loop helpers for probe 3: 1e7 external calls to the PascalCase export vs its snake_case alias.
-module(p3loop).
-export([direct/2, alias/2, empty/2]).
direct(0, _) -> ok;
direct(N, X) -> 'N100':'GetItem5'(X), direct(N - 1, X).
alias(0, _) -> ok;
alias(N, X) -> 'N100':get_item5(X), alias(N - 1, X).
empty(0, _) -> ok;
empty(N, X) -> erlang:abs(X), empty(N - 1, X).
