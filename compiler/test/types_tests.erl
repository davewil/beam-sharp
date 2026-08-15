-module(types_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, check_only/1]).

%%% ---------------------------------------------------------------------------
%%% Integer intervals — ticket 20's decision, exercised
%%% ---------------------------------------------------------------------------

%% Exhaustive ONLY if the checker sees that `n <= 1` and `n > 1` partition int.
guarded_integer_partition_is_exhaustive_test() ->
    Src = "module M\n"
          "int Fib(int n)\n"
          "Fib(n) when n <= 1 -> n\n"
          "Fib(n) when n > 1  -> Fib(n - 1) + Fib(n - 2)\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

fib_actually_computes_test() ->
    Src = "module M\n"
          "int Fib(int n)\n"
          "Fib(n) when n <= 1 -> n\n"
          "Fib(n) when n > 1  -> Fib(n - 1) + Fib(n - 2)\n",
    M = build_and_load(Src, 'M'),
    ?assertEqual(0,  M:'Fib'(0)),
    ?assertEqual(1,  M:'Fib'(1)),
    ?assertEqual(55, M:'Fib'(10)).

%% A hole in the middle of a partition must be found and named exactly.
interval_hole_is_found_test() ->
    Src = "module M\n"
          "type Band = :low | :mid | :high\n"
          "Band Classify(int n)\n"
          "Classify(n) when n < 10   -> :low\n"
          "Classify(n) when n >= 100 -> :high\n",
    {error, [{error, _, _, {inexhaustive, Residual}}]} = check_only(Src),
    ?assertEqual("(10..99)", bs_types:to_string(Residual)).

conjunction_in_a_guard_is_credited_test() ->
    Src = "module M\n"
          "type Band = :low | :mid | :high\n"
          "Band Classify(int n)\n"
          "Classify(n) when n < 10             -> :low\n"
          "Classify(n) when n >= 10 && n < 100 -> :mid\n"
          "Classify(n) when n >= 100           -> :high\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

%% Ticket 08: a condition the checker cannot translate credits nothing. That must
%% make the function *inexhaustive*, never accidentally exhaustive — an
%% uncreditable guard may not be read as full coverage.
uncreditable_guard_credits_nothing_test() ->
    Src = "module M\n"
          "int F(int n)\n"
          "F(n) when Weird(n) -> n\n",
    {error, Diags} = check_only(Src),
    ?assertMatch([{error, _, 'F', {inexhaustive, _}}], Diags).

%%% ---------------------------------------------------------------------------
%%% The algebra's own laws — no boundary reaches these
%%% ---------------------------------------------------------------------------

%% The precise failures measured against erl_types in prototype 20c.
interval_subtraction_is_exact_test() ->
    A = bs_types:range(1, 1000),
    B = bs_types:range(500, 2000),
    ?assertEqual("1..499", bs_types:to_string(bs_types:subtract(A, B))),
    ?assertNot(bs_types:is_none(bs_types:subtract(A, B))).

interval_subtyping_is_not_symmetric_test() ->
    Gt5 = bs_types:range(6, pos_inf),
    Gt0 = bs_types:range(1, pos_inf),
    ?assert(bs_types:is_subtype(Gt5, Gt0)),
    ?assertNot(bs_types:is_subtype(Gt0, Gt5)).

%% Ticket 20: the union does not widen. Two exact members stay two members, and
%% subtracting both empties the residual.
union_is_exact_test() ->
    A = bs_types:range(32, 32),
    B = bs_types:range(64, 64),
    U = bs_types:union(A, B),
    ?assertNot(bs_types:is_subtype(bs_types:range(96, 96), U)),
    ?assert(bs_types:is_none(bs_types:subtract(bs_types:subtract(U, A), B))).

%% Ticket 10: the atom universe is open, so `atom` is cofinite and the complement
%% of a singleton has to be representable.
cofinite_atoms_test() ->
    Rest = bs_types:subtract(bs_types:atom_top(), bs_types:atom_lit(ok)),
    ?assertNot(bs_types:is_none(Rest)),
    ?assert(bs_types:is_none(bs_types:intersect(Rest, bs_types:atom_lit(ok)))),
    ?assert(bs_types:is_subtype(bs_types:atom_lit(other), Rest)).

