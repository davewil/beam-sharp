%%% Scenarios: compiler/features/F16-diagnostic-as-a-term.md
-module(diagnostic_term_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [with_src/3, project_root/0]).

%%% Diagnostic terms

%% Keep streams separate to test which channel carries each output.
out(Args) ->
    {_, Stdout, _} = bs_test_support:run_cli_split_result(Args),
    Stdout.

err(Args) ->
    {_, _, Stderr} = bs_test_support:run_cli_split_result(Args),
    Stderr.

guarded(Fun) ->
    case bs_test_support:built() of
        false -> ok;
        true  -> Fun()
    end.

%% Parsing proves the output is an Erlang term, beyond resembling one.
parse_term(S) ->
    {ok, Tokens, _} = erl_scan:string(S ++ "."),
    {ok, Term} = erl_parse:parse_term(Tokens),
    Term.

%% Consumers split on newlines: each descriptor must occupy one line.
terms(S) ->
    [parse_term(L) || L <- string:split(string:trim(S), "\n", all), L =/= ""].

inexhaustive_src() ->
    "module Rank\n"
    "type Signal = :red | :amber | :green\n"
    "public int Rank(Signal s)\n"
    "Rank(:red) -> 1\n"
    "Rank(:green) -> 3\n".

%%% F16.1, F16.2 — the CLI separates terms from prose.

