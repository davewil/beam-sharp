-module(run_batch).
-export([main/0]).

main() ->
    {ok, Pid} = gen_server:start_link('BatchReduce', [], []),
    Result = 'BatchReduce':'Reduce'(Pid, [1,2,3,4,5]),
    io:format("Reduce([1..5]) = ~p~n", [Result]),
    ok.
