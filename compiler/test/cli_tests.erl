%%% Scenarios: compiler/features/F15-module-is-a-directory.md
%%% Scenarios: compiler/features/F47-diagnostic-json.md
-module(cli_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [project_root/0, escript/0, run_cli/1, with_src/3,
                          showcase_src/0, shop_src/0, an_order/0]).

-define(OUT, bs_test_support:run_root()).

%%% --- The built escript ---

escript_entry_point_exists_test() ->
    {ok, Terms} = file:consult(project_root() ++ "/rebar.config"),
    Args = proplists:get_value(escript_emu_args, Terms),
    ?assertNotEqual(undefined, Args),
    [_, "-escript", "main", ModStr | _] = string:lexemes(Args, " \n"),
    Mod = list_to_atom(ModStr),
    ?assertMatch({module, Mod}, code:ensure_loaded(Mod)),
    ?assert(erlang:function_exported(Mod, main, 1)).

%% Eunit builds the escript under the test profile, not the default profile.
built_escript_compiles_a_file_test() ->
    Escript = escript(),
    ?assert(filelib:is_regular(Escript)
            orelse throw({no_escript, Escript, "run `rebar3 escriptize` first"})),
    %% F15 — the fixture directory matches its declared module.
    Root = bs_test_support:fixture_root(),
    Src = bs_test_support:place(Root, "in.bs", showcase_src()),
    Out = Root ++ "/out",
    {Rc, _Output} = bs_test_support:run_cli_result(
                      "-o " ++ Out ++ " " ++ Src),
    ?assertEqual(0, Rc),
    ?assert(filelib:is_regular(Out ++ "/Readings.beam")).

%% An exit status is independent of text printed by the child.
a_cli_failure_keeps_exit_status_and_output_separate_test() ->
    {Rc, Output} = bs_test_support:run_cli_result("--definitely-not-a-flag"),
    ?assertEqual(2, Rc),
    ?assertNotEqual(nomatch, string:find(Output, "usage:")),
    %% A shell echo must not stand in for the child's exit status.
    ?assertEqual(nomatch, string:find(Output, "rc:")).

%% A conflicting dependency outside the source root must not enter the index.
a_previous_runs_fixture_cannot_enter_this_runs_source_index_test() ->
    Case = "eng229-isolation-" ++ os:getpid() ++ "-" ++
           integer_to_list(erlang:unique_integer([positive])),
    Root = filename:join(bs_test_support:run_root(), Case),
    Main = bs_test_support:place(
             Root, "main.bs",
             "module Eng229Main\n"
             "using Eng229Dep\n"
             "public int Go()\n"
             "Go() -> Value()\n"),
    _Dep = bs_test_support:place(
             Root, "dep.bs",
             "module Eng229Dep\n"
             "public int Value()\n"
             "Value() -> 1\n"),
    %% /tmp/bsc_eunit is the retired shared parent for test runs.
    %% A duplicate dependency there must stay outside this run's index.
    PoisonRoot = filename:join("/tmp/bsc_eunit", Case),
    _Poison = bs_test_support:place(
                PoisonRoot, "poison.bs",
                "module Eng229Dep\n"
                "public atom Value()\n"
                "Value() -> :stale\n"),
    try
        {Rc, Output} = bs_test_support:run_cli_result(
                         "--src-root " ++ Root ++ " -o " ++ Root ++ "/out " ++ Main),
        ?assertEqual({0, ""}, {Rc, Output})
    after
        ok = file:del_dir_r(PoisonRoot)
    end.

%% `bs@type_atoms` is a compiler export, not a runnable user function.
the_compilers_export_cannot_be_run_test() ->
    case bs_test_support:built() of
        false -> ok;
        true  ->
            with_src("modes.bs",
                     "module Modes\n"
                     "type Mode = :zzz_cli_mode_a | :zzz_cli_mode_b\n"
                     "public list<Mode> Known()\n"
                     "Known() -> []\n",
                     fun(Path, Out) ->
                             {Rc, Output} = bs_test_support:run_cli_result(
                                              "-o " ++ Out ++ " " ++ Path ++ " bs@type_atoms"),
                             ?assertNotEqual(0, Rc),
                             ?assertEqual(nomatch, string:find(Output, "zzz_cli_mode_a"))
                     end)
    end.

