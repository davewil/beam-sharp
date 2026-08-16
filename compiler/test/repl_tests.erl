%%% The `ibs` prompt — tested at ITS boundary, which is keystrokes in, printed
%%% output out.
%%%
%%% WHY THIS FILE EXISTS
%%% The REPL had **zero tests** until 2026-08-15 and had by then been the
%%% discovery site for five separate defects, one per feature that touched it:
%%%
%%%   F4  a stale diagnostic that named a construct the language had
%%%   F5  a destructuring bind that did not work there
%%%   F7  `true` and `false` reported as unbound names
%%%   ..  `(1, 2)` eaten by the call parser, so braces looked mandatory
%%%   ..  a declaration answered with "cannot read ... as a value"
%%%
%%% Every one was found by a person typing at it, and every one was fixed
%%% without a test, so the next feature rediscovered the pattern rather than the
%%% suite catching it. David, 2026-08-15: *"close the gap."*
%%%
%%% Each test below is a REGRESSION for one of those, plus the basics they kept
%%% breaking around.
%%%
%%% HOW IT DRIVES THE PROMPT
%%% `ibs` is a three-line front end on `bsc --repl`, so the tests drive the
%%% escript directly and feed stdin from a file — no shell quoting, which is its
%%% own source of false failures. Skipped when the escript is not built, exactly
%%% as the other CLI tests are, so `rebar3 eunit` on a clean tree is not red for
%%% a reason unrelated to the code.

-module(repl_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [escript/0, with_src/3]).

-define(OUT, "/tmp/bsc_eunit").

src() ->
    "module Repl\n"
    "record Order { Id: int, Total: int }\n"
    "int Squared(Order o)\n"
    "Squared(o) -> o.Total * o.Total\n"
    "atom Flag(bool b)\n"
    "Flag(true)  -> :yes\n"
    "Flag(false) -> :no\n"
    "term Echo(term t)\n"
    "Echo(t) -> t\n".

%% Drives the prompt and hands back everything it printed. `:quit` is appended
%% so the session always ends, whatever the lines under test do.
repl(Lines) ->
    with_src("repl.bs", src(),
             fun(Path, Out) ->
                     In = Out ++ "/repl.in",
                     ok = file:write_file(
                            In, string:join(Lines ++ [":quit"], "\n") ++ "\n"),
                     os:cmd(escript() ++ " --repl -o " ++ Out ++ " " ++ Path ++
                            " < " ++ In ++ " 2>&1")
             end).

%% Asserts on a SUBSTRING rather than the whole transcript, because the banner
%% carries the export list and would make every test a change detector for the
%% source above.
said(Out, What) -> ?assertNotEqual(nomatch, string:find(Out, What)).
silent(Out, What) -> ?assertEqual(nomatch, string:find(Out, What)).

%% Skipping is the suite's existing convention for tests that need the escript,
%% and it is kept — but NOT silently. Twelve tests reporting `ok` while running
%% nothing is the precise failure this file was written to end, so an unbuilt
%% tree says so on every one of them rather than showing a wall of green.
built() ->
    case filelib:is_regular(escript()) of
        true  -> true;
        false ->
            io:format(user, "  SKIPPED (no escript — run `rebar3 escriptize`)~n", []),
            false
    end.

%%% --- the basics the defects kept breaking around ----------------------------

a_call_returns_a_value_test() ->
    case built() of
        false -> ok;
        true  -> said(repl(["Squared({Kind = :'Repl.Order', Id = 1, Total = 5})"]), "25")
    end.

a_binding_is_readable_afterwards_test() ->
    case built() of
        false -> ok;
        true  ->
            %% The bound name is read from INSIDE a record literal, which is a
            %% separate path from resolving it bare.
            Out = repl(["var x = 7",
                        "Squared({Kind = :'Repl.Order', Id = 1, Total = x})"]),
            said(Out, "49")
    end.

%%% --- regressions, one per defect the prompt produced ------------------------

%% `(1, 2)` was read as a call to a nameless function, because `parse_call/1`
%% took ANY text before a `(` for a function name — so it answered
%% `no /2 -- try :exports` and braces looked like the only way to type a tuple.
a_parenthesised_tuple_binds_and_echoes_test() ->
    case built() of
        false -> ok;
        true  ->
            Out = repl(["var y = (1, 2)", "y"]),
            said(Out, "(1, 2)"),
            silent(Out, "no /2")
    end.

%% ...and the printer's own spelling comes back through the reader, which is the
%% property that was broken: a brace is a record, a tuple is parenthesised.
a_brace_that_is_not_a_record_names_both_spellings_test() ->
    case built() of
        false -> ok;
        true  ->
            Out = repl(["var z = {1, 2}"]),
            said(Out, "a tuple is parenthesised"),
            said(Out, "a brace is a record")
    end.

a_record_round_trips_in_one_spelling_test() ->
    case built() of
        false -> ok;
        true  ->
            Out = repl(["var r = {Id = 1, Total = 500}", "r"]),
            said(Out, "Total = 500")
    end.

%% F7. `true` and `false` are the language's two keyword atoms, and the prompt
%% resolved a bare word from its bindings first — so they reached `is_name/1`
%% and were reported unbound.
the_keyword_atoms_resolve_at_the_prompt_test() ->
    case built() of
        false -> ok;
        true  ->
            Out = repl(["Flag(true)", "Flag(false)"]),
            said(Out, ":yes"),
            said(Out, ":no"),
            silent(Out, "not bound")
    end.