%% Componentwise subtraction would be wrong; the product decomposition is not.
tuple_subtraction_decomposes_test() ->
    Ok = bs_types:atom_lit(ok),
    Err = bs_types:atom_lit(error),
    T = bs_types:union(bs_types:tuple([Ok, bs_types:int()]),
                       bs_types:tuple([Err, bs_types:atom_top()])),
    R = bs_types:subtract(T, bs_types:tuple([Ok, bs_types:int()])),
    ?assertEqual("(:error, atom)", bs_types:to_string(R)),
    ?assert(bs_types:is_none(bs_types:subtract(R, bs_types:tuple([Err, bs_types:atom_top()])))).

%%% ---------------------------------------------------------------------------
%%% The map partition's own laws.
%%%
%%% Tested directly rather than at the boundary for the reason the header gives:
%%% the algebra has no boundary to be reached through. These are the properties
%%% ticket 20's exactness rests on, at the fifth constructor.
%%% ---------------------------------------------------------------------------

rec(Tag, Fields) ->
    bs_types:map_closed(Fields#{'Kind' => bs_types:atom_lit(Tag)}).

pat(Fields) -> bs_types:map_open(Fields).

%% A closed record minus a pattern naming only its tag is EMPTY — this is what
%% makes one clause cover a whole record.
a_tag_pattern_covers_the_whole_record_test() ->
    Order = rec('Shop.Order', #{'Id' => bs_types:int()}),
    P = pat(#{'Kind' => bs_types:atom_lit('Shop.Order')}),
    ?assert(bs_types:is_none(bs_types:subtract(Order, P))).

%% ...and leaves the OTHER record untouched, which is what makes the residual
%% name the case you missed rather than an empty set.
a_tag_pattern_leaves_the_other_record_test() ->
    Order = rec('Shop.Order', #{'Id' => bs_types:int()}),
    Invoice = rec('Shop.Invoice', #{'Id' => bs_types:int()}),
    Doc = bs_types:union(Order, Invoice),
    P = pat(#{'Kind' => bs_types:atom_lit('Shop.Order')}),
    ?assertEqual("{ Kind: :'Shop.Invoice' }",
                 bs_types:to_pattern(bs_types:subtract(Doc, P))).

%% Union is exact — the two members do NOT collapse into one wider map. This is
%% the property ticket 20 exists to guarantee, at the new partition.
a_union_of_two_records_keeps_both_test() ->
    Order = rec('Shop.Order', #{'Id' => bs_types:int()}),
    Invoice = rec('Shop.Invoice', #{'Id' => bs_types:int()}),
    #{maps := Members} = bs_types:union(Order, Invoice),
    ?assertEqual(2, length(Members)).

%% Two records over identical field sets with the same tag ARE one type, so the
%% union absorbs to a single member. F3.2's algebra half.
the_same_tag_absorbs_to_one_member_test() ->
    A = rec('Shop.Order', #{'Id' => bs_types:int()}),
    B = rec('Shop.Order', #{'Id' => bs_types:int()}),
    #{maps := Members} = bs_types:union(A, B),
    ?assertEqual(1, length(Members)).

%% Different field sets are disjoint when both sides fix their domain, so
%% subtracting one from the other removes nothing.
different_field_sets_are_disjoint_test() ->
    A = rec('Shop.Order', #{'Id' => bs_types:int()}),
    B = rec('Shop.Order', #{'Id' => bs_types:int(), 'Total' => bs_types:int()}),
    ?assertEqual(A, bs_types:subtract(A, B)).

%% A catch-all removes every map, because `term` contains the map top and
%% `anything \ top` is empty. Without this, `_` would not close a record union.
a_catch_all_covers_every_record_test() ->
    Order = rec('Shop.Order', #{'Id' => bs_types:int()}),
    ?assert(bs_types:is_none(bs_types:subtract(Order, bs_types:term()))).

%% A guard over a record field still credits its clause. Written because the
%% obvious implementation — treating a field as unaddressable, the way a list
%% element is — makes `refine_all/3` credit NOTHING, so a record pattern plus a
%% guard would report inexhaustive. Routed through the checker, not the algebra.
a_guard_over_a_record_field_still_credits_the_clause_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "atom Band(Order o)\n"
          "Band({ Total: t }) when t > 0 -> :paid\n"
          "Band({ Total: t }) when t <= 0 -> :unpaid\n",
    ?assertMatch({ok, _, _}, check_only(Src)).


%%% ---------------------------------------------------------------------------
%%% Negation — `-1` and `-n`
%%%
%%% Absent until 2026-08-15, and absent by OVERSIGHT: a grep for "unary" across
%%% LANGUAGE.md, every ticket, the fog and every feature file returned nothing.
%%% C# has it and Erlang has it, so both tiers agreed and there was nothing to
%%% decide — which is why it is a fix rather than a ticket, unlike division.
%%%
%%% Found by running AoC 2025 Day 1, where a direction had to be written
%%% `0 - 1`. Negative numbers had always arrived fine as DATA — `bs_run`'s
%%% reader handles `-68` — so the gap was only ever in source.
%%%
%%% It lowers to `0 - e` rather than gaining a node, so nothing downstream of
%%% the parser learns a new shape.
%%% ---------------------------------------------------------------------------

a_negative_literal_is_an_expression_test() ->
    Src = "module Neg\n"
          "int MinusOne()\n"
          "MinusOne() -> -1\n",
    M = build_and_load(Src, 'Neg'),
    ?assertEqual(-1, M:'MinusOne'()).

a_variable_can_be_negated_test() ->
    Src = "module NegV\n"
          "int Flip(int n)\n"
          "Flip(n) -> -n\n",
    M = build_and_load(Src, 'NegV'),
    ?assertEqual(-7, M:'Flip'(7)),
    ?assertEqual(7, M:'Flip'(-7)).

%% THE REGRESSION THAT MATTERS. Adding a prefix `-` to an expression grammar
%% that already has an infix `-` is exactly where a parser quietly changes
%% meaning: `1 - 2 - 3` must stay left-associative and give -4, not re-associate
%% to 1 - (2 - 3) and give 2.
%%
%% yecc reported zero conflicts for this change, and F6.9's rule is that the
%% count is not the check — it resolves shift/reduce silently through the
%% precedence table. So this asserts the VALUE.
binary_minus_survives_the_prefix_one_test() ->
    Src = "module NegB\n"
          "int Chain()\n"
          "Chain() -> 1 - 2 - 3\n"
          "int Mixed()\n"
          "Mixed() -> 10 - -2\n",
    M = build_and_load(Src, 'NegB'),
    ?assertEqual(-4, M:'Chain'()),
    ?assertEqual(12, M:'Mixed'()).

%% In a PATTERN it is a literal, not a computation, and the interval algebra
%% needs nothing new: `range(-1, -1)` is what `p_int` already produces. The
%% function is exhaustive over `int` with no catch-all, which is what proves the
%% negative literal took part in the subtraction rather than being ignored.
a_negative_literal_dispatches_in_a_pattern_test() ->
    Src = "module NegP\n"
          "atom Sign(int n)\n"
          "Sign(-1) -> :minus_one\n"
          "Sign(0)  -> :zero\n"
          "Sign(n) when n > 0 -> :positive\n"
          "Sign(n) when n < 0 -> :negative\n",
    {ok, _, Diags} = check_only(Src),
    ?assertEqual([], Diags),
    M = build_and_load(Src, 'NegP'),
    ?assertEqual(minus_one, M:'Sign'(-1)),
    ?assertEqual(negative,  M:'Sign'(-5)),
    ?assertEqual(zero,      M:'Sign'(0)),
    ?assertEqual(positive,  M:'Sign'(3)).
