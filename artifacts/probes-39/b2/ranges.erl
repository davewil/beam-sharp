-module(ranges).
-export([f_plain/1, f_spec/1, f_guard/1, f_guard_chain/1, f_band/1, f_rem/1, f_eq/1, f_case/1, f_ret/1]).
%% each fn does X + 1 on an integer parameter; we read the {tr,..} on the `+` operand in `erlc -S`.
f_plain(X) when is_integer(X) -> X + 1.
-spec f_spec(0..99) -> 1..100.
f_spec(X) when is_integer(X) -> X + 1.                      % range only in the -spec
f_guard(X) when is_integer(X), X >= 0, X =< 99 -> X + 1.      % range only in relational guards
f_guard_chain(X) when is_integer(X) ->
    case X >= 0 andalso X =< 99 of true -> X + 1; false -> error end.   % same, body test
f_band(X) when is_integer(X) -> (X band 127) + 1.            % control: an op beam_ssa_type knows
f_rem(X) when is_integer(X) -> (X rem 100) + 1.              % control: an op beam_ssa_type knows
f_eq(X) when X =:= 3; X =:= 4 -> X + 1.                      % equality with literals
f_case(X) when is_integer(X) -> case X of 0 -> 1; 1 -> 2; 2 -> 3; _ -> X + 1 end.
%% return-position guard (what F42-style `case Call of V when V >= 0, V =< 99 -> V end` gives the caller)
f_ret(X) when is_integer(X) ->
    case hidden(X) of V when is_integer(V), V >= 0, V =< 99 -> V + 1 end.
hidden(X) -> erlang:phash2(X) - 5.
