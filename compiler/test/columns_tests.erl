%%% Scenarios: compiler/features/F35-columns.md
-module(columns_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [with_src/3]).

%%% F35 — diagnostics carry line and column positions.

guarded(Fun) ->
    case bs_test_support:built() of
        false -> ok;
        true  -> Fun()
    end.

parse_term(S) ->
    {ok, Tokens, _} = erl_scan:string(S ++ "."),
    {ok, Term} = erl_parse:parse_term(Tokens),
    Term.

desc(Path, Root) ->
    {_, Stdout, _} = bs_test_support:run_cli_split_result(
                       "--diagnostics term --src-root " ++ Root ++ " " ++ Path),
    parse_term(hd(string:split(string:trim(Stdout), "\n"))).

prose(Path, Root) ->
    {_, _, Stderr} = bs_test_support:run_cli_split_result(
                       "--src-root " ++ Root ++ " " ++ Path),
    Stderr.

%% A signature points at its name: Rank starts at column 12.
inexhaustive_src() ->
    "module Rank\n"
    "type Signal = :red | :amber | :green\n"
    "public int Rank(Signal s)\n"
    "Rank(:red) -> 1\n"
    "Rank(:green) -> 3\n".

%% Indenting only the signature shifts its name token four columns.
indented_src() ->
    "module Rank\n"
    "type Signal = :red | :amber | :green\n"
    "    public int Rank(Signal s)\n"
    "Rank(:red) -> 1\n"
    "Rank(:green) -> 3\n".

%%% F35.1 — the term carries a column.

the_term_carries_a_column_test() ->
    guarded(fun() ->
        with_src("in.bs", inexhaustive_src(), fun(Path, Root) ->
            ?assertMatch(#{tag := inexhaustive, line := 3, column := 12},
                         desc(Path, Root))
        end)
    end).

%%% F35.2 — the column follows the source text.

%% A constant column cannot pass the indentation comparison.
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

%%% F35.3 — the prose names the column.

the_prose_names_the_column_test() ->
    guarded(fun() ->
        with_src("in.bs", inexhaustive_src(), fun(Path, Root) ->
            ?assertNotEqual(nomatch,
                            string:find(prose(Path, Root), "in.bs:3:12: error:"))
        end)
    end).

%%% F35.4 — a resolve-time error carries a position.

%% Types carry no position; the error points at F, not Missing.
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

%%% F35.5 — a positioned warning carries both line and column.

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
