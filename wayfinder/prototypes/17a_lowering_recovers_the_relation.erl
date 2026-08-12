%%% 17a — Does LOWERING to a comprehension recover what a generic call throws away?
%%%
%%% Ticket 27 §6 measured that an emitted polymorphic `-spec` is documentation, not
%%% enforcement: Dialyzer reads the type variables as `any()`. Prototype 27a measured the
%%% complement — a comprehension preserves the element-type relation EXACTLY, under an
%%% analysis with no type variables at all, because it is syntax the analyser sees through.
%%%
%%% Both measurements were taken about the SURFACE language. This probe asks the question
%%% neither did, and it is a CODEGEN question rather than a syntax one:
%%%
%%%   If beam-sharp's surface is `xs |> List.Map(f)` — a call to a real, generic function —
%%%   does the compiler still get 27a's precision by LOWERING that call to an inlined
%%%   comprehension in the emitted abstract format, rather than to a call to a generic
%%%   `list_map/2`?
%%%
%%% If yes, the surface syntax and the emitted form are independent choices, and ticket 17
%%% can pick the pipe on readability grounds while keeping the typing win that 27a found
%%% belongs to comprehensions. It would also partially repair the boundary weakening that
%%% ticket 27 §6 explicitly handed to ticket 18.
%%%
%%% Measured locally, OTP 28.5 (`erlang:system_info(otp_release)` = 28), `typer` against a
%%% PLT of erts/kernel/stdlib.
%%%
%%% RESULT — typer --plt p17.plt 17a_lowering_recovers_the_relation.erl:
%%%
%%%   -spec roundtrip_lowered_to_comprehension([integer()]) -> [binary()].
%%%   -spec roundtrip_lowered_to_generic_call([any()])      -> [any()].
%%%   -spec filter_lowered_to_comprehension([any()])        -> [pos_integer()].
%%%   -spec filter_lowered_to_generic_call([any()])         -> [any()].
%%%   -spec chain_lowered_to_comprehension([any()])         -> [binary()].
%%%   -spec chain_lowered_to_generic_call([any()])          -> [any()].
%%%   -spec chain_lowered_to_fused_comprehension([any()])   -> [binary()].
%%%
%%% READING:
%%%
%%% 1. ANSWERED, YES. The surface form and the emitted form are independent. `roundtrip`
%%%    recovers `[integer()] -> [binary()]` — 27a's exact result — from a lowering decision
%%%    alone. The pipe can be the only surface syntax and the precision is still available.
%%%
%%% 2. The generic call loses BOTH sides on every case, including the ones where the fun is
%%%    a visible literal. 27a's `via_lists_map` kept the result element type because the
%%%    inline fun's body was visible through `lists:map/2`; here it does not, because
%%%    beam-sharp's own `list_map/2` carries a DECLARED spec (ticket 27 §6's widened
%%%    emission) and a contract overrides the success typing of the body. So the loss under
%%%    beam-sharp's emission is strictly worse than the loss 27a measured for `lists:map/2`.
%%%
%%% 3. UNEXPECTED — the comprehension is more precise than the surface signature can be.
%%%    `filter_lowered_to_comprehension` returns `[pos_integer()]`, narrowed out of the
%%%    guards. `List.Filter<T>(list<T>, fn(T) -> bool) -> list<T>` cannot say that: at the
%%%    surface, filter's output element type IS its input element type. The lowering
%%%    recovers a fact the language's own type system throws away.
%%%
%%% 4. Composition preserves the OUTPUT side (`chain` → `[binary()]`), which is the side
%%%    ticket 18 cares about. The input degrading to `[any()]` is not a lowering artefact:
%%%    `is_integer(X)` in a filter genuinely accepts any list. `roundtrip` keeps
%%%    `[integer()]` because `integer_to_binary/1` genuinely constrains it.
%%%
%%% 5. FUSION IS FREE. The fused single comprehension yields the identical spec to the
%%%    two-stage version while building no intermediate list. So deforestation is available
%%%    to the lowering at no cost in precision — which removes the main PERFORMANCE argument
%%%    for a lazy stream type, leaving only unbounded sources and early termination.
%%%
%%% CONSEQUENCE FOR TICKET 18: ticket 27 §6 found that choosing generics made the emitted
%%% boundary strictly weaker, and handed that to 18. This is the repair — but a PARTIAL one,
%%% and its limit is the interesting part. Precision is a privilege of whatever the compiler
%%% chooses to inline. A user-written generic function gets `[any()]` no matter what, because
%%% the mechanism is inlining, not analysis.

