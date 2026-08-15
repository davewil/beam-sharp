-module(cli_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [project_root/0, escript/0, run_cli/1, with_src/3,
                          showcase_src/0, shop_src/0, an_order/0]).

-define(OUT, "/tmp/bsc_eunit").

%%% ---------------------------------------------------------------------------
%%% The built escript
%%%
%%% `escript_emu_args` named a module that does not exist (`bsc_cli`), so the
%%% README's documented quickstart died with `undefined function bsc_cli:main/1`
%%% while every test above passed — because none of them executed the artefact
%%% users are told to run. Found by a teammate building the OTP corpus, who had
%%% to route around it.
%%%
%%% Two tests: one that reads the config and needs no build, so it fails wherever
%%% it is run; one that executes the escript when it has been built.
%%% ---------------------------------------------------------------------------

escript_entry_point_exists_test() ->
    {ok, Terms} = file:consult(project_root() ++ "/rebar.config"),
    Args = proplists:get_value(escript_emu_args, Terms),
    ?assertNotEqual(undefined, Args),
    %% "%%! -escript main bsc\n" -> bsc
    [_, "-escript", "main", ModStr | _] = string:lexemes(Args, " \n"),
    Mod = list_to_atom(ModStr),
    ?assertMatch({module, Mod}, code:ensure_loaded(Mod)),
    ?assert(erlang:function_exported(Mod, main, 1)).

%% THE SILENT SKIP THIS USED TO HAVE IS WHY IT NEVER RAN IN CI.
%%
%% It guarded itself with `is_regular/1` and returned `ok` when the escript was
%% absent — and CI ran `rebar3 eunit` BEFORE `rebar3 escriptize`, so the artefact
%% was always absent and this test passed without ever executing anything. A test
%% written because the documented quickstart was broken had itself been green and
%% empty since the day it was written.
%%
%% The workflow now builds the escript first, so the guard is removed rather than
%% kept: a missing escript is a real failure with a message that says what to run.
%% This repo's own rule, from the spec-check harness — a clean run proves nothing
%% unless the broken case would fail it.
built_escript_compiles_a_file_test() ->
    Escript = project_root() ++ "/_build/default/bin/bsc",
    ?assert(filelib:is_regular(Escript)
            orelse throw({no_escript, Escript, "run `rebar3 escriptize` first"})),
    Out = ?OUT ++ "/escript",
    ok = filelib:ensure_dir(Out ++ "/x"),
    Src = Out ++ "/in.bs",
    ok = file:write_file(Src, showcase_src()),
    Result = os:cmd(Escript ++ " -o " ++ Out ++ " " ++ Src ++ " 2>&1; echo rc:$?"),
    ?assert(string:find(Result, "rc:0") =/= nomatch),
    ?assert(filelib:is_regular(Out ++ "/Readings.beam")).

%%% ---------------------------------------------------------------------------
%%% Running a program — `bsc fib.bs 5`
%%%
%%% Development is driven by runnable code (David, 2026-08-14), so these assert
%%% on what the CLI prints, not on internals.
%%% ---------------------------------------------------------------------------

fib_src() ->
    "module Fib\n"
    "int Fib(int n)\n"
    "Fib(n) when n <= 1 -> n\n"
    "Fib(n) when n > 1  -> Fib(n - 1) + Fib(n - 2)\n".


%% The rule that makes `bsc fib.bs 5` need no function name: under one function
%% per file, the file names the function.
run_infers_the_function_from_the_file_name_test() ->
    case filelib:is_regular(escript()) of
        false -> ok;
        true ->
            with_src("fib.bs", fib_src(), fun(Path, Out) ->
                R = run_cli("-o " ++ Out ++ " " ++ Path ++ " 5"),
                ?assert(string:find(R, "rc:0") =/= nomatch),
                ?assertEqual("5", hd(string:lexemes(R, "\n")))
            end)
    end.

run_computes_rather_than_parrots_test() ->
    case filelib:is_regular(escript()) of
        false -> ok;
        true ->
            with_src("fib.bs", fib_src(), fun(Path, Out) ->
                R = run_cli("-o " ++ Out ++ " " ++ Path ++ " 10"),
                ?assertEqual("55", hd(string:lexemes(R, "\n")))
            end)
    end.

