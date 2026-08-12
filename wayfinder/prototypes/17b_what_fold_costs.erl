%%% 17b — What does FOLD cost, once map and filter are lowered to comprehensions?
%%%
%%% 27a established that a comprehension preserves the element-type relation exactly, and
%%% noted the limit: "It covers map and filter cleanly. It does not cover fold — there is no
%%% comprehension syntax for foldl, and 27 did not create one."
%%%
%%% 17a then established that beam-sharp can have that precision by LOWERING rather than by
%%% surface syntax. So the live question for ticket 17 is narrower than 27a's framing: not
%%% "should the surface reach fold" but **is there any lowering of fold that keeps the
%%% precision map and filter now get, or is fold structurally a second tier?**
%%%
%%% Three lowerings, each of which beam-sharp could plausibly emit for `List.Fold`:
%%%
%%%   (a) a call to lists:foldl/3 with the folding function inline
%%%   (b) an inlined, monomorphic recursive function emitted per call site
%%%   (c) a call to a generic prelude list_fold/3 carrying ticket 27 §6's widened spec
%%%
%%% Measured locally, OTP 28.5, `typer` against a PLT of erts/kernel/stdlib.
%%%
%%% RESULT — typer --plt p17.plt 17b_what_fold_costs.erl:
%%%
%%%   -spec sum_via_inlined_recursion([number()])   -> number().
%%%   -spec sum_via_foldl([any()])                  -> number().
%%%   -spec sum_via_generic_fold([any()])           -> any().
%%%
%%%   -spec join_via_inlined_recursion([integer()]) -> bitstring().
%%%   -spec join_via_foldl([any()])                 -> binary().
%%%   -spec join_via_generic_fold([any()])          -> any().
%%%
%%% READING:
%%%
%%% 1. FOLD IS NOT A SECOND TIER, and 27a's framing was about Erlang's available SYNTAX
%%%    rather than about a limit on precision. Lowering (b) — an inlined monomorphic
%%%    recursive function — recovers the relation on BOTH sides for the type-changing case:
%%%    `[integer()] -> bitstring()`, exactly parallel to 17a's `[integer()] -> [binary()]`.
%%%
%%% 2. So the mechanism was never "comprehension". It is **inlining a monomorphic body the
%%%    analyser can see through**, and a comprehension is merely the shortest spelling of
%%%    that for map and filter. One lowering rule covers map, filter and fold alike, which
%%%    is a simpler rule than ticket 17 expected to have to write.
%%%
%%% 3. Lowering (a), `lists:foldl/3` with an inline fun, reproduces 27a's `via_lists_map`
%%%    exactly: the result type survives because the fun's body is visible, the input element
%%%    type does not because it passes through `foldl`'s own declared spec. Confirms the loss
%%%    is located AT the higher-order boundary, now on a second operation.
%%%
%%% 4. HONEST CAVEAT, and it lands on ticket 20's pile. Inlined recursion is more precise on
%%%    the input side but LESS precise on the output side in the binary case: `bitstring()`
%%%    where `lists:foldl` gave `binary()`. The accumulator widens at the recursive fixpoint,
%%%    and it widens specifically at a BINARY — the shape ticket 20 records as untheorised
%%%    and ticket 25 puts three of six ordinary workloads on. Not a reason to prefer (a):
%%%    losing the input element type is the worse loss, and `bitstring()` is a sound
%%%    supertype rather than a wrong answer.

-module('17b_what_fold_costs').

-export([sum_via_foldl/1, sum_via_inlined_recursion/1, sum_via_generic_fold/1,
         join_via_foldl/1, join_via_inlined_recursion/1, join_via_generic_fold/1,
         list_fold/3]).

%%% ---------------------------------------------------------------------------
%%% The generic prelude fold, as beam-sharp would emit it under ticket 27 §6.
%%% `List.Fold<T, A>(list<T>, A, fn(T, A) -> A) -> A` widens to this.
%%% ---------------------------------------------------------------------------

-spec list_fold(fun((any(), any()) -> any()), any(), [any()]) -> any().
list_fold(F, Acc, Xs) -> lists:foldl(F, Acc, Xs).

%%% ---------------------------------------------------------------------------
%%% Case 1 — accumulator type equals element type. The easy case.
%%% ---------------------------------------------------------------------------

sum_via_foldl(Xs) ->
    lists:foldl(fun(X, A) -> X + A end, 0, Xs).

sum_via_inlined_recursion(Xs) ->
    sum_loop(Xs, 0).

sum_loop([], A) -> A;
sum_loop([X | Rest], A) -> sum_loop(Rest, X + A).

sum_via_generic_fold(Xs) ->
    list_fold(fun(X, A) -> X + A end, 0, Xs).

%%% ---------------------------------------------------------------------------
%%% Case 2 — accumulator type DIFFERS from element type. This is fold's version of
%%% 27a's `roundtrip`: [integer()] in, binary() out. If any lowering preserves this
%%% relation, fold is not a second tier.
%%% ---------------------------------------------------------------------------

join_via_foldl(Xs) ->
    lists:foldl(fun(X, A) -> <<A/binary, (integer_to_binary(X))/binary>> end, <<>>, Xs).

join_via_inlined_recursion(Xs) ->
    join_loop(Xs, <<>>).

join_loop([], A) -> A;
join_loop([X | Rest], A) ->
    join_loop(Rest, <<A/binary, (integer_to_binary(X))/binary>>).

join_via_generic_fold(Xs) ->
    list_fold(fun(X, A) -> <<A/binary, (integer_to_binary(X))/binary>> end, <<>>, Xs).
