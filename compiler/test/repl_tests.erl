%%% The `ibs` prompt: stdin in, printed output out.
%%% File-backed stdin avoids shell quoting. Tests need a built escript.

%%% Scenarios: compiler/features/F8-bind-and-match.md
%%% Scenarios: compiler/features/F7-switch.md
%%% Scenarios: compiler/features/F12-public-and-private.md
-module(repl_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [with_src/3]).

-define(OUT, bs_test_support:run_root()).

src() ->
    "module Repl\n"
    "record Order { Id: int, Total: int }\n"
    "public int Squared(Order o)\n"
    "Squared(o) -> o.Total * o.Total\n"
    "public atom Flag(bool b)\n"
    "Flag(true)  -> :yes\n"
    "Flag(false) -> :no\n"
    "public term Echo(term t)\n"
    "Echo(t) -> t\n"
    %% F12 — private calls are refused.
    %% `Twice` keeps `Half` in the beam: erlc removes uncalled private code.
    "public int Twice(int n)\n"
    "Twice(n) -> Half(n) + Half(n)\n"
    "private int Half(int n)\n"
    "Half(n) -> n\n".

%% Appending `:quit` ensures the session ends.
repl(Lines) ->
    with_src("repl.bs", src(),
             fun(Path, Out) ->
                     In = Out ++ "/repl.in",
                     ok = file:write_file(
                            In, string:join(Lines ++ [":quit"], "\n") ++ "\n"),
                     {_, Output} = bs_test_support:run_cli_with_stdin_file_result(
                                     "--repl -o " ++ Out ++ " " ++ Path, In),
                     Output
             end).

%% Substrings exclude the banner, whose export list varies with the fixture.
said(Out, What) -> ?assertNotEqual(nomatch, string:find(Out, What)).
silent(Out, What) -> ?assertEqual(nomatch, string:find(Out, What)).

built() -> bs_test_support:built().

%%% --- Basics ---------------------------------------------------------------

a_call_returns_a_value_test() ->
    case built() of
        false -> ok;
        true  -> said(repl(["Squared({Kind = :'Repl.Order', Id = 1, Total = 5})"]), "25")
    end.

a_binding_is_readable_afterwards_test() ->
    case built() of
        false -> ok;
        true  ->
            %% Reading a name inside a record uses a separate resolution path.
            Out = repl(["var x = 7",
                        "Squared({Kind = :'Repl.Order', Id = 1, Total = x})"]),
            said(Out, "49")
    end.

%%% --- Values and declarations ----------------------------------------------

a_parenthesised_tuple_binds_and_echoes_test() ->
    case built() of
        false -> ok;
        true  ->
            Out = repl(["var y = (1, 2)", "y"]),
            said(Out, "(1, 2)"),
            silent(Out, "no /2")
    end.

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

%% F7 — keyword atoms resolve at the prompt.
the_keyword_atoms_resolve_at_the_prompt_test() ->
    case built() of
        false -> ok;
        true  ->
            Out = repl(["Flag(true)", "Flag(false)"]),
            said(Out, ":yes"),
            said(Out, ":no"),
            silent(Out, "not bound")
    end.

a_declaration_says_where_declarations_go_test() ->
    case built() of
        false -> ok;
        true  ->
            Out = repl(["record Thing { Id: int }"]),
            said(Out, ":reload")
    end.

%%% --- `=` matches ----------------------------------------------------------

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

a_destructuring_match_binds_every_name_test() ->
    case built() of
        false -> ok;
        true  ->
            Out = repl(["var p = (1, 2)", "var (a, b) = p", "Echo(b)"]),
            said(Out, "2"),
            silent(Out, "does not match")
    end.

%% F8.8 — the prompt uses the compiler's explicit name-match rule.
a_bound_name_must_be_marked_to_match_test() ->
    case built() of
        false -> ok;
        true  ->
            Ok = repl(["var p = (1, 2)", "var n = 1", "var (== n, b) = p"]),
            silent(Ok, "does not match"),
            %% A different value must fail, ruling out a catch-all match.
            No = repl(["var p = (1, 2)", "var m = 9", "var (== m, b) = p"]),
            said(No, "does not match")
    end.

a_bare_bound_name_is_a_rebinding_and_names_the_fix_test() ->
    case built() of
        false -> ok;
        true  ->
            Out = repl(["var p = (1, 2)", "var n = 1", "var (n, b) = p"]),
            said(Out, "already bound"),
            said(Out, "== n")
    end.

a_bare_binding_at_the_prompt_refuses_and_names_var_test() ->
    case built() of
        false -> ok;
        true  ->
            Out = repl(["x = 1"]),
            said(Out, "var x = ")
    end.

an_unbound_name_after_the_marker_says_so_test() ->
    case built() of
        false -> ok;
        true  -> said(repl(["var p = (1, 2)", "var (== nope, b) = p"]),
                      "not bound")
    end.

a_failed_match_names_the_whole_value_test() ->
    case built() of
        false -> ok;
        true  -> said(repl(["var p = (1, 2)", "(9, _) = p"]), "does not match (1, 2)")
    end.

%%% --- Diagnostics ----------------------------------------------------------

an_unbound_name_says_so_test() ->
    case built() of
        false -> ok;
        true  -> said(repl(["nope"]), "not bound")
    end.

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
            said(Out, "Flag/1"),
            %% F12 — the banner omits private functions.
            silent(Out, "Half/1")
    end.

%% The compiler-generated export is callable metadata, not a user function.
the_banner_hides_the_compilers_export_test() ->
    case built() of
        false -> ok;
        true  -> silent(repl([]), "bs@")
    end.

%%% --- F12 visibility -------------------------------------------------------

a_private_function_is_refused_by_name_at_the_prompt_test() ->
    case built() of
        false -> ok;
        true  ->
            Out = repl(["Half(4)"]),
            said(Out, "is private in"),
            silent(Out, "no Half/1")
    end.

%% An unknown name must remain distinct from a private function.
an_unknown_function_still_says_no_such_function_test() ->
    case built() of
        false -> ok;
        true  ->
            Out = repl(["Nope(4)"]),
            said(Out, "no Nope/1"),
            silent(Out, "is private in")
    end.

exports_and_reload_both_answer_test() ->
    case built() of
        false -> ok;
        true  ->
            Out = repl([":exports", ":reload"]),
            said(Out, "Squared/1"),
            %% The source is unchanged; only command recognition is asserted.
            silent(Out, "cannot read")
    end.