%% F16.1 — stdout carries the diagnostic and a pasteable clause.
the_term_is_published_on_stdout_test() ->
    guarded(fun() ->
        with_src("in.bs", inexhaustive_src(), fun(Path, Root) ->
            Desc = parse_term(out("--diagnostics term --src-root " ++ Root ++
                                      " " ++ Path)),
            ?assertMatch(#{tag := inexhaustive, severity := error}, Desc),
            #{heads := #{pasteable := Pasteable}} = Desc,
            ?assertEqual(["Rank(:amber) -> ..."], Pasteable)
        end)
    end).

%% F16.2 — the default channel leaves stdout empty.
the_default_channel_writes_nothing_to_stdout_test() ->
    guarded(fun() ->
        with_src("in.bs", inexhaustive_src(), fun(Path, Root) ->
            ?assertEqual("", out("--src-root " ++ Root ++ " " ++ Path)),
            ?assertNotEqual(nomatch,
                            string:find(err("--src-root " ++ Root ++ " " ++ Path),
                                        "is not exhaustive"))
        end)
    end).

%%% F16.3 — prose equals the formatted descriptor.

the_prose_is_the_format_of_the_term_test() ->
    guarded(fun() ->
        with_src("in.bs", inexhaustive_src(), fun(Path, Root) ->
            Args = "--src-root " ++ Root ++ " " ++ Path,
            Desc  = parse_term(out("--diagnostics term " ++ Args)),
            Prose = err(Args),
            ?assertEqual(Prose,
                         unicode:characters_to_list(bs_diag:format(Desc)))
        end)
    end).

%%% F16.4 — raised conditions also produce descriptors.

a_raised_condition_gets_a_descriptor_too_test() ->
    guarded(fun() ->
        Src = "module R\n"
              "public int F(Missing m)\n"
              "F(m) -> 1\n",
        with_src("in.bs", Src, fun(Path, Root) ->
            Desc = parse_term(out("--diagnostics term --src-root " ++ Root ++
                                      " " ++ Path)),
            ?assertMatch(#{tag := unknown_type, severity := error}, Desc)
        end)
    end).

%%% F16.5 — warnings carry severity and allow compilation.

a_warning_carries_its_severity_and_still_compiles_test() ->
    guarded(fun() ->
        Src = "module W\n"
              "public int F(int n)\n"
              "F(n) -> 1\n"
              "F(0) -> 0\n",
        with_src("in.bs", Src, fun(Path, Root) ->
            Args = "--diagnostics term --src-root " ++ Root ++ " " ++ Path,
            Desc = parse_term(out(Args)),
            ?assertMatch(#{tag := unreachable_clause, severity := warning}, Desc),
            %% Warning severity must agree with a successful exit status.
            {Rc, _Output} = bs_test_support:run_cli_result(Args),
            ?assertEqual(0, Rc)
        end)
    end).

%%% F16.6 — an unsynthesisable head offers nothing.

%% Exercise the published descriptor directly: an argument that is not a
%% whole parameter cannot yield a caller clause head.
an_unsynthesisable_caller_head_offers_nothing_test() ->
    Residual = bs_types:atom_lit(oops),
    %% Production positions carry both line and column; the descriptor
    %% needs both to select its message.
    Desc = bs_diag:descriptor("x.bs",
                              {error, {3, 7}, "F",
                               {arg_not_accepted, 'G', 1, Residual, none}}),
    ?assertMatch(#{tag := arg_not_accepted, caller_head := none}, Desc),
    %% The prose must also omit a suggestion when no caller head is available.
    Prose = unicode:characters_to_list(bs_diag:format(Desc)),
    ?assertEqual(nomatch, string:find(Prose, "the clause to add here")).

a_synthesisable_caller_head_is_pasteable_test() ->
    Residual = bs_types:atom_lit(oops),
    Desc = bs_diag:descriptor("x.bs",
                              {error, 3, "F",
                               {arg_not_accepted, 'G', 1, Residual,
                                {1, 2, #{}}}}),
    %% Heads form a list because a residual can require multiple clauses.
    ?assertMatch(#{caller_head := ["F(:oops, _) -> ..."]}, Desc).

%%% F16.7 — unknown tags have no generic renderer.

an_unknown_tag_crashes_rather_than_rendering_generic_prose_test() ->
    ?assertError(function_clause,
                 bs_diag:format(#{tag => no_such_diagnostic_exists,
                                  severity => error, file => "x.bs"})).

every_contractual_tag_is_rendered_test() ->
    Src = filename:join([project_root(), "src", "bs_diag.erl"]),
    {ok, Bin} = file:read_file(Src),
    Text = binary_to_list(Bin),
    [?assertNotEqual(nomatch,
                     string:find(Text, "#{tag := " ++ atom_to_list(T)))
     || T <- bs_diag:contractual()].

%%% Complete terms and truncated prose

the_descriptor_keeps_every_case_the_prose_truncates_test() ->
    guarded(fun() ->
        Src = "module Odd\n"
              "public int Odd(int n)\n"
              "Odd(1) -> 1\n"
              "Odd(3) -> 3\n"
              "Odd(5) -> 5\n"
              "Odd(7) -> 7\n",
        with_src("in.bs", Src, fun(Path, Root) ->
            Args = "--src-root " ++ Root ++ " " ++ Path,
            Desc = parse_term(out("--diagnostics term " ++ Args)),
            #{heads := #{products := [[Parts]]}} = Desc,
            %% Removing four isolated integers leaves five disjoint ranges.
            ?assertEqual(5, length(Parts)),
            %% Prose shows three cases and counts the remaining two.
            Prose = err(Args),
            ?assertNotEqual(nomatch, string:find(Prose, "... (2 more)"))
        end)
    end).

%%% F16.8 — diagnostic emission passes the gate.

the_diagnostics_gate_passes_test() ->
    Script = filename:join([project_root(), "bin", "check-diagnostics.sh"]),
    case filelib:is_regular(Script) of
        false -> ?assert(false);
        true  ->
            {Rc, _Output} = bs_test_support:run_command_result(Script),
            ?assertEqual(0, Rc)
    end.

%%% Stream framing

%% Multiple descriptors expose wrapping that a single parsed term allows.
two_diagnostics_are_two_independently_parseable_lines_test() ->
    guarded(fun() ->
        Src = "module Multi\n"
              "type Signal = :red | :amber | :green\n"
              "public int Rank(Signal s)\n"
              "Rank(:red) -> 1\n"
              "public int Grade(Signal s)\n"
              "Grade(:green) -> 3\n",
        with_src("in.bs", Src, fun(Path, Root) ->
            Terms = terms(out("--diagnostics term --src-root " ++ Root ++
                                  " " ++ Path)),
            ?assertEqual(2, length(Terms)),
            ?assertEqual([inexhaustive, inexhaustive],
                         [maps:get(tag, T) || T <- Terms]),
            ?assertEqual(['Grade', 'Rank'],
                         lists:sort([maps:get(function, T) || T <- Terms]))
        end)
    end).

%% REPL values use stdout, which the term channel reserves for descriptors.
the_term_channel_is_refused_in_the_repl_test() ->
    guarded(fun() ->
        %% `ibs` uses `--repl`; `-S` alone is accepted but does not select it.
        {Rc, Out} = bs_test_support:run_cli_result(
                      "--repl -S x.bs --diagnostics term"),
        ?assertNotEqual(nomatch, string:find(Out, "not available in the REPL")),
        ?assertEqual(2, Rc)
    end).
