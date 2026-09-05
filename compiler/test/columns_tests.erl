-module(columns_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [with_src/3]).

%%% ---------------------------------------------------------------------------
%%% F35 — a diagnostic names a column, and a resolve-time error names a position
%%%
%%% A position is a line AND a column, because the second consumer of a
%%% diagnostic is an editor and a line alone cannot underline anything
%%% (ENG-297, from `editor/README.md`'s "what an LSP would need first").
%%%
%%% The column is a NEW KEY beside `line`, never a tuple replacing it. Ticket
%%% 23 §4 makes payload evolution additive only, and the suite's existing
%%% matchers are `#{... line := 3}` map patterns: a `{Line, Col}` in `line`
%%% would break every one of them, which is the shape the rule exists to
%%% forbid.
%%%
%%% THE CENTRAL TEST IS `the_column_follows_the_text_test`. Asserting that a
%%% column is an integer, or that it equals some value once, is passed by a
%%% descriptor that hardcodes `column => 1` — the plausible wrong fix, and the
%%% one a swap of `TokenLine` for `TokenLoc` would make if the loc never
%%% reached the term. So the same construct is compiled twice, indented the
%%% second time, and the two columns must DIFFER by the indent.
%%% ---------------------------------------------------------------------------

guarded(Fun) ->
    case bs_test_support:built() of
        false -> ok;
        true  -> Fun()
    end.

parse_term(S) ->
    {ok, Tokens, _} = erl_scan:string(S ++ "."),
    {ok, Term} = erl_parse:parse_term(Tokens),
    Term.

%% The descriptor of the first diagnostic the file produces.
desc(Path, Root) ->
    {_, Stdout, _} = bs_test_support:run_cli_split_result(
                       "--diagnostics term --src-root " ++ Root ++ " " ++ Path),
    parse_term(hd(string:split(string:trim(Stdout), "\n"))).

prose(Path, Root) ->
    {_, _, Stderr} = bs_test_support:run_cli_split_result(
                       "--src-root " ++ Root ++ " " ++ Path),
    Stderr.

%% A signature carries the position of its NAME token, not of its first word
%% (`bs_parser.yrl`'s `signature` productions read `line('$3')`). In
%% `public int Rank(Signal s)` that is `Rank`, which starts at column 12.
inexhaustive_src() ->
    "module Rank\n"
    "type Signal = :red | :amber | :green\n"
    "public int Rank(Signal s)\n"
    "Rank(:red) -> 1\n"
    "Rank(:green) -> 3\n".

%% The same program with the signature indented four spaces, so the name now
%% starts at column 16. Nothing else moves: leading whitespace is skipped by
%% the lexer, so this is the same parse with one token displaced.
indented_src() ->
    "module Rank\n"
    "type Signal = :red | :amber | :green\n"
    "    public int Rank(Signal s)\n"
    "Rank(:red) -> 1\n"
    "Rank(:green) -> 3\n".

%%% --- F35.1 — the term carries a column -------------------------------------

the_term_carries_a_column_test() ->
    guarded(fun() ->
        with_src("in.bs", inexhaustive_src(), fun(Path, Root) ->
            ?assertMatch(#{tag := inexhaustive, line := 3, column := 12},
                         desc(Path, Root))
        end)
    end).

%%% --- F35.2 — the column is read off the text, not minted ---------------------

%% The discriminating one. A constant column passes F35.1 and fails here.
the_column_follows_the_text_test() ->
    guarded(fun() ->
        with_src("in.bs", inexhaustive_src(), fun(P1, R1) ->
            with_src("in.bs", indented_src(), fun(P2, R2) ->
                #{column := Plain}    = desc(P1, R1),
                #{column := Indented} = desc(P2, R2),
                ?assertEqual(12, Plain),
                ?assertEqual(16, Indented),
                ?assertEqual(4, Indented - Plain)
            end)
        end)
    end).

%%% --- F35.3 — the prose names the column too ---------------------------------

%% Prose is a pure function of the term (ticket 23 §1), so a column in the term
%% that the prose does not print would make the two disagree about what is
%% known. The header is `file:line:column:`.
the_prose_names_the_column_test() ->
    guarded(fun() ->
        with_src("in.bs", inexhaustive_src(), fun(Path, Root) ->
            ?assertNotEqual(nomatch,
                            string:find(prose(Path, Root), "in.bs:3:12: error:"))
        end)
    end).

%%% --- F35.4 — a resolve-time error has a position at all ---------------------

%% `unknown_type` and its five neighbours are raised via `erlang:error` from
%% below the level that holds a position, so before F35 they reached the author
%% as `file: error: ...` with nothing to anchor to — an editor could not place
%% them anywhere but the top of the file. `kind_field_is_minted` already
%% carried a line, so the fix has precedent in the same module.
%%
%% THE POSITION IS THE DECLARATION'S, NOT THE TYPE NAME'S, and column 12 is
%% what says so: that is `F` in `public int F(Missing m)`, not `Missing` at
%% column 14. The grammar attaches no position to a type — `type_prim ->
%% uident : {t_ref, value('$1')}` drops the token's location — so the nearest
%% node that has one is the signature. Underlining the declaration that names
%% the missing type is the honest limit of this increment; the type's own span
%% needs a position on every type node, which is a change to the type grammar
%% and to every consumer of one.
a_resolve_time_error_carries_a_position_test() ->
    guarded(fun() ->
        Src = "module R\n"
              "public int F(Missing m)\n"
              "F(m) -> 1\n",
        with_src("in.bs", Src, fun(Path, Root) ->
            ?assertMatch(#{tag := unknown_type, line := 2, column := 12},
                         desc(Path, Root))
        end)
    end).

%%% --- F35.5 — every positioned diagnostic carries both halves -----------------

%% The invariant the gate holds at the source level, asserted here at the
%% boundary for one witness of each raising path: a descriptor that names a
%% line names a column beside it. A site that hands the term an integer where
%% a loc was expected produces the first without the second.
line_and_column_travel_together_test() ->
    guarded(fun() ->
        Src = "module W\n"
              "public int F(int n)\n"
              "F(n) -> 1\n"
              "F(0) -> 0\n",
        with_src("in.bs", Src, fun(Path, Root) ->
            D = desc(Path, Root),
            ?assertMatch(#{tag := unreachable_clause, severity := warning}, D),
            ?assert(is_integer(maps:get(line, D))),
            ?assert(is_integer(maps:get(column, D)))
        end)
    end).
