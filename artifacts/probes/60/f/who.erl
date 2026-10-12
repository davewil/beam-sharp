-module(who).
-export([main/0, plain/1, checked/1, caller_arg/2, via_tail/1, via_body/1]).
plain(X) -> X + 1.
%% runtime caller check: what a callee-side `friend` would need if the emitter had to enforce it
checked(X) ->
    {current_stacktrace, [_Self, {M, _, _, _} | _]} = process_info(self(), current_stacktrace),
    true = (M =:= who),
    X + 1.
%% the cheap alternative: the caller passes its own identity (changes every arity; forgeable)
caller_arg(Caller, X) when Caller =:= who -> X + 1.
via_body(X) -> Y = checked(X), {ok, Y}.      %% non-tail call: caller frame is on the stack
via_tail(X) -> checked(X).             %% tail call: caller frame is gone
bench(F, N) ->
    lists:sort([begin {T, _} = timer:tc(fun() -> loop(F, N) end), T * 1000 / N end || _ <- lists:seq(1, 9)]).
loop(_, 0) -> ok;
loop(F, N) -> F(), loop(F, N - 1).
main() ->
    N = 200000,
    P = bench(fun() -> who:plain(1) end, N),
    A = bench(fun() -> who:caller_arg(who, 1) end, N),
    C = bench(fun() -> who:via_body(1) end, N),
    io:format("plain remote call      : min=~.1f median=~.1f ns/call~n", [hd(P), lists:nth(5, P)]),
    io:format("caller passed as arg   : min=~.1f median=~.1f ns/call~n", [hd(A), lists:nth(5, A)]),
    io:format("stacktrace caller check: min=~.1f median=~.1f ns/call (x~.1f of plain, by median)~n",
              [hd(C), lists:nth(5, C), lists:nth(5, C) / lists:nth(5, P)]),
    %% soundness: who does the callee see when the caller tail-calls it?
    io:format("legit caller, body call          -> ~p~n", [catch who:via_body(1)]),
    io:format("ROGUE caller, non-tail call      -> ~p~n", [case catch rogue:body(1) of {'EXIT', {{badmatch, _}, _}} -> refused; V -> V end]),
    io:format("ROGUE caller, TAIL call (admitted) -> ~p~n", [catch rogue:tail(1)]),
    io:format("ROGUE `Y = f(), Y` (erlc makes it a tail call; admitted) -> ~p~n", [catch rogue:body_looks_nontail(1)]).