-module('17a_lowering_recovers_the_relation').

-export([roundtrip_lowered_to_comprehension/1,
         roundtrip_lowered_to_generic_call/1,
         filter_lowered_to_comprehension/1,
         filter_lowered_to_generic_call/1,
         chain_lowered_to_comprehension/1,
         chain_lowered_to_generic_call/1,
         chain_lowered_to_fused_comprehension/1,
         list_map/2,
         list_filter/2]).

%%% ---------------------------------------------------------------------------
%%% The generic prelude functions, as beam-sharp would emit them under ticket 27.
%%%
%%% `List.Map<T, U>(list<T>, fn(T) -> U) -> list<U>` has no Erlang spelling: ticket 13 §5
%%% widens to the nearest expressible supertype, and ticket 27 §6 measured that the emitted
%%% variables read as `any()`. These two specs ARE that emission.
%%% ---------------------------------------------------------------------------

-spec list_map(fun((any()) -> any()), [any()]) -> [any()].
list_map(F, Xs) -> [F(X) || X <- Xs].

-spec list_filter(fun((any()) -> boolean()), [any()]) -> [any()].
list_filter(P, Xs) -> [X || X <- Xs, P(X)].

%%% ---------------------------------------------------------------------------
%%% Case 1 — map with a genuinely different output element type.
%%% This is 27a's `roundtrip`, the load-bearing line, taken through both lowerings.
%%% ---------------------------------------------------------------------------

roundtrip_lowered_to_comprehension(Xs) ->
    [integer_to_binary(X) || X <- Xs].

roundtrip_lowered_to_generic_call(Xs) ->
    list_map(fun integer_to_binary/1, Xs).

%%% ---------------------------------------------------------------------------
%%% Case 2 — filter, where input and output element types are identical.
%%% 27a never measured filter. If the relation is preserved here it is preserved by
%%% the comprehension's own typing rule, not by the body of the mapping function.
%%% ---------------------------------------------------------------------------

filter_lowered_to_comprehension(Xs) ->
    [X || X <- Xs, X > 0, is_integer(X)].

filter_lowered_to_generic_call(Xs) ->
    list_filter(fun(X) -> is_integer(X) andalso X > 0 end, Xs).

%%% ---------------------------------------------------------------------------
%%% Case 3 — a two-stage pipeline, which is what ticket 17 is actually designing.
%%% `xs |> List.Filter(p) |> List.Map(f)`. The question is whether the relation
%%% survives COMPOSITION, or only survives a single stage.
%%% ---------------------------------------------------------------------------

chain_lowered_to_comprehension(Xs) ->
    Kept = [X || X <- Xs, is_integer(X), X > 0],
    [integer_to_binary(X) || X <- Kept].

chain_lowered_to_generic_call(Xs) ->
    Kept = list_filter(fun(X) -> is_integer(X) andalso X > 0 end, Xs),
    list_map(fun integer_to_binary/1, Kept).

%%% ---------------------------------------------------------------------------
%%% Case 4 — the same two-stage pipeline FUSED into one comprehension, building no
%%% intermediate list. If precision survives fusion, then deforestation is available
%%% to the lowering, which removes the main performance argument for a lazy stream
%%% type — the reason ticket 17 asks the laziness question at all.
%%% ---------------------------------------------------------------------------

chain_lowered_to_fused_comprehension(Xs) ->
    [integer_to_binary(X) || X <- Xs, is_integer(X), X > 0].
