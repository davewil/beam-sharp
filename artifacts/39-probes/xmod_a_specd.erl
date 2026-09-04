%%% Same as xmod_a.erl but with an explicit, EXACT -spec on both functions
%%% (0..99 for wrap/1's return, the tightest true Erlang range type), to test
%%% empirically whether beam_call_types/beam_ssa_type consult a callee's
%%% -spec for a cross-module call at all (source claims sub_unsafe(any,...)
%%% is the universal catch-all for any Mod:Func pair with no BIF-level rule —
%%% see beam_call_types.erl "Catch-all clause for unknown functions").
-module(xmod_a_specd).
-export([wrap/1, hit/1]).

-spec wrap(integer()) -> 0..99.
wrap(N) -> ((N rem 100) + 100) rem 100.

-spec hit(integer()) -> 0 | 1.
hit(0) -> 1;
hit(_) -> 0.
