%% Probe 3 - what a RUN-TIME "who may call me" check would cost on the BEAM (the only way the
%% emitter could enforce it, since one entry label serves local and remote callers: ticket 18 §5).
%% erlc p3_runtime_check_cost.erl && erl -noshell -s p3_runtime_check_cost main -s init stop
-module(p3_runtime_check_cost).
-export([main/0, tail_caller/0, body_caller/0, who/0]).
-define(N, 200000).

plain(A, B) -> A + B.
checked(A, B) ->
    {current_stacktrace, [_Self, {M, _, _, _} | _]} = process_info(self(), current_stacktrace),
    true = (M =:= p3_runtime_check_cost) orelse erlang:error(not_visible),
    A + B.

loop(_, 0, Acc) -> Acc;
loop(F, N, Acc) -> loop(F, N - 1, Acc + F(N, 1)).

t(F) ->
    lists:min([begin {T, _} = timer:tc(fun() -> loop(F, ?N, 0) end), T end || _ <- lists:seq(1, 7)]).

%% A tail call leaves no frame, so the callee cannot see its caller: a stacktrace check is also unsound.
who() -> {current_stacktrace, St} = process_info(self(), current_stacktrace), [F || {_, F, _, _} <- St].
tail_caller() -> who().
body_caller() -> X = who(), {X}.

main() ->
    io:format("tail-called callee sees frames ~p; body-called sees ~p~n", [tail_caller(), body_caller()]),
    Plain = t(fun plain/2), Checked = t(fun checked/2),
    io:format("OTP ~s plain ~p ns/call, stacktrace-checked ~p ns/call, ratio ~.1fx~n",
              [erlang:system_info(otp_release), Plain * 1000 div ?N, Checked * 1000 div ?N, Checked / Plain]).
