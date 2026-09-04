-module(flat_size_probe).
-export([main/0]).

main() ->
    Down = {'DOWN', make_ref(), process, self(), normal},
    io:format("DOWN tuple (normal)      : ~p words (~p bytes)~n",
              [erts_debug:flat_size(Down), erts_debug:flat_size(Down) * 8]),
    DownAbnormal = {'DOWN', make_ref(), process, self(), {badarith, []}},
    io:format("DOWN tuple (crash reason): ~p words (~p bytes)~n",
              [erts_debug:flat_size(DownAbnormal), erts_debug:flat_size(DownAbnormal) * 8]),
    ResultMsg = {result, 144},
    io:format("(:result, int) cast msg  : ~p words (~p bytes)~n",
              [erts_debug:flat_size(ResultMsg), erts_debug:flat_size(ResultMsg) * 8]),
    Job = {reduce, lists:seq(1, 100)},
    io:format("(:reduce, [1..100]) call : ~p words (~p bytes)~n",
              [erts_debug:flat_size(Job), erts_debug:flat_size(Job) * 8]),
    BatchState = #{'Kind' => 'BatchReduce.BatchState', 'Pending' => 5, 'Total' => 30, 'From' => self()},
    io:format("BatchState (tagged map)  : ~p words (~p bytes)~n",
              [erts_debug:flat_size(BatchState), erts_debug:flat_size(BatchState) * 8]),
    ok.
