%%% Scenarios: compiler/features/F15-module-is-a-directory.md
%%% F15 — a module is a directory.
%%% The CLI accepts a directory; a checker given one parsed file cannot test it.

-module(aggregate_tests).

-include_lib("eunit/include/eunit.hrl").

%% Each source lands in the directory its module implies:
%% `module Shop.Reports` goes to `<root>/Shop/Reports/`.
in_root(Files) ->
    Root = bs_test_support:fixture_root(),
    Paths = [bs_test_support:place(Root, N, S) || {N, S} <- Files],
    {Root, hd(Paths)}.

compile_dir(Files) ->
    {Root, Main} = in_root(Files),
    Dir = filename:dirname(Main),
    {Root, Dir, bs_test_support:run_cli("--src-root " ++ Root ++ " -o " ++ Root ++
                                            "/out " ++ Dir)}.

ok_rc(Out)  -> ?assert(string:find(Out, "rc:0") =/= nomatch).
bad_rc(Out) -> ?assert(string:find(Out, "rc:1") =/= nomatch).
has(Out, S) -> ?assert(string:find(Out, S) =/= nomatch).

%%% ---------------------------------------------------------------------------
%%% F15.1, F15.3 — sibling files compile into one module.
%%% ---------------------------------------------------------------------------

%% A beam can exist with missing functions; exports reveal incomplete assembly.
two_files_in_one_directory_become_one_beam_test() ->
    {Root, _, Out} = compile_dir([{"index.bs", "module Agg\n"},
                                  {"Total.bs", "module Agg\n"
                                               "public int Total(int n)\n"
                                               "Total(n) -> n + 1\n"},
                                  {"Apply.bs", "module Agg\n"
                                               "public int Apply(int n)\n"
                                               "Apply(n) -> n + 2\n"}]),
    ok_rc(Out),
    Beam = Root ++ "/out/Agg.beam",
    ?assert(filelib:is_regular(Beam)),
    ?assert(lists:member('Apply', exports(Beam))),
    ?assert(lists:member('Total', exports(Beam))),
    %% Aggregation must not also emit a beam for the individual file.
    ?assertEqual([], filelib:wildcard(Root ++ "/out/Total.beam")).

a_record_declared_in_index_is_visible_to_a_sibling_test() ->
    {_, _, Out} = compile_dir([{"index.bs", "module Agg\n"
                                            "record Order { Id: int }\n"},
                               {"Read.bs", "module Agg\n"
                                           "public int Read(Order o)\n"
                                           "Read(o) -> o.Id\n"}]),
    ok_rc(Out).

a_file_with_no_module_line_inherits_the_directorys_test() ->
    {Root, _, Out} = compile_dir([{"index.bs", "module Agg\n"},
                                  {"Total.bs", "public int Total(int n)\n"
                                               "Total(n) -> n + 1\n"}]),
    ok_rc(Out),
    ?assert(filelib:is_regular(Root ++ "/out/Agg.beam")),
    ?assertEqual([], filelib:wildcard(Root ++ "/out/Main.beam")).

%%% ---------------------------------------------------------------------------
%%% F15.4 — one directory is one module
%%% ---------------------------------------------------------------------------

two_module_declarations_in_one_directory_are_refused_test() ->
    Root = bs_test_support:fixture_root(),
    Dir = Root ++ "/Two",
    ok = filelib:ensure_dir(Dir ++ "/x"),
    ok = file:write_file(Dir ++ "/a.bs", "module Two\npublic int One()\nOne() -> 1\n"),
    ok = file:write_file(Dir ++ "/b.bs", "module Other\npublic int Twice()\nTwice() -> 2\n"),
    Out = bs_test_support:run_cli("-o " ++ Root ++ "/out " ++ Dir),
    bad_rc(Out),
    has(Out, "one directory is one module"),
    has(Out, "a.bs"),
    has(Out, "b.bs").

a_directory_of_bs_files_with_no_module_line_at_all_is_refused_test() ->
    Root = bs_test_support:fixture_root(),
    Dir = Root ++ "/None",
    ok = filelib:ensure_dir(Dir ++ "/x"),
    ok = file:write_file(Dir ++ "/a.bs", "public int One()\nOne() -> 1\n"),
    Out = bs_test_support:run_cli("-o " ++ Root ++ "/out " ++ Dir),
    bad_rc(Out),
    has(Out, "no `module` line").

%%% F15.5, F15.7 — declarations match their directory paths.

