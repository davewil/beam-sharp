-module(diagnostic_term_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [escript/0, with_src/3, project_root/0]).

%%% ---------------------------------------------------------------------------
%%% F16 — the diagnostic is a term, and prose is a pure function of it
%%%
%%% Ticket 23 §1. The 321 tests that existed before this feature are most of its
%%% coverage and they are not in this file: they assert on the PROSE, and the
%%% whole claim of the refactor is that the prose did not change while every
%%% message moved into `bs_diag`. What is here is only what those cannot see.
%%%
%%% THE CENTRAL TEST IS `the_prose_is_the_format_of_the_term_test`, and it is
%%% worth saying why it is shaped the way it is. It runs the compiler once,
%%% takes the TERM off stdout, parses it back into a map, hands that map to
%%% `bs_diag:format/1`, and requires the result to equal the PROSE the same run
%%% printed on stderr. That is §1 stated as an assertion rather than as an
%%% intention: not "both exist" but "one is the other, computed". A test that
%%% checked the two separately would pass on the day they diverge.
%%% ---------------------------------------------------------------------------

%% The suite's other CLI tests merge the streams (`2>&1`), which is exactly what
%% these cannot do: the feature's claim is that the two channels are SEPARATE.
out(Args) -> os:cmd(escript() ++ " " ++ Args ++ " 2>/dev/null").
err(Args) -> os:cmd(escript() ++ " " ++ Args ++ " 2>&1 1>/dev/null").

guarded(Fun) ->
    case bs_test_support:built() of
        false -> ok;
        true  -> Fun()
    end.

%% `~p` wraps long terms over several lines; scanning handles that, and parsing
%% back is what proves the printed form is a TERM rather than something that
%% merely looks like one.
parse_term(S) ->
    {ok, Tokens, _} = erl_scan:string(S ++ "."),
    {ok, Term} = erl_parse:parse_term(Tokens),
    Term.

%% The framing contract: one descriptor per line, so a consumer splits on
%% newlines and parses each. This helper is what a consumer would write, and it
%% is deliberately as naive as one — if it needs to get cleverer, the channel
%% has broken its promise.
terms(S) ->
    [parse_term(L) || L <- string:split(string:trim(S), "\n", all), L =/= ""].

inexhaustive_src() ->
    "module Rank\n"
    "type Signal = :red | :amber | :green\n"
    "public int Rank(Signal s)\n"
    "Rank(:red) -> 1\n"
    "Rank(:green) -> 3\n".

%%% --- F16.1, F16.2 — two channels, and only one of them is new ---------------

%% F16.1. The term names the tag to dispatch on, and carries the clause to
%% write. `pasteable` is 23 §2's whole point: the compiler synthesises the head
%% so that consumers never each invert the residual differently.
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

%% F16.2. The default prints NOTHING new. A consumer that never asks for the
%% term must not be able to tell this feature landed — which is why the channel
%% is a flag rather than a second stream that is always written.
the_default_channel_writes_nothing_to_stdout_test() ->
    guarded(fun() ->
        with_src("in.bs", inexhaustive_src(), fun(Path, Root) ->
            ?assertEqual("", out("--src-root " ++ Root ++ " " ++ Path)),
            ?assertNotEqual(nomatch,
                            string:find(err("--src-root " ++ Root ++ " " ++ Path),
                                        "is not exhaustive"))
        end)
    end).

%%% --- F16.3 — the one that makes §1 true rather than intended ----------------

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

%%% --- F16.4 — the raise path is not a second channel -------------------------

%% Ticket 23 §1 says "the diagnostic", not "the returned diagnostic". These are
%% found while RESOLVING types, below the level that carries a function name,
%% and before F16 they were a separate set of 32 `io:format` calls reached
%% through a `try`. A consumer cannot be asked to know which half of the
%% compiler noticed its mistake.
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

%%% --- F16.5 — severity is data, and a warning does not stop the run ----------

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
            %% It is a warning, so the compiler carried on and emitted.
            ?assertNotEqual(nomatch,
                            string:find(os:cmd(escript() ++ " " ++ Args ++
                                                   " 2>&1; echo rc:$?"), "rc:0"))
        end)
    end).

%%% --- F16.6 — where nothing can be synthesised, the term offers nothing ------

