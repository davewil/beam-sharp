%%% Ticket 63 — negation has no spelling, and the absence teaches.
%%%
%%% The decision was `no not`, on REDUNDANCY rather than danger: everywhere the
%%% checker can read a guard, `alternatives/1`'s fragment is already closed
%%% under complement (proved nine ways with two controls in prototype 63c), so a
%%% `not` the translator had learned would compile into the exact spelling the
%%% author could have written. David took the option that pairs the refusal with
%%% a diagnostic naming the complement, so the message is part of the decision
%%% rather than a courtesy on top of it.
%%%
%%% THESE ASSERT THE TERM, NOT THE PROSE, which is F16's contract: the
%%% descriptor is the diagnostic and `message/1` is a pure function of it. Doing
%%% it this way also keeps the suite off `os:cmd` — ENG-229 has the CLI-driven
%%% tests failing intermittently, and there is nothing here that needs a
%%% subprocess. `bin/check-negation.sh` asserts the same five facts at the real
%%% CLI boundary, where a subprocess is the point.
-module(negation_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2]).

%% The descriptor a parse failure mints, given the tokens that produced it.
parse_descriptor(Src) ->
    {ok, Toks, _} = bs_lexer:string(Src),
    {error, Err} = bs_parser:parse(Toks),
    bs_diag:descriptor("t.bs", {parse, Err, Toks}).

%% The descriptor a LEX failure mints. `!` never reaches the parser.
lex_descriptor(Src) ->
    {error, Err, _} = bs_lexer:string(Src),
    bs_diag:descriptor("t.bs", {lex, Err}).

prose(D) -> lists:flatten(bs_diag:format(D)).

%%% ---------------------------------------------------------------------------
%%% The three spellings that must be taught
%%%
%%% Guard and refinement fail at DIFFERENT tokens — `'('` and `'>'` — so a rule
%%% keyed on the token yecc reported would pass the first and miss the second.
%%% The ticket's "one translator, so a guard and a refinement cannot disagree"
%%% is about `alternatives/1` in the checker and does not reach the parser.
%%% ---------------------------------------------------------------------------

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

%% `not` with no parentheses fails before the operand rather than before `(`.
not_without_parentheses_is_taught_test() ->
    D = parse_descriptor("module T\n"
                         "public :atom F(int n)\n"
                         "F(n) when not n > 100 -> :small\n"
                         "F(n) -> :big\n"),
    ?assertMatch(#{tag := no_negation, spelling := "not", line := 3}, D).

%% The spelling a C#/TS reader reaches for on sight. It is an ILLEGAL CHARACTER,
%% so it is caught in the lexer and never reaches the parse path above.
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

%%% ---------------------------------------------------------------------------
%%% The two absences
%%%
%%% Both are asserted against a run that gets far enough to be evidence. This
%%% repo has shipped a check that asserted an absence against a compile that
%%% never happened, so neither of these is a bare "no crash".
%%% ---------------------------------------------------------------------------

%% THE RESERVED-WORD CONTROL. `not` is an ordinary identifier and stays one:
%% reserving it would be the cheap way to a sharp message and would take a name
%% out of the language, which is ticket 65's decision and not ticket 63's.
%% This is the test that fails if a later session reaches for the keyword.
not_is_still_an_identifier_test() ->
    M = build_and_load("module NotId\n"
                       "type Size = :big | :small\n"
                       "public Size F(int not)\n"
                       "F(not) when not > 100 -> :big\n"
                       "F(not) -> :small\n", 'NotId'),
    ?assertEqual(big, M:'F'(500)),
    ?assertEqual(small, M:'F'(5)).

%% THE CRY-WOLF CONTROL. A hint keyed on parse failure alone would satisfy every
%% test above and be worthless. There is no `not` in this source.
an_unrelated_syntax_error_is_not_taught_test() ->
    D = parse_descriptor("module T\n"
                         "public :atom F(int n)\n"
                         "F(n) when n > -> :small\n"
                         "F(n) -> :big\n"),
    ?assertMatch(#{tag := parse_error}, D),
    ?assert(string:find(prose(D), "negation is not an operator here") =:= nomatch).
