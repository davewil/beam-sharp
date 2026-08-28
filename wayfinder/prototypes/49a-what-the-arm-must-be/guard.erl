%%% 49a — is the residual `binary \ string` decidable by a BEAM GUARD?
%%%
%%%   erlc -o /tmp wayfinder/prototypes/49a-what-the-arm-must-be/guard.erl
%%%
%%% THIS FILE IS EXPECTED TO FAIL TO COMPILE. That failure is the measurement.
%%%
%%% `algebra.erl` row 4 shows the residual is non-empty and that F29's head
%%% channel can spell no pattern for it. Unspellable is not the same as
%%% undiscriminable — `bs_emit` may emit a guard the surface has no pattern for
%%% — so ticket 09's "discriminable by one BEAM guard in O(1)" has to be asked
%%% of the platform directly rather than inferred from the head count.
%%%
%%% Measured 2026-08-28, Erlang/OTP 28:
%%%
%%%   guard.erl:25:11: illegal guard expression
%%%
%%% Inverting the arm does not rescue it. Shape B could test the PARAMETER type
%%% and leave the residual to a catch-all, but "is this binary valid UTF-8" is
%%% the same non-guard test in either direction — both polarities fail on one
%%% fact, that validity is a linear scan and no guard BIF performs it.
-module(guard).
-export([f/1, g/1]).

%% The only stdlib function that decides UTF-8 validity over a WHOLE binary.
f(X) when unicode:characters_to_binary(X) =/= X -> not_string;
f(_) -> string.

%% The near-miss, offered to show what IS guard-legal: a binary pattern reaches
%% the FIRST codepoint, never the whole binary.
g(<<_/utf8, _/binary>>) -> starts_utf8;
g(_) -> other.
