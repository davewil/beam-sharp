#!/usr/bin/env escript
main([Dir]) ->
    true = code:add_patha(Dir),
    Cs = [{'Total', [10]}, {'Total', [200000]}, {'Total', [0]}, {'Wrap', [0]}, {'Wrap', [254]}, {'Wrap', [255]},
          {'WrapList', [[0,1,255,7]]}, {'Decay', [5, 64.0]}, {'Decay', [0, 1.5]}, {'FromInts', [[1,2,3]]},
          {'Price', [<<"{\"price\":1}">>]}, {'Price', [<<"{\"price\":0.5}">>]}, {'Price', [<<"{\"price\":\"x\"}">>]},
          {'Doubled', [[1,2,3]]}, {'ViaNum', [1]}, {'ViaNum', [1.5]},
          %% forged: must still refuse at the door, in both
          {'Wrap', [256]}, {'Wrap', [1.5]}, {'Decay', [1, 2]}],
    [begin R = try {ok, apply('L', F, A)} catch C:E -> {C, E} end,
           io:format("~p~w -> ~p~n", [F, A, R]) end || {F, A} <- Cs].
