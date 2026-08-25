-module(division_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2, errors/1]).

%%% ---------------------------------------------------------------------------
%%% F26 — `/` and `%`, ticket 38.
%%%
%%% THE VALUE ASSERTION IS THE EMISSION ASSERTION, which is why these tests run
%%% the code rather than reading the beam. Ticket 38 decided that `/` lowers to
%%% Erlang's `div` and NEVER to Erlang's `/`, which is float division. Measured
%%% on OTP 28: `-7 div 2` is `-3` and `-7 / 2` is `-3.5`. So a test asserting the
%%% integer `-3` fails loudly if the emitter ever reaches for `/` — no
%%% disassembly, and no way for the check to pass while the wrong operator ships.
%%%
%%% Implements ticket 38. Decides nothing.
%%% ---------------------------------------------------------------------------

src(Body) ->
    "module Div\n\n"
    "public int Slash(int a, int b)\n"
    "Slash(a, b) -> a / b\n\n"
    "public int Pct(int a, int b)\n"
    "Pct(a, b) -> a % b\n\n" ++ Body.

%%% --- F26.1 — truncation, and its sign ---------------------------------------

%% `/` on two ints truncates TOWARD ZERO. If this returns -3.5 the emitter used
%% Erlang's `/`; if it returns -4 the emitter used floor division.
slash_truncates_toward_zero_test() ->
    M = build_and_load(src(""), 'Div'),
    ?assertEqual(-3, M:'Slash'(-7, 2)),
    ?assertEqual(3,  M:'Slash'(7, 2)),
    ?assertEqual(-3, M:'Slash'(7, -2)).

%% `%` is the remainder `/` leaves, signed by the DIVIDEND — not the divisor,
%% which is where Python and Erlang part company.
pct_is_signed_by_the_dividend_test() ->
    M = build_and_load(src(""), 'Div'),
    ?assertEqual(-1, M:'Pct'(-7, 2)),
    ?assertEqual(1,  M:'Pct'(7, 2)),
    ?assertEqual(1,  M:'Pct'(7, -2)).

%% The identity the two operators owe each other, over a spread of signs.
quotient_and_remainder_reconstruct_the_dividend_test() ->
    M = build_and_load(src(""), 'Div'),
    [?assertEqual(A, M:'Slash'(A, B) * B + M:'Pct'(A, B))
     || A <- [-7, -1, 0, 1, 7, 100], B <- [-3, -1, 1, 2, 3]].

%%% --- F26.1b — `int` is a bignum, and division must not narrow it -----------

%% RAISED BY DAVID MID-BUILD: "on the BEAM an int is arbitrarily long, not
%% int32, not int64, more like BigNumber."
%%
%% The type model already agrees — `bs_types:int()` is `[{neg_inf, pos_inf}]`,
%% unbounded at both ends, with no machine width anywhere in the interval
%% representation — and Erlang's `div`/`rem` are exact on bignums. So this test
%% asserts something that is true today. It exists because NOTHING ELSE WOULD
%% CATCH IT BREAKING: every other case in this file fits in a machine word, so a
%% future change that clamped `int` to 64 bits, or emitted a fixed-width op,
%% would leave the whole suite green.
%%
%% 2^100 needs 101 bits, so it cannot be mistaken for anything narrower.
a_bignum_divides_exactly_test() ->
    M = build_and_load(src(""), 'Div'),
    TwoPow100 = 1267650600228229401496703205376,
    ?assertEqual(181092942889747057356671886482, M:'Slash'(TwoPow100, 7)),
    ?assertEqual(2, M:'Pct'(TwoPow100, 7)),
    %% and the identity still reconstructs, which a truncation to 64 bits breaks
    ?assertEqual(TwoPow100, M:'Slash'(TwoPow100, 7) * 7 + M:'Pct'(TwoPow100, 7)).

%% The same, written as a LITERAL in B# source rather than passed in, so the
%% lexer and the emitted form are exercised on a value no machine word holds.
a_bignum_literal_survives_the_front_end_test() ->
    Src = "module Big\n\n"
          "public int Go(int d)\n"
          "Go(d) -> 1267650600228229401496703205376 / d\n",
    M = build_and_load(Src, 'Big'),
    ?assertEqual(181092942889747057356671886482, M:'Go'(7)).

%%% --- F26.2 — the precondition, and the fact that there isn't one ------------

%% Ticket 38: "`/` carries no precondition". A divisor that MIGHT be zero
%% compiles, and crashes at run time if it is — ticket 12's stance.
a_possibly_zero_divisor_compiles_test() ->
    Src = "module Mean\n\n"
          "public int Of(int total, int count)\n"
          "Of(total, count) -> total / count\n",
    ?assertMatch({ok, _}, compile(Src)).

%% ...and only a divisor the compiler PROVES is zero is refused.
a_provably_zero_divisor_is_refused_test() ->
    Src = "module Bad\n\n"
          "public int Go(int n)\n"
          "Go(n) -> n / 0\n",
    [D | _] = errors(Src),
    ?assertMatch({divide_by_zero, '/'}, element(4, D)).

%% The same rule reaches `%`, which leaves the same divisor unusable.
a_provably_zero_modulus_is_refused_test() ->
    Src = "module BadPct\n\n"
          "public int Go(int n)\n"
          "Go(n) -> n % 0\n",
    [D | _] = errors(Src),
    ?assertMatch({divide_by_zero, '%'}, element(4, D)).

%% CONTROL — the check must not fire on every literal divisor, only on zero.
%% Without this, a rule that refused all literals would pass the two above.
a_nonzero_literal_divisor_compiles_test() ->
    Src = "module Half\n\n"
          "public int Go(int n)\n"
          "Go(n) -> n / 2\n",
    ?assertMatch({ok, _}, compile(Src)).

%% CONTROL — a refinement that EXCLUDES zero is not the same as a literal, and
%% must also compile. Ticket 38 records `int where value != 0` as available.
a_divisor_refined_away_from_zero_compiles_test() ->
    Src = "module Safe\n\n"
          "type NonZero = int where value != 0\n\n"
          "public int Go(int n, NonZero d)\n"
          "Go(n, d) -> n / d\n",
    ?assertMatch({ok, _}, compile(Src)).