%%% --- Running a program ---

fib_src() ->
    "module Fib\n"
    "public int Fib(int n)\n"
    "Fib(n) when n <= 1 -> n\n"
    "Fib(n) when n > 1  -> Fib(n - 1) + Fib(n - 2)\n".

run_infers_the_function_from_the_file_name_test() ->
    case bs_test_support:built() of
        false -> ok;
        true ->
            with_src("fib.bs", fib_src(), fun(Path, Out) ->
                R = run_cli("-o " ++ Out ++ " " ++ Path ++ " 5"),
                ?assert(string:find(R, "rc:0") =/= nomatch),
                ?assertEqual("5", hd(string:lexemes(R, "\n")))
            end)
    end.

run_computes_rather_than_parrots_test() ->
    case bs_test_support:built() of
        false -> ok;
        true ->
            with_src("fib.bs", fib_src(), fun(Path, Out) ->
                R = run_cli("-o " ++ Out ++ " " ++ Path ++ " 10"),
                ?assertEqual("55", hd(string:lexemes(R, "\n")))
            end)
    end.

run_round_trips_beam_sharp_notation_test() ->
    case bs_test_support:built() of
        false -> ok;
        true ->
            with_src("readings.bs", showcase_src(), fun(Path, Out) ->
                R = run_cli("-o " ++ Out ++ " " ++ Path ++ " Classify \"(:ok, 7)\""),
                ?assertEqual(":positive", hd(string:lexemes(R, "\n")))
            end)
    end.

run_names_the_choice_when_it_cannot_infer_test() ->
    case bs_test_support:built() of
        false -> ok;
        true ->
            Src = showcase_src() ++
                  "\npublic Verdict Second(Reading r)\n"
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

%% Piped stdin cannot edit a file mid-session; drive the REPL reload path.
reload_picks_up_a_changed_file_test() ->
    Out = ?OUT ++ "/reload",
    ok = filelib:ensure_dir(Out ++ "/x"),
    Path = Out ++ "/Fib.bs",
    ok = file:write_file(Path, fib_src()),
    {ok, _} = bsc:file_to_dir(Path, Out),
    true = code:add_patha(Out),
    {module, 'Fib'} = code:ensure_loaded('Fib'),
    ?assertEqual(8, 'Fib':'Fib'(6)),
    Changed = "module Fib\npublic int Fib(int n)\nFib(n) when n <= 1 -> 100\n"
              "Fib(n) when n > 1  -> 100\n",
    ok = file:write_file(Path, Changed),
    {ok, _} = bsc:file_to_dir(Path, Out),
    code:purge('Fib'), code:delete('Fib'), code:purge('Fib'),
    {module, 'Fib'} = code:ensure_loaded('Fib'),
    ?assertEqual(100, 'Fib':'Fib'(6)).

%% The child PID checks isolation without racing concurrent runs.
%% `env` is needed because `exec VAR=x prog` treats `VAR=x` as a program.
a_scratch_directory_is_named_for_the_process_that_made_it_test() ->
    case bs_test_support:built() of
        false -> ok;
        true ->
            with_src("fib.bs", fib_src(), fun(Path, Root) ->
                Tmp = filename:join(Root, "scratch"),
                ok = filelib:ensure_dir(filename:join(Tmp, "x")),
                {Rc, Output, OsPid} = bs_process:run_merged_with_pid(
                    "env TMPDIR=" ++ Tmp ++ " " ++ bs_test_support:escript() ++
                    " -v " ++ Path ++ " 5"),
                ?assertEqual({0, "5"}, {Rc, lists:last(string:lexemes(Output, "\n"))}),
                Wrote = [string:prefix(L, "wrote ")
                         || L <- string:lexemes(Output, "\n"),
                            string:prefix(L, "wrote ") =/= nomatch],
                ?assertMatch([_ | _], Wrote),
                Scratch = filename:dirname(hd(Wrote)),
                ?assertEqual(Tmp, filename:dirname(Scratch)),
                Expected = "bsc-" ++ integer_to_list(OsPid) ++ "-",
                ?assertEqual(Expected,
                             string:slice(filename:basename(Scratch), 0, length(Expected)))
            end)
    end.

%%% --- The reader's diagnostics ---