a_declaration_that_does_not_match_its_directory_is_refused_test() ->
    Root = bs_test_support:fixture_root(),
    Dir = Root ++ "/Shop/Orders",
    ok = filelib:ensure_dir(Dir ++ "/x"),
    ok = file:write_file(Dir ++ "/Total.bs",
                         "module Shop.Billing\npublic int One()\nOne() -> 1\n"),
    Out = bs_test_support:run_cli("--src-root " ++ Root ++ " -o " ++ Root ++
                                      "/out " ++ Dir),
    bad_rc(Out),
    has(Out, "does not match its directory"),
    has(Out, "module Shop.Orders").

%% Orders is a suffix of Shop/Orders, but names a different module.
a_module_dropping_its_leading_segments_is_refused_test() ->
    Root = bs_test_support:fixture_root(),
    Dir = Root ++ "/Shop/Orders",
    ok = filelib:ensure_dir(Dir ++ "/x"),
    ok = file:write_file(Dir ++ "/Total.bs",
                         "module Orders\npublic int One()\nOne() -> 1\n"),
    Out = bs_test_support:run_cli("--src-root " ++ Root ++ " -o " ++ Root ++
                                      "/out " ++ Dir),
    bad_rc(Out),
    has(Out, "does not match its directory").

%% The default source root is the module directory's parent.
a_single_segment_module_needs_no_src_root_test() ->
    Root = bs_test_support:fixture_root(),
    Path = bs_test_support:place(Root, "a.bs",
                                 "module Solo\npublic int One()\nOne() -> 1\n"),
    Out = bs_test_support:run_cli("-o " ++ Root ++ "/out " ++ filename:dirname(Path)),
    ok_rc(Out),
    ?assert(filelib:is_regular(Root ++ "/out/Solo.beam")).

a_dotted_module_without_a_src_root_says_so_test() ->
    Root = bs_test_support:fixture_root(),
    Path = bs_test_support:place(Root, "a.bs",
                                 "module Deep.Down\npublic int One()\nOne() -> 1\n"),
    Out = bs_test_support:run_cli("-o " ++ Root ++ "/out " ++ filename:dirname(Path)),
    bad_rc(Out),
    has(Out, "does not match its directory"),
    has(Out, "--src-root").

%%% F15.6 — index.bs holds no functions.

a_function_declared_in_index_is_refused_test() ->
    {_, _, Out} = compile_dir([{"index.bs", "module Idx\n"
                                            "public int Nope(int n)\n"
                                            "Nope(n) -> n\n"}]),
    bad_rc(Out),
    has(Out, "index.bs holds no functions"),
    has(Out, "Nope").

the_index_error_names_index_bs_test() ->
    {_, _, Out} = compile_dir([{"index.bs", "module Idx\n"
                                            "public int Nope(int n)\n"
                                            "Nope(n) -> n\n"}]),
    has(Out, "index.bs:2").

%%% F15.10 — a module needs no index.bs.
a_module_without_an_index_is_accepted_test() ->
    {Root, _, Out} = compile_dir([{"Only.bs", "module Only\n"
                                              "public int One()\n"
                                              "One() -> 1\n"}]),
    ok_rc(Out),
    ?assert(filelib:is_regular(Root ++ "/out/Only.beam")).

%%% F15.8, F15.11 — each directory is a module or a namespace.

a_namespace_emits_nothing_and_says_so_test() ->
    Root = bs_test_support:fixture_root(),
    bs_test_support:place(Root, "a.bs", "module Ns.Inner\npublic int One()\nOne() -> 1\n"),
    Out = bs_test_support:run_cli("--src-root " ++ Root ++ " -o " ++ Root ++
                                      "/out " ++ Root ++ "/Ns"),
    has(Out, "is a namespace, not a module"),
    has(Out, "Ns/Inner").

%% A nested module compiles separately from its parent module.
a_module_directory_may_hold_another_module_test() ->
    Root = bs_test_support:fixture_root(),
    bs_test_support:place(Root, "outer.bs", "module Outer\npublic int One()\nOne() -> 1\n"),
    bs_test_support:place(Root, "inner.bs",
                          "module Outer.Deep.Inner\npublic int Two()\nTwo() -> 2\n"),
    Out1 = bs_test_support:run_cli("--src-root " ++ Root ++ " -o " ++ Root ++
                                       "/out " ++ Root ++ "/Outer"),
    ok_rc(Out1),
    Out2 = bs_test_support:run_cli("--src-root " ++ Root ++ " -o " ++ Root ++
                                       "/out " ++ Root ++ "/Outer/Deep/Inner"),
    ok_rc(Out2),
    %% Outer/Deep is an intervening namespace, so it emits no beam.
    ?assert(filelib:is_regular(Root ++ "/out/Outer.beam")),
    ?assert(filelib:is_regular(Root ++ "/out/Outer.Deep.Inner.beam")),
    ?assertEqual([], filelib:wildcard(Root ++ "/out/Outer.Deep.beam")).

