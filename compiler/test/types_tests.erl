-module(types_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, check_only/1]).

%%% ---------------------------------------------------------------------------
%%% Integer intervals
%%% ---------------------------------------------------------------------------

guarded_integer_partition_is_exhaustive_test() ->
    Src = "module M\n"
          "public int Fib(int n)\n"
          "Fib(n) when n <= 1 -> n\n"
          "Fib(n) when n > 1  -> Fib(n - 1) + Fib(n - 2)\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

fib_actually_computes_test() ->
    Src = "module M\n"
          "public int Fib(int n)\n"
          "Fib(n) when n <= 1 -> n\n"
          "Fib(n) when n > 1  -> Fib(n - 1) + Fib(n - 2)\n",
    M = build_and_load(Src, 'M'),
    ?assertEqual(0,  M:'Fib'(0)),
    ?assertEqual(1,  M:'Fib'(1)),
    ?assertEqual(55, M:'Fib'(10)).

interval_hole_is_found_test() ->
    Src = "module M\n"
          "type Band = :low | :mid | :high\n"
          "public Band Classify(int n)\n"
          "Classify(n) when n < 10   -> :low\n"
          "Classify(n) when n >= 100 -> :high\n",
    {error, [{error, _, _, {inexhaustive, Residual, _}}]} = check_only(Src),
    ?assertEqual("(10..99)", bs_types:to_string(Residual)).

conjunction_in_a_guard_is_credited_test() ->
    Src = "module M\n"
          "type Band = :low | :mid | :high\n"
          "public Band Classify(int n)\n"
          "Classify(n) when n < 10             -> :low\n"
          "Classify(n) when n >= 10 and n < 100 -> :mid\n"
          "Classify(n) when n >= 100           -> :high\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

%% The remainder guard is legal on the BEAM but credits no coverage.
uncreditable_guard_credits_nothing_test() ->
    Src = "module M\n"
          "public int F(int n)\n"
          "F(n) when n % 2 == 0 -> n\n",
    {error, Diags} = check_only(Src),
    ?assertMatch([{error, _, 'F', {inexhaustive, _, _}}], Diags).

%%% ---------------------------------------------------------------------------
%%% The algebra's own laws — no boundary reaches these
%%% ---------------------------------------------------------------------------

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

union_is_exact_test() ->
    A = bs_types:range(32, 32),
    B = bs_types:range(64, 64),
    U = bs_types:union(A, B),
    ?assertNot(bs_types:is_subtype(bs_types:range(96, 96), U)),
    ?assert(bs_types:is_none(bs_types:subtract(bs_types:subtract(U, A), B))).

cofinite_atoms_test() ->
    Rest = bs_types:subtract(bs_types:atom_top(), bs_types:atom_lit(ok)),
    ?assertNot(bs_types:is_none(Rest)),
    ?assert(bs_types:is_none(bs_types:intersect(Rest, bs_types:atom_lit(ok)))),
    ?assert(bs_types:is_subtype(bs_types:atom_lit(other), Rest)).

tuple_subtraction_decomposes_test() ->
    Ok = bs_types:atom_lit(ok),
    Err = bs_types:atom_lit(error),
    T = bs_types:union(bs_types:tuple([Ok, bs_types:int()]),
                       bs_types:tuple([Err, bs_types:atom_top()])),
    R = bs_types:subtract(T, bs_types:tuple([Ok, bs_types:int()])),
    ?assertEqual("(:error, atom)", bs_types:to_string(R)),
    ?assert(bs_types:is_none(bs_types:subtract(R, bs_types:tuple([Err, bs_types:atom_top()])))).

%%% ---------------------------------------------------------------------------
%%% Map partition laws
%%% ---------------------------------------------------------------------------