%% Results print in beam-sharp notation, and the argument parser accepts back
%% exactly what the printer emits — `(:ok, 7)`, not `{ok,7}`.
run_round_trips_beam_sharp_notation_test() ->
    case filelib:is_regular(escript()) of
        false -> ok;
        true ->
            with_src("readings.bs", showcase_src(), fun(Path, Out) ->
                R = run_cli("-o " ++ Out ++ " " ++ Path ++ " Classify \"(:ok, 7)\""),
                ?assertEqual(":positive", hd(string:lexemes(R, "\n")))
            end)
    end.

%% A file with several functions cannot infer one, and says so rather than
%% guessing.
run_names_the_choice_when_it_cannot_infer_test() ->
    case filelib:is_regular(escript()) of
        false -> ok;
        true ->
            Src = showcase_src() ++
                  "\nVerdict Second(Reading r)\n"
                  "Second((:ok, n)) when n > 0 -> :positive\n"
                  "Second((:ok, 0))            -> :zero\n"
                  "Second((:ok, n))            -> :negative\n"
                  "Second((:error, e))         -> :unknown\n",
            with_src("many.bs", Src, fun(Path, Out) ->
                R = run_cli("-o " ++ Out ++ " " ++ Path ++ " 5"),
                ?assert(string:find(R, "rc:2") =/= nomatch),
                ?assert(string:find(R, "which function") =/= nomatch)
            end)
    end.

%% What `:reload` does, asserted where it can be: a piped stdin cannot edit a
%% file mid-session, so this drives the same recompile-purge-load path the REPL
%% command drives and checks the NEW source is what answers.
reload_picks_up_a_changed_file_test() ->
    Out = ?OUT ++ "/reload",
    ok = filelib:ensure_dir(Out ++ "/x"),
    Path = Out ++ "/Fib.bs",
    ok = file:write_file(Path, fib_src()),
    {ok, _} = bsc:file_to_dir(Path, Out),
    true = code:add_patha(Out),
    {module, 'Fib'} = code:ensure_loaded('Fib'),
    ?assertEqual(8, 'Fib':'Fib'(6)),
    Changed = "module Fib\nint Fib(int n)\nFib(n) when n <= 1 -> 100\n"
              "Fib(n) when n > 1  -> 100\n",
    ok = file:write_file(Path, Changed),
    {ok, _} = bsc:file_to_dir(Path, Out),
    code:purge('Fib'), code:delete('Fib'), code:purge('Fib'),
    {module, 'Fib'} = code:ensure_loaded('Fib'),
    ?assertEqual(100, 'Fib':'Fib'(6)).

%%% ---------------------------------------------------------------------------
%%% The reader's diagnostics.
%%%
%%% Every case below is one David actually typed at the prompt on 2026-08-14.
%%% The reader used to answer all of them with `expected a call, e.g. Fib(5)` or,
%%% worse, by silently turning the text into a BINARY and letting it crash inside
%%% the function — `{badmap, <<"Order{Id = 1}">>}`, which shows a person their own
%%% source inside an error about a map. Ticket 23's rule is that the compiler
%%% hands you the thing to write, and the prompt is where that matters most.
%%% ---------------------------------------------------------------------------

%% Construction is not available in an argument: arguments are values.
an_unreadable_argument_says_what_it_could_not_read_test() ->
    {error, Msg} = bs_run:read_arg("Order{Id = 1, Total = 0}"),
    Flat = lists:flatten(Msg),
    ?assert(string:find(Flat, "Order{Id = 1, Total = 0}") =/= nomatch),
    ?assert(string:find(Flat, "record construction is not available") =/= nomatch).

%% ...and neither is a nested call.
a_call_in_an_argument_is_named_as_such_test() ->
    {error, Msg} = bs_run:read_arg("Pay(x)"),
    ?assert(string:find(lists:flatten(Msg), "arguments are values, not calls")
            =/= nomatch).