%%% F15.9 — crashes identify the source file.

%% Blank lines give the clauses distinct line numbers as well as file names.
a_crash_names_the_file_the_clause_is_in_test() ->
    {Root, Dir, Out} =
        compile_dir([{"index.bs", "module Crash\n"
                                  "using :lists {\n"
                                  "    int nth(int n, list<int> xs)\n"
                                  "}\n"},
                     {"Total.bs", "module Crash\n"
                                  "\n"
                                  "public int Total(list<int> xs)\n"
                                  "Total(xs) -> :lists.nth(9, xs) + 1\n"},
                     {"Apply.bs", "module Crash\n"
                                  "\n\n\n\n"
                                  "public int Apply(list<int> xs)\n"
                                  "Apply(xs) -> :lists.nth(9, xs) + 2\n"}]),
    ok_rc(Out),
    true = code:add_patha(Root ++ "/out"),
    code:purge('Crash'),
    {module, 'Crash'} = code:load_abs(Root ++ "/out/Crash"),
    ?assertEqual({Dir ++ "/Total.bs", 4}, crash_site('Total')),
    ?assertEqual({Dir ++ "/Apply.bs", 7}, crash_site('Apply')).

%% The innermost frame belongs to lists; select the emitted module frame.
crash_site(Fn) ->
    try
        'Crash':Fn([1]),
        no_crash
    catch
        _:_:Stack ->
            [{_, _, _, Info} | _] = [F || F = {M, _, _, _} <- Stack, M =:= 'Crash'],
            {proplists:get_value(file, Info), proplists:get_value(line, Info)}
    end.

%%% ---------------------------------------------------------------------------
%%% F15.12 — a diagnostic names the file its clause is in
%%% ---------------------------------------------------------------------------

%% The diagnostic carries a name without arity; name-only lookup would
%% conflate these two files.
a_diagnostic_names_its_own_file_under_arity_overloading_test() ->
    {_, Dir, Out} = compile_dir([{"index.bs", "module Over\n"},
                                 {"One.bs", "module Over\n"
                                            "public int Length(int n)\n"
                                            "Length(1) -> 1\n"},
                                 {"Two.bs", "module Over\n"
                                            "\n\n"
                                            "public int Length(int n, int m)\n"
                                            "Length(1, 1) -> 1\n"}]),
    bad_rc(Out),
    has(Out, Dir ++ "/One.bs:2"),
    has(Out, Dir ++ "/Two.bs:4").

%% The raised error must identify Go.bs even with index.bs present.
a_raised_error_names_its_own_file_too_test() ->
    {_, Dir, Out} = compile_dir([{"index.bs", "module M\n"},
                                 {"Go.bs", "module M\n"
                                           "\n\n\n"
                                           "public int Go(int n)\n"
                                           "Go(n) -> Nope.Thing(n)\n"}]),
    bad_rc(Out),
    has(Out, Dir ++ "/Go.bs:6"),
    ?assertEqual(nomatch, string:find(Out, "index.bs:")).

%%% ---------------------------------------------------------------------------
%%% F15.2 — naming a file means the same as naming its directory
%%% ---------------------------------------------------------------------------

naming_one_file_compiles_the_whole_module_test() ->
    {Root, Main} = in_root([{"index.bs", "module Whole\n"},
                            {"A.bs", "module Whole\npublic int A()\nA() -> 1\n"},
                            {"B.bs", "module Whole\npublic int B()\nB() -> 2\n"}]),
    Out = bs_test_support:run_cli("--src-root " ++ Root ++ " -o " ++ Root ++
                                      "/out " ++ Main),
    ok_rc(Out),
    Exports = exports(Root ++ "/out/Whole.beam"),
    ?assert(lists:member('A', Exports)),
    ?assert(lists:member('B', Exports)).

%%% ---------------------------------------------------------------------------
%%% Helpers
%%% ---------------------------------------------------------------------------

exports(Beam) ->
    {ok, {_Mod, [{exports, Es}]}} = beam_lib:chunks(Beam, [exports]),
    [N || {N, _A} <- Es].