an_unreadable_argument_says_what_it_could_not_read_test() ->
    {error, Msg} = bs_run:read_arg("Order{Id = 1, Total = 0}"),
    Flat = lists:flatten(Msg),
    ?assert(string:find(Flat, "Order{Id = 1, Total = 0}") =/= nomatch),
    ?assert(string:find(Flat, "record construction is not available") =/= nomatch).

a_call_in_an_argument_is_named_as_such_test() ->
    {error, Msg} = bs_run:read_arg("Pay(x)"),
    ?assert(string:find(lists:flatten(Msg), "arguments are values, not calls")
            =/= nomatch).

a_record_value_round_trips_through_the_reader_test() ->
    ?assertEqual({ok, an_order()},
                 bs_run:read_arg("{Kind = :'Shop.Order', Id = 1, Total = 0}")),
    ?assertEqual("{Kind = :'Shop.Order', Id = 1, Total = 0}",
                 lists:flatten(bs_run:format_value(an_order()))).

a_bound_name_resolves_inside_a_literal_test() ->
    Env = #{"t" => 9},
    ?assertEqual({ok, 9}, bs_run:read_arg("t", Env)),
    ?assertEqual({ok, #{'Kind' => 'Shop.Order', 'Total' => 9}},
                 bs_run:read_arg("{Kind = :'Shop.Order', Total = t}", Env)),
    ?assertEqual({ok, [1, 9]}, bs_run:read_arg("[1, t]", Env)),
    ?assertEqual({ok, {9, 2}}, bs_run:read_arg("(t, 2)", Env)).

an_empty_environment_changes_nothing_test() ->
    ?assertEqual(bs_run:read_arg("[1, 2]"), bs_run:read_arg("[1, 2]", #{})),
    ?assertEqual({ok, {ok, 5}}, bs_run:read_arg("(:ok, 5)", #{"t" => 9})).

%% Braces denote records; Erlang tuple syntax must not be accepted as a tuple.
a_brace_that_is_not_a_record_names_both_spellings_test() ->
    {error, Msg} = bs_run:read_arg("{ok,5}"),
    Flat = lists:flatten(Msg),
    ?assertNotEqual(nomatch, string:find(Flat, "(1, 2)")),
    ?assertNotEqual(nomatch, string:find(Flat, "Id = 1")),
    %% The equivalent tuple in beam-sharp notation remains valid.
    ?assertEqual({ok, {ok, 5}}, bs_run:read_arg("(:ok, 5)")),
    ?assertEqual({ok, [1, 2]}, bs_run:read_arg("[1, 2]")),
    %% Braces remain valid for records.
    ?assertEqual({ok, #{'Id' => 1, 'Total' => 500}},
                 bs_run:read_arg("{Id = 1, Total = 500}")).

the_cli_reports_an_unreadable_argument_test() ->
    case bs_test_support:built() of
        false -> ok;
        true ->
            with_src("shop.bs", shop_src(), fun(Path, Out) ->
                R = run_cli("-o " ++ Out ++ " " ++ Path ++ " Pay 'Order{Id = 1}'"),
                ?assert(string:find(R, "record construction is not available")
                        =/= nomatch),
                ?assertEqual(nomatch, string:find(R, "badmap"))
            end)
    end.

%%% --- Batch invocations ---

manifest(Entries) ->
    lists:append(
      [["entry ", Id, "\n",
        case Cwd of undefined -> ""; _ -> ["cwd ", Cwd, "\n"] end,
        [["arg ", A, "\n"] || A <- Args],
        "end\n\n"]
       || {Id, Cwd, Args} <- Entries]).

read_result(Dir, Id, Ext) ->
    {ok, Bin} = file:read_file(filename:join(Dir, Id ++ "." ++ Ext)),
    binary_to_list(Bin).

%% Separate runs capture split and merged streams for comparison.
%% These arguments contain no single quotes, so shell quoting is sufficient.
standalone(Args) ->
    Quoted = lists:flatten(lists:join(" ", ["'" ++ A ++ "'" || A <- Args])),
    {Rc, Out, Err} = bs_test_support:run_cli_split_result(Quoted),
    {Rc2, Merged} = bs_test_support:run_cli_result(Quoted),
    ?assertEqual(Rc, Rc2),
    #{status => Rc, stdout => Out, stderr => Err, output => Merged}.

inexhaustive_src() ->
    "module Bad\n"
    "type Colour = :red | :amber | :green\n"
    "public atom Go(Colour c)\n"
    "Go(:red)   -> :stop\n"
    "Go(:amber) -> :wait\n".

%% `place/3` writes list elements as bytes; encode the accent as UTF-8.
accented_src() ->
    "module Label\n"
    "public string Accented()\n"
    "Accented() -> \"h\303\251llo\"\n".

batch_runs_every_entry_in_one_vm_and_attributes_each_test_() ->
    {timeout, 120, fun batch_runs_every_entry_in_one_vm_and_attributes_each/0}.

batch_runs_every_entry_in_one_vm_and_attributes_each() ->
    Root = bs_test_support:fixture_root(),
    Good  = bs_test_support:place(Root, "good.bs", showcase_src()),
    Bad   = bs_test_support:place(Root, "bad.bs", inexhaustive_src()),
    Fib   = bs_test_support:place(Root, "fib.bs", fib_src()),
    Label = bs_test_support:place(Root, "label.bs", accented_src()),
    %% Reusing the module atom with different code detects stale loads.
    Root2 = bs_test_support:fixture_root(),
    Fib2  = bs_test_support:place(Root2, "fib.bs",
                                  "module Fib\npublic int Fib(int n)\n"
                                  "Fib(n) when n <= 1 -> 100\n"
                                  "Fib(n) when n > 1  -> 100\n"),
    Out = fun(N) -> filename:join(Root, "out" ++ integer_to_list(N)) end,
    Pwned = filename:join(Root, "pwned"),
    Entries =
        [{"good",   undefined, ["--src-root", Root, "-o", Out(1), Good]},
         {"bad",    undefined, ["--src-root", Root, "-o", Out(2), Bad]},
         {"term",   undefined, ["--diagnostics", "term", "--src-root", Root,
                                "-o", Out(3), Bad]},
         {"json",   undefined, ["--diagnostics", "json", "--src-root", Root,
                                "-o", Out(10), Bad]},
         {"run",    undefined, ["--src-root", Root, "-o", Out(4), Fib, "10"]},
         {"rerun",  undefined, ["--src-root", Root2, "-o", Out(5), Fib2, "10"]},
         {"rel",    Root,      ["-o", Out(6), "Bad/bad.bs"]},
         {"utf",    undefined, ["--src-root", Root, "-o", Out(7), Label, "Accented"]},
         {"inject", undefined, ["--src-root", Root, "-o", Out(8), Fib, "Fib",
                                "10; touch " ++ Pwned]},
         {"space",  undefined, ["--src-root", Root, "-o", Out(9), Good,
                                "Classify", "(:ok, 7)"]},
         {"repl",   undefined, ["--repl", Good]}],
    ManifestPath = filename:join(Root, "batch.manifest"),
    ok = file:write_file(ManifestPath, manifest(Entries)),
    Results = filename:join(Root, "results"),
    {Rc, BatchOutput} = bs_test_support:run_cli_result(
                          "--batch " ++ ManifestPath ++ " " ++ Results),
    ?assertEqual({0, ""}, {Rc, BatchOutput}),
    Compare =
        fun(Id, Args) ->
                Want = standalone(Args),
                Got = #{status => list_to_integer(
                                    string:trim(read_result(Results, Id, "status"))),
                        stdout => read_result(Results, Id, "stdout"),
                        stderr => read_result(Results, Id, "stderr"),
                        output => read_result(Results, Id, "output")},
                ?assertEqual({Id, Want}, {Id, Got})
        end,
    [Compare(Id, Args) || {Id, undefined, Args} <- Entries, Id =/= "repl"],
    %% These expectations also catch identical failures in both run modes.
    ?assertEqual("0", string:trim(read_result(Results, "good", "status"))),
    ?assertEqual("1", string:trim(read_result(Results, "bad", "status"))),
    ?assertNotEqual(nomatch, string:find(read_result(Results, "bad", "stderr"),
                                         "Go is not exhaustive")),
    TermOut = read_result(Results, "term", "stdout"),
    TermErr = read_result(Results, "term", "stderr"),
    ?assertNotEqual(nomatch, string:find(TermOut, "tag => inexhaustive")),
    ?assertEqual(nomatch, string:find(TermErr, "tag =>")),
    ?assertEqual(TermOut ++ TermErr, read_result(Results, "term", "output")),
    %% F47.9 — batch JSON matches standalone output on each stream.
    JsonOut = read_result(Results, "json", "stdout"),
    JsonErr = read_result(Results, "json", "stderr"),
    ?assertNotEqual(nomatch, string:find(JsonOut, "\"tag\":\"inexhaustive\"")),
    ?assertEqual(nomatch, string:find(JsonErr, "\"tag\"")),
    ?assertEqual(JsonOut ++ JsonErr, read_result(Results, "json", "output")),
    ?assertEqual("55\n", read_result(Results, "run", "stdout")),
    ?assertEqual("100\n", read_result(Results, "rerun", "stdout")),
    %% The result is read as bytes, so the expected accent is UTF-8.
    ?assertEqual("\"h\303\251llo\"\n", read_result(Results, "utf", "stdout")),
    ?assertEqual(":positive\n", read_result(Results, "space", "stdout")),
    ?assertEqual("2", string:trim(read_result(Results, "inject", "status"))),
    ?assertNot(filelib:is_file(Pwned)),
    %% Resolve against the entry's cwd and retain its relative path in errors.
    ?assertEqual("1", string:trim(read_result(Results, "rel", "status"))),
    %% Match the entry's relative path and line without pinning the column.
    ?assertNotEqual(nomatch, string:find(read_result(Results, "rel", "stderr"),
                                         "Bad/bad.bs:3:")),
    %% A batch entry must refuse --repl rather than silently ignore it.
    ?assertEqual("2", string:trim(read_result(Results, "repl", "status"))),
    ?assertNotEqual(nomatch, string:find(read_result(Results, "repl", "stderr"),
                                         "--repl is not available in a batch")).

%% A valid first entry must not run when a later entry is malformed.
a_malformed_manifest_runs_nothing_and_names_the_line_test() ->
    Root = bs_test_support:fixture_root(),
    Good = bs_test_support:place(Root, "good.bs", showcase_src()),
    ManifestPath = filename:join(Root, "bad.manifest"),
    ok = file:write_file(ManifestPath,
                         "entry one\narg " ++ Good ++ "\nend\n"
                         "entry two\nargh " ++ Good ++ "\nend\n"),
    Results = filename:join(Root, "results"),
    {Rc, Output} = bs_test_support:run_cli_result(
                     "--batch " ++ ManifestPath ++ " " ++ Results),
    ?assertEqual(2, Rc),
    ?assertNotEqual(nomatch, string:find(Output, "bad.manifest:5")),
    ?assertEqual({error, enoent},
                 file:read_file(filename:join(Results, "one.status"))),
    %% Extra flags must not turn the batch invocation into a compile.
    {Rc2, Output2} = bs_test_support:run_cli_result(
                       "-o " ++ Root ++ " --batch " ++ ManifestPath ++ " " ++ Results),
    ?assertEqual(2, Rc2),
    ?assertNotEqual(nomatch, string:find(Output2, "--batch")),
    {Rc3, _} = bs_test_support:run_cli_result("--batch " ++ ManifestPath),
    ?assertEqual(2, Rc3).

%% Compilation runs in-process, so the prefix names compile, never erlc.
the_erlang_compilers_warning_reaches_stderr_under_an_honest_prefix_test() ->
    Root = bs_test_support:fixture_root(),
    %% An unused private function triggers an Erlang compiler warning.
    Src = bs_test_support:place(Root, "half.bs",
                                "module Half\n"
                                "public int Whole(int n)\n"
                                "Whole(n) -> n\n"
                                "int Half(int n)\n"
                                "Half(n) -> n\n"),
    {Rc, Out, Err} = bs_test_support:run_cli_split_result(
                       "--src-root " ++ Root ++ " -o " ++ Root ++ "/out " ++ Src),
    ?assertEqual({0, ""}, {Rc, Out}),
    ?assertNotEqual(nomatch, string:find(Err, "compile: ")),
    ?assertEqual(nomatch, string:find(Err, "erlc")),
    ?assertNotEqual(nomatch, string:find(Err, "is unused")).
