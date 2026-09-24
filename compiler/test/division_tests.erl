%%% Scenarios: compiler/features/F26-division-and-remainder.md
-module(division_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2, errors/1]).

%%% F26 — integer division and remainder.

src(Body) ->
    "module Div\n\n"
    "public int Slash(int a, int b)\n"
    "Slash(a, b) -> a / b\n\n"
    "public int Pct(int a, int b)\n"
    "Pct(a, b) -> a % b\n\n" ++ Body.

%%% F26.1 — division truncates toward zero; remainder follows the dividend.

%% The integer result distinguishes div from float or floor division.
slash_truncates_toward_zero_test() ->
    M = build_and_load(src(""), 'Div'),
    ?assertEqual(-3, M:'Slash'(-7, 2)),
    ?assertEqual(3,  M:'Slash'(7, 2)),
    ?assertEqual(-3, M:'Slash'(7, -2)).

pct_is_signed_by_the_dividend_test() ->
    M = build_and_load(src(""), 'Div'),
    ?assertEqual(-1, M:'Pct'(-7, 2)),
    ?assertEqual(1,  M:'Pct'(7, 2)),
    ?assertEqual(1,  M:'Pct'(7, -2)).

quotient_and_remainder_reconstruct_the_dividend_test() ->
    M = build_and_load(src(""), 'Div'),
    [?assertEqual(A, M:'Slash'(A, B) * B + M:'Pct'(A, B))
     || A <- [-7, -1, 0, 1, 7, 100], B <- [-3, -1, 1, 2, 3]].

%%% F26.1b — division preserves arbitrary-width integers.

%% This value needs 101 bits, beyond a machine word.
a_bignum_divides_exactly_test() ->
    M = build_and_load(src(""), 'Div'),
    TwoPow100 = 1267650600228229401496703205376,
    ?assertEqual(181092942889747057356671886482, M:'Slash'(TwoPow100, 7)),
    ?assertEqual(2, M:'Pct'(TwoPow100, 7)),
    %% The identity reconstructs; a truncation to 64 bits would break it.
    ?assertEqual(TwoPow100, M:'Slash'(TwoPow100, 7) * 7 + M:'Pct'(TwoPow100, 7)).

%% A source literal also exercises the lexer and emitted representation.
a_bignum_literal_survives_the_front_end_test() ->
    Src = "module Big\n\n"
          "public int Go(int d)\n"
          "Go(d) -> 1267650600228229401496703205376 / d\n",
    M = build_and_load(Src, 'Big'),
    ?assertEqual(181092942889747057356671886482, M:'Go'(7)).

%%% F26.2 — only provably zero divisors are refused.

%% A possibly zero divisor compiles; zero fails at runtime.
a_possibly_zero_divisor_compiles_test() ->
    Src = "module Mean\n\n"
          "public int Of(int total, int count)\n"
          "Of(total, count) -> total / count\n",
    ?assertMatch({ok, _}, compile(Src)).

a_provably_zero_divisor_is_refused_test() ->
    Src = "module Bad\n\n"
          "public int Go(int n)\n"
          "Go(n) -> n / 0\n",
    [D | _] = errors(Src),
    ?assertMatch({divide_by_zero, '/'}, element(4, D)).

a_provably_zero_modulus_is_refused_test() ->
    Src = "module BadPct\n\n"
          "public int Go(int n)\n"
          "Go(n) -> n % 0\n",
    [D | _] = errors(Src),
    ?assertMatch({divide_by_zero, '%'}, element(4, D)).

%% This control rules out refusing every literal divisor.
a_nonzero_literal_divisor_compiles_test() ->
    Src = "module Half\n\n"
          "public int Go(int n)\n"
          "Go(n) -> n / 2\n",
    ?assertMatch({ok, _}, compile(Src)).

%% A nonzero refinement must compile as well as a nonzero literal.
a_divisor_refined_away_from_zero_compiles_test() ->
    Src = "module Safe\n\n"
          "type NonZero = int where value != 0\n\n"
          "public int Go(int n, NonZero d)\n"
          "Go(n, d) -> n / d\n",
    ?assertMatch({ok, _}, compile(Src)).
