-module(drive_leak).
-export([run/0]).
r(Label, F) ->
    R = try {returned, F()} catch C:E:_ -> {raised, C, case E of {Tag,_} -> Tag; _ -> E end} end,
    io:format("~-58s ~w~n", [Label, R]).
run() ->
    M = 'Leak',
    C = fun(N) -> #{'Kind'=>'Leak.Counter','N'=>N} end,
    r("ViaField(Counter{N=1})                [valid]", fun() -> M:'ViaField'(C(1)) end),
    r("ViaField(Counter{N=1.5})              [float, via private Bump]", fun() -> M:'ViaField'(C(1.5)) end),
    r("DirectField(Counter{N=1.5})           [float, no helper]", fun() -> M:'DirectField'(C(1.5)) end),
    r("ViaTuple({1,2})                       [valid]", fun() -> M:'ViaTuple'({1,2}) end),
    r("ViaTuple({1.5,2})                     [float, via private Bump]", fun() -> M:'ViaTuple'({1.5,2}) end),
    r("DirectTuple({1.5,2})                  [float, no helper]", fun() -> M:'DirectTuple'({1.5,2}) end),
    r("ViaList([1])                          [valid]", fun() -> M:'ViaList'([1]) end),
    r("ViaList([1.5])                        [float, via private Bump]", fun() -> M:'ViaList'([1.5]) end),
    r("DirectList([1.5])                     [float, no helper]", fun() -> M:'DirectList'([1.5]) end),
    r("BumpPub(1.5)                          [exported guard, control]", fun() -> M:'BumpPub'(1.5) end),
    ok.
