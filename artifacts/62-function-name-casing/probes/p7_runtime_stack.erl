%% Probe 7: runtime consequences of alias-by-trampoline vs duplicate body.
%% Run: erlc p7_runtime_stack.erl && erl -noshell -pa . -eval 'p7_runtime_stack:main(), halt().'
%% Exits via init:stop(1) if a trampoline frame appears in a stack trace (contradicting call_only).
-module(p7_runtime_stack).
-export([main/0, 'Calc'/1, calc/1, calc2/1]).

'Calc'(#{'Kind' := k, 'Id' := Id}) -> {Id, 0}.
calc(X) -> 'Calc'(X).                          % trampoline
calc2(#{'Kind' := k, 'Id' := Id}) -> {Id, 0}.  % duplicate body

names(S) -> [F || {_, F, _, _} <- S].
st(F) -> try ?MODULE:F(not_a_map) catch error:_:S -> names(S) end.
loop(_, 0) -> ok;
loop(F, N) -> _ = ?MODULE:F(#{'Kind' => k, 'Id' => 1}), loop(F, N - 1).
t(F, N) -> {Us, _} = timer:tc(fun() -> loop(F, N) end), Us.

main() ->
    io:format("top frames via 'Calc': ~p~n", [lists:sublist(st('Calc'), 2)]),
    io:format("top frames via calc  : ~p  (trampoline)~n", [lists:sublist(st(calc), 2)]),
    io:format("top frames via calc2 : ~p  (duplicate body)~n", [lists:sublist(st(calc2), 2)]),
    TrampFrame = lists:member(calc, st(calc)),
    DupFrame = lists:member(calc2, st(calc2)),
    io:format("alias name appears in trace: trampoline=~p duplicate=~p~n", [TrampFrame, DupFrame]),
    N = 5000000,
    [t(F, N) || F <- ['Calc', calc, calc2]],  % warmup
    [A, B, C] = [lists:min([t(F, N) || _ <- lists:seq(1, 7)]) || F <- ['Calc', calc, calc2]],
    io:format("~p calls (compiled, best of 7) us: 'Calc'=~p calc(tramp)=~p calc2(dup)=~p~n", [N, A, B, C]),
    case {TrampFrame, DupFrame} of
        {false, true} -> ok;
        Other -> io:format("UNEXPECTED ~p~n", [Other]), init:stop(1)
    end.
