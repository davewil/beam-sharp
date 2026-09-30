%% P5: does erlc drop an `is_integer` guard on a PRIVATE function?
%% `erlc -S` the module and look for `is_integer` in each function.
-module(p5_erlc_local_types).
-export([known/1, unknown/1, escapes/0, loop_known/1]).

%% (1) private, guarded, every call site passes a value erlc can see is an integer
known(N) when is_integer(N) -> inner1(N + 1).
inner1(X) when is_integer(X) -> X * 2.

%% (2) private, guarded, called with an argument of unknown type (it is an exported
%% function's parameter): the guard must stay, it is the only test.
unknown(T) -> inner2(T).
inner2(X) when is_integer(X) -> X * 2.

%% (3) private, guarded, and its name is taken as a fun that leaves the module:
%% erlc must assume any caller, so the guard must stay.
escapes() -> fun inner3/1.
inner3(X) when is_integer(X) -> X * 2.

%% (4) private tail-recursive loop with the guard on every entry
loop_known(N) when is_integer(N) -> loop4(N, 0).
loop4(0, Acc) when is_integer(Acc) -> Acc;
loop4(N, Acc) when is_integer(N), is_integer(Acc) -> loop4(N - 1, Acc + N).
