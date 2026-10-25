%% Probe 13b: does a global call trace on the original PascalCase function see calls made through a snake alias?
%% Control: the trace MUST see the original-name call (else the harness is broken, as 13_v1 was).
%% Run: erl -noshell -pa <aliased-ebin> -eval '13b_trace_alias:run(), halt().'   (module name starts with digit; use escript form below)
-module('13b_trace_alias').
-export([run/0]).

trial(Label, Fun) ->
    {ok, Tracer} = {ok, spawn(fun() -> loop([]) end)},
    erlang:trace_pattern({'Shop', 'Amount', 1}, true, [global]),
    erlang:trace(self(), true, [call, {tracer, Tracer}]),
    O = 'Shop':'New'(1), Fun(O),
    erlang:trace(self(), false, [call]),
    erlang:trace_pattern({'Shop', 'Amount', 1}, false, [global]),
    Tracer ! {get, self()},
    receive {events, E} -> io:format("~-34s -> ~p trace event(s) ~p~n", [Label, length(E), E]) after 1000 -> io:format("~s: no reply~n",[Label]) end.
loop(A) -> receive {trace, _, call, MFA} -> loop([MFA | A]); {get, P} -> P ! {events, lists:reverse(A)} end.
run() ->
    {module, _} = code:ensure_loaded('Shop'),
    trial("control: call 'Amount' directly", fun(O) -> 'Shop':'Amount'(O) end),
    trial("via alias amount/1", fun(O) -> 'Shop':amount(O) end).