rec(Tag, Fields) ->
    bs_types:map_closed(Fields#{'Kind' => bs_types:atom_lit(Tag)}).

pat(Fields) -> bs_types:map_open(Fields).

a_tag_pattern_covers_the_whole_record_test() ->
    Order = rec('Shop.Order', #{'Id' => bs_types:int()}),
    P = pat(#{'Kind' => bs_types:atom_lit('Shop.Order')}),
    ?assert(bs_types:is_none(bs_types:subtract(Order, P))).

a_tag_pattern_leaves_the_other_record_test() ->
    Order = rec('Shop.Order', #{'Id' => bs_types:int()}),
    Invoice = rec('Shop.Invoice', #{'Id' => bs_types:int()}),
    Doc = bs_types:union(Order, Invoice),
    P = pat(#{'Kind' => bs_types:atom_lit('Shop.Order')}),
    ?assertEqual("{ Kind: :'Shop.Invoice' }",
                 bs_types:to_pattern(bs_types:subtract(Doc, P))).

a_union_of_two_records_keeps_both_test() ->
    Order = rec('Shop.Order', #{'Id' => bs_types:int()}),
    Invoice = rec('Shop.Invoice', #{'Id' => bs_types:int()}),
    #{maps := Members} = bs_types:union(Order, Invoice),
    ?assertEqual(2, length(Members)).

the_same_tag_absorbs_to_one_member_test() ->
    A = rec('Shop.Order', #{'Id' => bs_types:int()}),
    B = rec('Shop.Order', #{'Id' => bs_types:int()}),
    #{maps := Members} = bs_types:union(A, B),
    ?assertEqual(1, length(Members)).

different_field_sets_are_disjoint_test() ->
    A = rec('Shop.Order', #{'Id' => bs_types:int()}),
    B = rec('Shop.Order', #{'Id' => bs_types:int(), 'Total' => bs_types:int()}),
    ?assertEqual(A, bs_types:subtract(A, B)).

a_catch_all_covers_every_record_test() ->
    Order = rec('Shop.Order', #{'Id' => bs_types:int()}),
    ?assert(bs_types:is_none(bs_types:subtract(Order, bs_types:term()))).

a_guard_over_a_record_field_still_credits_the_clause_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "public atom Band(Order o)\n"
          "Band({ Total: t }) when t > 0 -> :paid\n"
          "Band({ Total: t }) when t <= 0 -> :unpaid\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%%% ---------------------------------------------------------------------------
%%% Negation
%%% ---------------------------------------------------------------------------

a_negative_literal_is_an_expression_test() ->
    Src = "module Neg\n"
          "public int MinusOne()\n"
          "MinusOne() -> -1\n",
    M = build_and_load(Src, 'Neg'),
    ?assertEqual(-1, M:'MinusOne'()).

a_variable_can_be_negated_test() ->
    Src = "module NegV\n"
          "public int Flip(int n)\n"
          "Flip(n) -> -n\n",
    M = build_and_load(Src, 'NegV'),
    ?assertEqual(-7, M:'Flip'(7)),
    ?assertEqual(7, M:'Flip'(-7)).

%% Conflict counts cannot prove associativity; the computed value does.
binary_minus_survives_the_prefix_one_test() ->
    Src = "module NegB\n"
          "public int Chain()\n"
          "Chain() -> 1 - 2 - 3\n"
          "public int Mixed()\n"
          "Mixed() -> 10 - -2\n",
    M = build_and_load(Src, 'NegB'),
    ?assertEqual(-4, M:'Chain'()),
    ?assertEqual(12, M:'Mixed'()).

a_negative_literal_dispatches_in_a_pattern_test() ->
    Src = "module NegP\n"
          "public atom Sign(int n)\n"
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

%%% ---------------------------------------------------------------------------
%%% Product absorption and top printing
%%% ---------------------------------------------------------------------------

a_union_of_a_product_with_itself_is_the_product_test() ->
    P = bs_types:tuple([bs_types:int(), bs_types:int()]),
    ?assertEqual("(int, int)", bs_types:to_string(bs_types:union(P, P))).

%% Structurally different products can contain each other; dedup is not enough.
mutually_containing_products_keep_a_representative_test() ->
    IA = bs_types:tuple([bs_types:int(), bs_types:atom_top()]),
    AI = bs_types:tuple([bs_types:atom_top(), bs_types:int()]),
    X  = bs_types:union(IA, AI),
    Y  = bs_types:union(AI, IA),
    U  = bs_types:union(bs_types:tuple([X, bs_types:int()]),
                        bs_types:tuple([Y, bs_types:int()])),
    ?assertNot(bs_types:is_none(U)),
    ?assert(bs_types:is_subtype(bs_types:tuple([X, bs_types:int()]), U)).

the_top_prints_as_term_test() ->
    ?assertEqual("term", bs_types:to_string(bs_types:term())).

%%% ---------------------------------------------------------------------------
%%% Inline unions
%%% ---------------------------------------------------------------------------

inline_union_parameter_is_exhaustive_test() ->
    Src = "module M\n"
          "public int Handle(:ok | :error x)\n"
          "Handle(:ok)    -> 1\n"
          "Handle(:error) -> 0\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

inline_union_and_its_alias_give_the_same_residual_test() ->
    Inline = "module M\n"
             "public int Handle(:ok | :error x)\n"
             "Handle(:ok) -> 1\n",
    Alias  = "module M\n"
             "type R = :ok | :error\n"
             "public int Handle(R x)\n"
             "Handle(:ok) -> 1\n",
    {error, [{error, _, _, {inexhaustive, RInline, _}}]} = check_only(Inline),
    {error, [{error, _, _, {inexhaustive, RAlias,  _}}]} = check_only(Alias),
    ?assertEqual(bs_types:to_string(RAlias), bs_types:to_string(RInline)),
    ?assertEqual("(:error)", bs_types:to_string(RInline)).

inline_union_of_tuples_in_a_parameter_test() ->
    Src = "module M\n"
          "public int Handle((:ok, int) | (:error, int) r)\n"
          "Handle((:ok, n))    -> n\n"
          "Handle((:error, _)) -> 0\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

anonymous_inline_union_parameter_test() ->
    Src = "module M\n"
          "public int Handle(:ok | :error)\n"
          "Handle(:ok)    -> 1\n"
          "Handle(:error) -> 0\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

inline_union_beside_an_ordinary_parameter_test() ->
    Src = "module M\n"
          "public int Handle(:ok | :error x, int n)\n"
          "Handle(:ok, n)    -> n\n"
          "Handle(:error, _) -> 0\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

inline_union_in_a_return_position_test() ->
    Src = "module M\n"
          "public :ok | :error Pick(int n)\n"
          "Pick(n) when n > 0  -> :ok\n"
          "Pick(n) when n <= 0 -> :error\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

inline_union_return_without_a_visibility_marker_test() ->
    Src = "module M\n"
          "public int Total(int n)\n"
          "Total(n) -> Score(Pick(n))\n"
          ":ok | :error Pick(int n)\n"
          "Pick(n) when n > 0  -> :ok\n"
          "Pick(n) when n <= 0 -> :error\n"
          "int Score(:ok | :error r)\n"
          "Score(:ok)    -> 1\n"
          "Score(:error) -> 0\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

%% check_only never calls OTP; this signature uses application:get_env/2
%% to match a real foreign return contract.
inline_union_in_a_foreign_signature_test() ->
    Src = "module M\n"
          "using :application {\n"
          "    (:ok, term) | :undefined get_env(atom app, atom par)\n"
          "}\n"
          "public (:ok, term) | :undefined Setting(atom a, atom p)\n"
          "Setting(a, p) -> :application.get_env(a, p)\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

inline_union_parameter_actually_runs_test() ->
    Src = "module InlineUnion\n"
          "public int Handle(:ok | :error x)\n"
          "Handle(:ok)    -> 1\n"
          "Handle(:error) -> 0\n",
    M = build_and_load(Src, 'InlineUnion'),
    ?assertEqual(1, M:'Handle'(ok)),
    ?assertEqual(0, M:'Handle'(error)).