%% 23 §2: "where the residual is not guard-expressible the term says so and
%% offers nothing". Emitting an approximation there is the Elm defect in its most
%% dangerous form — output that reads as actionable and silently is not. Driven
%% through `bs_diag` directly because the published descriptor IS this feature's
%% boundary, and `none` is reached from an argument that is not a whole
%% parameter, which no clause head can be written for.
an_unsynthesisable_caller_head_offers_nothing_test() ->
    Residual = bs_types:atom_lit(oops),
    Desc = bs_diag:descriptor("x.bs",
                              {error, 3, "F",
                               {arg_not_accepted, 'G', 1, Residual, none}}),
    ?assertMatch(#{tag := arg_not_accepted, caller_head := none}, Desc),
    %% And the prose says nothing rather than proposing something wrong.
    Prose = unicode:characters_to_list(bs_diag:format(Desc)),
    ?assertEqual(nomatch, string:find(Prose, "the clause to add here")).

%% The other side of the same rule: when the argument IS a whole parameter, the
%% head is derived and it is pasteable.
a_synthesisable_caller_head_is_pasteable_test() ->
    Residual = bs_types:atom_lit(oops),
    Desc = bs_diag:descriptor("x.bs",
                              {error, 3, "F",
                               {arg_not_accepted, 'G', 1, Residual,
                                {1, 2, #{}}}}),
    %% F29 — A LIST, because the residual is a union and a head is not. One
    %% element here because `:oops` is one atom; an interval residual with two
    %% spans is two clauses to add, and joining them with `|` was the defect.
    ?assertMatch(#{caller_head := ["F(:oops, _) -> ..."]}, Desc).

%%% --- F16.7 — no generic renderer --------------------------------------------

%% `message/1` has no catch-all on purpose. A renderer that could always print
%% *something* would let a new diagnostic ship looking like it had a message,
%% which is the F12 finding in a new place: the gate is only as good as what it
%% was told to look at, and a generic fallback tells it nothing is missing.
%% `bin/check-diagnostics.sh` walks the roster in the source; this asserts the
%% property that makes the roster matter.
an_unknown_tag_crashes_rather_than_rendering_generic_prose_test() ->
    ?assertError(function_clause,
                 bs_diag:format(#{tag => no_such_diagnostic_exists,
                                  severity => error, file => "x.bs"})).

%% Every tag 23 §4 freezes as contractual must actually be producible today.
%% `defended` is deliberately absent — it is §3's boundary answer and no feature
%% has built it — and this test is what would notice if it were listed anyway.
every_contractual_tag_is_rendered_test() ->
    Src = filename:join([project_root(), "src", "bs_diag.erl"]),
    {ok, Bin} = file:read_file(Src),
    Text = binary_to_list(Bin),
    [?assertNotEqual(nomatch,
                     string:find(Text, "#{tag := " ++ atom_to_list(T)))
     || T <- bs_diag:contractual()].

%%% --- ticket 43's promise, now kept ------------------------------------------

%% `bsc.erl` recorded this in the future tense when it capped the prose: "the
%% descriptor keeps all forty-one and 23 §10's `bsc --api` is the full-fidelity
%% channel". That is why the term carries the residual's PARTS rather than
%% finished text — prose cannot be a pure function of a term that was truncated
%% before it arrived.
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
            %% Five disjoint cases in the term...
            ?assertEqual(5, length(Parts)),
            %% ...and three plus a marker in the prose (ticket 43's cap).
            Prose = err(Args),
            ?assertNotEqual(nomatch, string:find(Prose, "... (2 more)"))
        end)
    end).

%%% --- F16.8 — the gate ------------------------------------------------------

the_diagnostics_gate_passes_test() ->
    Script = filename:join([project_root(), "bin", "check-diagnostics.sh"]),
    case filelib:is_regular(Script) of
        false -> ?assert(false);
        true  ->
            Out = os:cmd(Script ++ " 2>&1; echo rc:$?"),
            ?assertNotEqual({nomatch, Out}, {string:find(Out, "rc:0"), Out})
    end.

%%% --- the framing, which is the part a consumer depends on -------------------

%% EVERY OTHER TEST HERE USES A FIXTURE WITH EXACTLY ONE DIAGNOSTIC, and that is
%% the case a consumer will least often meet: an agent compiles a file and gets
%% the list of clauses to write, not one. Under plain `~p` two descriptors wrap
%% across several lines each with nothing between them, so the only way to find
%% the boundary is to match brackets — which is the screen-scraping ticket 23
%% exists to abolish, reintroduced by the feature meant to end it. `~0p` makes
%% the newline the frame.
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

%% A flag accepted and quietly not honoured costs the flag its credibility
%% everywhere else, so the REPL refuses the combination rather than falling back
%% to prose: `ibs` prints values on stdout, and the flag's contract is that
%% stdout carries descriptors.
the_term_channel_is_refused_in_the_repl_test() ->
    guarded(fun() ->
        %% `ibs` is a thin front end on `bsc --repl`, so that is the flag
        %% the refusal has to see; `-S` alone is accepted and ignored by
        %% the arg parser, exactly as `iex -S mix` spells it.
        Out = os:cmd(escript() ++ " --repl -S x.bs --diagnostics term 2>&1; echo rc:$?"),
        ?assertNotEqual(nomatch, string:find(Out, "not available in the REPL")),
        ?assertNotEqual(nomatch, string:find(Out, "rc:2"))
    end).
