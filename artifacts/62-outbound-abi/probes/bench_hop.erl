%% Hot loops calling the same B# function through its PascalCase export or its snake_case alias.
-module(bench_hop).
-export([run/2, empty/1, pascal/1, alias/1, via_apply/1]).

empty(N)  -> empty(N, 0).
empty(0, A) -> A;
empty(N, A) -> empty(N - 1, A + N).

pascal(N) -> pascal(N, 0).
pascal(0, A) -> A;
pascal(N, A) -> pascal(N - 1, A + 'Abi':'NewHTTP'(N)).

alias(N)  -> alias(N, 0).
alias(0, A) -> A;
alias(N, A) -> alias(N - 1, A + 'Abi':new_http(N)).

%% NEGATIVE CONTROL: the same call plus one extra BIF call per iteration. The probe must see this.
via_apply(N) -> via_apply(N, 0).
via_apply(0, A) -> A;
via_apply(N, A) -> via_apply(N - 1, A + 'Abi':'NewHTTP'(N) + erlang:phash2(N)).

%% Which :: empty | pascal | alias ; best-of-Reps microseconds is NOT used: all reps are returned.
run(Which, N) ->
    {T, R} = timer:tc(fun() -> ?MODULE:Which(N) end),
    {T, R}.
