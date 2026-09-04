-module(run_pool).
-export([main/0]).
main() ->
    {ok, Pool} = gen_server:start_link('WorkerPool', 3, []),
    Results = ['WorkerPool':'Submit'(Pool, N) || N <- [1,2,3,4,5]],
    io:format("Submit results = ~p~n", [Results]),
    ok.
