#!/usr/bin/env escript
%% P7: what a RUNTIME "who called me" guard would cost per call (the alternative to a compile-time check).
main(_) ->
    N = 200000,
    Plain = fun() -> g(1) end,
    Guarded = fun() -> gg(1) end,
    Run = fun(F) -> {T, _} = timer:tc(fun() -> [F() || _ <- lists:seq(1, N)], ok end), T * 1000 / N end,
    [begin
       A = Run(Plain), B = Run(Guarded),
       io:format("run ~p: plain ~.1f ns/call, stacktrace-guarded ~.1f ns/call~n", [R, A, B])
     end || R <- [1,2,3,4,5]].
g(X) -> X + 1.
gg(X) ->
    {current_stacktrace, [_, _, {M, _, _, _} | _]} = process_info(self(), current_stacktrace),
    _ = M,
    X + 1.