%% A declaration used to answer "cannot read ... as a value" — true, and useless,
%% because it named what the prompt wanted rather than where the thing goes.
a_declaration_says_where_declarations_go_test() ->
    case built() of
        false -> ok;
        true  ->
            Out = repl(["record Thing { Id: int }"]),
            said(Out, ":reload")
    end.

%%% --- `=` is a match, not an assignment -------------------------------------
%%%
%%% David, 2026-08-15: *"I do want Elixir matching behaviour. e.g x = 1, then
%%% 1 = x, 2 = x is an error."* The LANGUAGE already had it — and stronger, since
%%% F5 rejects the failing case at compile time where Elixir raises at run time.
%%% The prompt did not: `binding/1` required a plain name on the left, so
%%% `1 = x` never reached a match at all.

a_literal_on_the_left_matches_test() ->
    case built() of
        false -> ok;
        true  ->
            Out = repl(["var x = 1", "1 = x"]),
            silent(Out, "cannot read")
    end.

a_literal_that_cannot_match_is_refused_test() ->
    case built() of
        false -> ok;
        true  -> said(repl(["var x = 1", "2 = x"]), "does not match")
    end.

%% Closes the hole F5 left at this prompt: a destructuring bind that binds.
a_destructuring_match_binds_every_name_test() ->
    case built() of
        false -> ok;
        true  ->
            Out = repl(["var p = (1, 2)", "var (a, b) = p", "Echo(b)"]),
            said(Out, "2"),
            silent(Out, "does not match")
    end.

%% F8.8 — ONE RULE, BOTH SURFACES, AND THIS PROMPT IS THE SURFACE THAT MOVED.
%%
%% Until 2026-08-16 this test asserted PIN-BY-DEFAULT: a bound name in a pattern
%% matched the value it held, under a source comment stating the language
%% therefore *"needs no `^`: there is nothing to disambiguate."* That shipped the
%% same day David settled the opposite shape, and ticket 45 found it — nothing
%% failed, because both halves agreed with themselves.
%%
%% The marked rule won: a bare name INTRODUCES, `== name` matches. So the prompt
%% changed and the claim was deleted with the behaviour, which matters more than
%% the branch did — a confident comment arguing a settled question away survives
%% a test suite, and the branch beneath it does not.
a_bound_name_must_be_marked_to_match_test() ->
    case built() of
        false -> ok;
        true  ->
            %% `== n` matches the value `n` holds, so the match succeeds.
            Ok = repl(["var p = (1, 2)", "var n = 1", "var (== n, b) = p"]),
            silent(Ok, "does not match"),
            %% ...and genuinely tests it, rather than matching anything.
            No = repl(["var p = (1, 2)", "var m = 9", "var (== m, b) = p"]),
            said(No, "does not match")
    end.

%% The other half of the same rule, and the one a reader of the old dialect will
%% trip on first: a BARE bound name is a rebinding, and the message names `==` as
%% the fix rather than merely refusing.
a_bare_bound_name_is_a_rebinding_and_names_the_fix_test() ->
    case built() of
        false -> ok;
        true  ->
            Out = repl(["var p = (1, 2)", "var n = 1", "var (n, b) = p"]),
            said(Out, "already bound"),
            said(Out, "== n")
    end.

%% David's three lines, now identical at the prompt and in a file. `x = 1` is the
%% one that changed: it used to introduce here and now refuses, naming `var`.
a_bare_binding_at_the_prompt_refuses_and_names_var_test() ->
    case built() of
        false -> ok;
        true  ->
            Out = repl(["x = 1"]),
            said(Out, "var x = ")
    end.

%% `== name` needs something to match against, and saying so beats reporting the
%% pattern as unreadable — F4's rule that a diagnostic names the fix.
an_unbound_name_after_the_marker_says_so_test() ->
    case built() of
        false -> ok;
        true  -> said(repl(["var p = (1, 2)", "var (== nope, b) = p"]),
                      "not bound")
    end.

%% The message names what was typed against what it was typed at. Reporting the
%% failing COMPONENT said "(9, _) does not match 1", naming a number nobody
%% wrote.
a_failed_match_names_the_whole_value_test() ->
    case built() of
        false -> ok;
        true  -> said(repl(["var p = (1, 2)", "(9, _) = p"]), "does not match (1, 2)")
    end.

%%% --- the diagnostics that were already right, pinned so they stay right -----

an_unbound_name_says_so_test() ->
    case built() of
        false -> ok;
        true  -> said(repl(["nope"]), "not bound")
    end.

%% A PascalCase word is a function someone forgot the parentheses on, not a
%% value that failed to read.
a_bare_function_name_is_not_a_failed_value_test() ->
    case built() of
        false -> ok;
        true  -> said(repl(["Squared"]), "not a call")
    end.

an_unknown_arity_names_the_exports_test() ->
    case built() of
        false -> ok;
        true  -> said(repl(["Squared(1, 2)"]), ":exports")
    end.

%%% --- the session itself -----------------------------------------------------

the_banner_lists_the_exports_test() ->
    case built() of
        false -> ok;
        true  ->
            Out = repl([]),
            said(Out, "Squared/1"),
            said(Out, "Flag/1")
    end.

exports_and_reload_both_answer_test() ->
    case built() of
        false -> ok;
        true  ->
            Out = repl([":exports", ":reload"]),
            said(Out, "Squared/1"),
            %% `:reload` recompiles the file it was started on; the check is
            %% that it answers rather than what it prints, since the file has
            %% not changed underneath it.
            silent(Out, "cannot read")
    end.