%% The record value itself still reads, and reads back to what the printer emits.
a_record_value_round_trips_through_the_reader_test() ->
    ?assertEqual({ok, an_order()},
                 bs_run:read_arg("{Kind = :'Shop.Order', Id = 1, Total = 0}")),
    ?assertEqual("{Kind = :'Shop.Order', Id = 1, Total = 0}",
                 lists:flatten(bs_run:format_value(an_order()))).

%% A name the REPL has bound resolves at any DEPTH, not only as a whole
%% argument. Without this the inner `t` fell through to the Erlang reader and
%% came back as the atom `t`, failing arithmetic three frames later — the same
%% silent-wrong-value shape as the binary fallback.
a_bound_name_resolves_inside_a_literal_test() ->
    Env = #{"t" => 9},
    ?assertEqual({ok, 9}, bs_run:read_arg("t", Env)),
    ?assertEqual({ok, #{'Kind' => 'Shop.Order', 'Total' => 9}},
                 bs_run:read_arg("{Kind = :'Shop.Order', Total = t}", Env)),
    ?assertEqual({ok, [1, 9]}, bs_run:read_arg("[1, t]", Env)),
    ?assertEqual({ok, {9, 2}}, bs_run:read_arg("(t, 2)", Env)).

%% ...and an empty environment behaves exactly as before, which is what makes
%% the change additive and leaves the CLI untouched.
an_empty_environment_changes_nothing_test() ->
    ?assertEqual(bs_run:read_arg("[1, 2]"), bs_run:read_arg("[1, 2]", #{})),
    ?assertEqual({ok, {ok, 5}}, bs_run:read_arg("(:ok, 5)", #{"t" => 9})).

%% SUPERSEDES `an_erlang_term_is_still_readable_test`, which asserted
%% `read_arg("{ok,5}")` was an Erlang tuple and justified it as *"the fallback
%% that was removed was the SILENT one, not this"*.
%%
%% It was silent too, about a different thing. `{}` is not a second spelling for
%% a tuple in beam-sharp — it is **taken**, meaning a record or a map type — so
%% `{1, 2}` was malformed record syntax being quietly reinterpreted, and then
%% echoed back as `(1, 2)` because the printer prints beam-sharp. David found it
%% at the prompt on 2026-08-15 and ruled: *"If () for tuples to match C# is
%% doable that is preferable."*
%%
%% It is doable and was already done — `(int, int)`, `Swap((a, b))` and
%% `(:ok, n)` all compile, run, and lower to `{tuple, L, …}` abstract-format
%% terms. There was never a fight with the Erlang compiler to have, because
%% ticket 13 emits terms rather than Erlang source text.
%%
%% The test is rewritten rather than deleted so the reversal is on the record.
a_brace_that_is_not_a_record_names_both_spellings_test() ->
    {error, Msg} = bs_run:read_arg("{ok,5}"),
    Flat = lists:flatten(Msg),
    ?assertNotEqual(nomatch, string:find(Flat, "(1, 2)")),
    ?assertNotEqual(nomatch, string:find(Flat, "Id = 1")),
    %% The beam-sharp spelling of the same value reads, so the reader accepts
    %% what `format_value/1` prints — which is the property that was broken.
    ?assertEqual({ok, {ok, 5}}, bs_run:read_arg("(:ok, 5)")),
    ?assertEqual({ok, [1, 2]}, bs_run:read_arg("[1, 2]")),
    %% A record still reads, which is what braces are FOR.
    ?assertEqual({ok, #{'Id' => 1, 'Total' => 500}},
                 bs_run:read_arg("{Id = 1, Total = 500}")).

%% The CLI reports it rather than crashing inside the function.
the_cli_reports_an_unreadable_argument_test() ->
    case filelib:is_regular(escript()) of
        false -> ok;
        true ->
            with_src("shop.bs", shop_src(), fun(Path, Out) ->
                R = run_cli("-o " ++ Out ++ " " ++ Path ++ " Pay 'Order{Id = 1}'"),
                ?assert(string:find(R, "record construction is not available")
                        =/= nomatch),
                ?assertEqual(nomatch, string:find(R, "badmap"))
            end)
    end.

