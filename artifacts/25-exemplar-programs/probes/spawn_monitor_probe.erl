-module(spawn_monitor_probe).
-export([main/0]).

%% Probe 1: does a worker that finishes normally still deliver a DOWN to a
%% process that spawn+monitor'd it AFTER it may have already run?
main() ->
    probe_double_signal(),
    probe_timing(),
    probe_cost().

probe_double_signal() ->
    Self = self(),
    Worker = spawn(fun() -> Self ! {cast, 42} end),
    timer:sleep(5), %% let the worker finish and exit well before we monitor
    erlang:monitor(process, Worker),
    Msgs = drain(200),
    io:format("probe 1 -- late monitor on an already-exited normal worker:~n"
              "  mailbox after 200ms = ~p~n"
              "  (a monitor established AFTER the target already exited still~n"
              "   enqueues an immediate DOWN -- the naive fan-in double-counts~n"
              "   unless it special-cases reason =:= normal)~n", [Msgs]).

probe_timing() ->
    Self = self(),
    {_Pid, _Ref} = spawn_monitor(fun() -> Self ! {cast, square(12)} end),
    Msgs = drain(200),
    io:format("probe 2 -- spawn_monitor (atomic) on a fast, successful worker:~n"
              "  mailbox after 200ms = ~p~n"
              "  (BOTH the cast and the DOWN arrive -- atomicity does not~n"
              "   remove the double signal, it only removes the race window)~n", [Msgs]).

probe_cost() ->
    N = 10000,
    T0 = erlang:monotonic_time(microsecond),
    lists:foreach(fun(_) ->
        {Pid, Ref} = spawn_monitor(fun() -> ok end),
        receive {'DOWN', Ref, process, Pid, _} -> ok end
    end, lists:seq(1, N)),
    T1 = erlang:monotonic_time(microsecond),
    Us = T1 - T0,
    io:format("probe 3 -- ~p spawn_monitor+DOWN round trips: ~p us total, ~.2f us each~n",
              [N, Us, Us / N]).

square(X) -> X * X.

drain(Timeout) ->
    receive
        M -> [M | drain(Timeout)]
    after Timeout ->
        []
    end.
