%%% Probe for ticket 39 sub-decision 2 (causation test). wrap/1 and hit/1
%%% live in their OWN module with NO -spec, so a caller in a different
%%% module gets whatever the compiler's default cross-module assumption is
%%% (no interprocedural body inlining across module boundaries) rather than
%%% the same-module SSA fixpoint that narrows to exact integer ranges.
-module(xmod_a).
-export([wrap/1, hit/1]).

wrap(N) -> ((N rem 100) + 100) rem 100.

hit(0) -> 1;
hit(_) -> 0.
