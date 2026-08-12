%%% 27a — Does the element-type relation survive without polymorphism?
%%%
%%% Ticket 27 asks whether beam-sharp needs polymorphic function signatures. The cost of
%%% saying no was stated as: `Map` becomes (list<term>, fn(term)->term) -> list<term>, and
%%% ticket 11 then forces an O(n) `ValidateAs<list<T>>` to recover a typed list from data
%%% that never left the program.
%%%
%%% This probe asks whether that cost is a property of *mapping* or a property of
%%% *abstracting the map into a function*. Dialyzer is the right instrument precisely
%%% because success typing has NO parametric polymorphism at all — whatever relation it
%%% preserves, it preserves without type variables.
%%%
%%% Measured locally, OTP 28.5, `typer` against a PLT of erts/kernel/stdlib.
%%%
%%% RESULT — typer p27a.erl:
%%%
%%%   -spec via_comprehension([number()]) -> [number()].
%%%   -spec via_lists_map([any()]) -> [number()].
%%%   -spec via_fun_arg([any()], fun((_) -> any())) -> [any()].
%%%   -spec roundtrip([integer()]) -> [binary()].
%%%
%%% READING:
%%%
%%% 1. `roundtrip` is the load-bearing line. It IS `Map`: input element `integer()`, output
%%%    element `binary()` — a genuinely different type — and the relation between them is
%%%    preserved EXACTLY, by an analysis with no type variables. The comprehension is syntax
%%%    the analyser sees through, so the element relation is established by a typing rule
%%%    rather than by solving a constraint. No tallying is involved because no constraint is
%%%    ever generated.
%%%
%%% 2. `via_fun_arg` is the measured no-generics `Map`. Route the identical computation
%%%    through an opaque fun ARGUMENT and every element type collapses to `any()` — on both
%%%    the argument and the result. This is ticket 11's `list<term>` arriving, and the
%%%    O(n) `ValidateAs` bill with it.
%%%
%%% 3. `via_lists_map` shows the degradation is not all-or-nothing and locates it precisely:
%%%    the inline `fun` keeps the RESULT element type (`[number()]`) because the fun's body
%%%    is visible, but loses the ARGUMENT element type (`[any()]`) because it passes through
%%%    `lists:map/2`'s own declared spec, which has already discarded it. This is the same
%%%    phenomenon the ticket recorded for Elixir's `Enum.map/2` — `element() :: any()` — and
%%%    it confirms the loss happens AT the higher-order boundary, not inside the mapping.
%%%
%%% CONCLUSION FOR TICKET 27 (written before the decision; re-framed after it).
%%%
%%% What this measures: syntax recovers the element-type RELATION with zero polymorphism,
%%% because the compiler writes the typing rule for a construct it can see through. Losing the
%%% relation is a property of abstracting an operation into a user-written higher-order
%%% function, not a property of the operation.
%%%
%%% Ticket 27 resolved in favour of real prenex parametric polymorphism, so this is NOT the
%%% mechanism the language relies on for `Map`. It remains load-bearing in three places:
%%%
%%%   - It is the reason ROW POLYMORPHISM was declined. Record update is `with`/spread — syntax
%%%     over a concrete record type — so the case that would have demanded a row variable is
%%%     already covered by the same mechanism measured here.
%%%   - It sizes what the syntax route covers for ticket 17 (pipeline and comprehension idiom):
%%%     map and filter cleanly, fold not at all.
%%%   - It is the fallback for anything generics decline to cover, which after 27 means
%%%     capability-constrained operations (deferred to ticket 16 with bounds).
%%%
%%% CAVEAT ON PROVENANCE: success typing is an underapproximation and is not beam-sharp's
%%% checker, which is set-theoretic. What this measures is that the element RELATION is
%%% recoverable from syntax alone with zero polymorphism — a lower bound on what beam-sharp's
%%% own comprehension typing rule can deliver, not a model of it.

-module(p27a).
-export([via_comprehension/1, via_lists_map/1, via_fun_arg/2, roundtrip/1]).

%% element type visible to the compiler: the body is syntax
via_comprehension(Xs) -> [X * 2 || X <- Xs].

%% element type via a known higher-order library function, fun written inline
via_lists_map(Xs) -> lists:map(fun(X) -> X * 2 end, Xs).

%% element type via an OPAQUE fun argument — the polymorphic case
via_fun_arg(Xs, F) -> lists:map(F, Xs).

%% a -> b: does a CHANGE of element type survive a comprehension?
roundtrip(Xs) -> [integer_to_binary(X) || X <- Xs].

%%% ---------------------------------------------------------------------------
%%% CORRECTION — ticket 17, 2026-08-13.
%%%
%%% The CONCLUSION above states, as the second of three places this measurement stays
%%% load-bearing: "It sizes what the syntax route covers for ticket 17 (pipeline and
%%% comprehension idiom): map and filter cleanly, fold not at all."
%%%
%%% THE SECOND HALF IS WRONG, and 17b falsified it directly. Fold is covered just as
%%% cleanly, by an inlined monomorphic recursive function rather than by a comprehension:
%%%
%%%   -spec join_via_inlined_recursion([integer()]) -> bitstring().   % both sides kept
%%%   -spec join_via_generic_fold([any()])          -> any().
%%%
%%% What this file actually measured was never a property of COMPREHENSIONS. It is a
%%% property of INLINING A MONOMORPHIC BODY THE ANALYSER CAN SEE THROUGH — and for map and
%%% filter, a comprehension is merely the shortest spelling of that. Erlang has no
%%% comprehension syntax for foldl, which is what made fold look like a gap; the gap was in
%%% Erlang's surface syntax, not in achievable precision.
%%%
%%% Ticket 17 §2 and §3 therefore state one rule where this file implied two: the
%%% compiler-known prelude is inlined, user code is called, and precision follows the
%%% inlining — uniformly across map, filter and fold.
%%%
%%% See prototypes/17b_what_fold_costs.erl and issues/17-pipeline-and-comprehension.md §3.
