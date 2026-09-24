%%% Scenarios: compiler/features/F27-no-negation.md
%%% The diagnostic term is the contract; prose comes from its renderer.
%%% These checks need no subprocess; bin/check-negation.sh covers the CLI.
-module(negation_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2]).

parse_descriptor(Src) ->
    {ok, Toks, _} = bs_lexer:string(Src),
    {error, Err} = bs_parser:parse(Toks),
    bs_diag:descriptor("t.bs", {parse, Err, Toks}).

%% `!` fails in the lexer and never reaches the parser.
lex_descriptor(Src) ->
    {error, Err, _} = bs_lexer:string(Src),
    bs_diag:descriptor("t.bs", {lex, Err}).

prose(D) -> lists:flatten(bs_diag:format(D)).

%%% --- Negation spellings ---
%%% Guard and refinement failures expose different tokens to yecc.

not_in_a_guard_is_taught_test() ->
    D = parse_descriptor("module T\n"
                         "public :atom F(int n)\n"
                         "F(n) when not (n > 100) -> :small\n"
                         "F(n) -> :big\n"),
    ?assertMatch(#{tag := no_negation, spelling := "not", line := 3}, D),
    ?assert(string:find(prose(D), "beam-sharp has no `not`") =/= nomatch),
    ?assert(string:find(prose(D), "negation is not an operator here") =/= nomatch).

not_in_a_refinement_is_taught_test() ->
    D = parse_descriptor("module T\n"
                         "type S = int where not (value > 100)\n"
                         "public :atom F(S n)\n"
                         "F(n) -> :small\n"),
    ?assertMatch(#{tag := no_negation, spelling := "not", line := 2}, D),
    ?assert(string:find(prose(D), "beam-sharp has no `not`") =/= nomatch).

%% Without parentheses, parsing fails before the operand, not before `(`.
not_without_parentheses_is_taught_test() ->
    D = parse_descriptor("module T\n"
                         "public :atom F(int n)\n"
                         "F(n) when not n > 100 -> :small\n"
                         "F(n) -> :big\n"),
    ?assertMatch(#{tag := no_negation, spelling := "not", line := 3}, D).

bang_is_taught_test() ->
    D = lex_descriptor("module T\n"
                       "public :atom F(int n)\n"
                       "F(n) when !n -> :small\n"
                       "F(n) -> :big\n"),
    ?assertMatch(#{tag := no_negation, spelling := "!", line := 3}, D),
    ?assert(string:find(prose(D), "beam-sharp has no `!`") =/= nomatch).

%% `!=` is a token and must not be mistaken for a bare `!`.
not_equal_is_untouched_test() ->
    ?assertMatch({ok, _, _},
                 bs_lexer:string("module T\n"
                                 "type S = int where value != 0\n")).

%%% --- Controls ---

%% Reserving `not` would reject this valid identifier use.
not_is_still_an_identifier_test() ->
    M = build_and_load("module NotId\n"
                       "type Size = :big | :small\n"
                       "public Size F(int not)\n"
                       "F(not) when not > 100 -> :big\n"
                       "F(not) -> :small\n", 'NotId'),
    ?assertEqual(big, M:'F'(500)),
    ?assertEqual(small, M:'F'(5)).

%% An unrelated parse failure must not trigger the negation hint.
an_unrelated_syntax_error_is_not_taught_test() ->
    D = parse_descriptor("module T\n"
                         "public :atom F(int n)\n"
                         "F(n) when n > -> :small\n"
                         "F(n) -> :big\n"),
    ?assertMatch(#{tag := parse_error}, D),
    ?assert(string:find(prose(D), "negation is not an operator here") =:= nomatch).
