%%% F15 — a module is a directory.
%%%
%%% Ticket 13 §3's aggregate rule, ticket 41 §4's `index.bs` and §5's
%%% classification and path check. Two of these scenarios are F11's, moved: F11.3
%%% became F15.5 and F11.13 became F15.6, both with their original wording, and
%%% they were moved because they are specified against a module that is a
%%% directory and F11 built the half where one file is one module.
%%%
%%% DRIVEN THROUGH THE CLI, like `modules_tests`, and for the same reason its
%%% header gives: a checker called with one parsed file cannot express the
%%% question. It is more literally true here — the unit under test is
%%% `bsc DIR`, and a directory is exactly what a caller of `bs_check` does not
%%% have.

-module(aggregate_tests).

-include_lib("eunit/include/eunit.hrl").

%% Files is [{"Name.bs", Source}]; each lands in the directory its own `module`
%% line implies, so `module Shop.Reports` goes to `<root>/Shop/Reports/`.
in_root(Files) ->
    Root = bs_test_support:fixture_root(),
    Paths = [bs_test_support:place(Root, N, S) || {N, S} <- Files],
    {Root, hd(Paths)}.

%% Compiles the module DIRECTORY, which is the whole point of the feature.
compile_dir(Files) ->
    {Root, Main} = in_root(Files),
    Dir = filename:dirname(Main),
    {Root, Dir, bs_test_support:run_cli("--src-root " ++ Root ++ " -o " ++ Root ++
                                            "/out " ++ Dir)}.

ok_rc(Out)  -> ?assert(string:find(Out, "rc:0") =/= nomatch).
bad_rc(Out) -> ?assert(string:find(Out, "rc:1") =/= nomatch).
has(Out, S) -> ?assert(string:find(Out, S) =/= nomatch).

%%% ---------------------------------------------------------------------------
%%% F15.1 / F15.3 — the aggregate itself
%%% ---------------------------------------------------------------------------

%% Ticket 13 §3: every `.bs` file in the directory compiles into the ONE `.beam`.
%% Asserting on the export list rather than on the file's existence, because a
%% beam missing half its module still exists — that is the failure this rule
%% creates if the aggregation is wrong, and it is invisible to `ls`.
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
    %% One beam, not three.
    ?assertEqual([], filelib:wildcard(Root ++ "/out/Total.beam")).

%% 41 §4 — `index.bs` is the DECLARATION file, so what it declares has to be in
%% scope for its siblings. This is the half of the rule that makes the other half
%% (no functions there) worth having.
a_record_declared_in_index_is_visible_to_a_sibling_test() ->
    {_, _, Out} = compile_dir([{"index.bs", "module Agg\n"
                                            "record Order { Id: int }\n"},
                               {"Read.bs", "module Agg\n"
                                           "public int Read(Order o)\n"
                                           "Read(o) -> o.Id\n"}]),
    ok_rc(Out).

%% A sibling with no `module` line inherits the directory's. Under one function
%% per file this is the common case, not a concession — and the two defaults in
%% the compiler used to disagree about it: `module_of/1` answered `undefined` and
%% dropped the file from the source index, while `module_name/1` answered `Main`
%% and emitted it under that name.
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

%% `examples/collections/` held exactly this shape until F15 — `Shop.Collections.List`
%% beside `Shop.Reports` in one directory. F11 shipped it because nothing said it
%% was wrong.
two_module_declarations_in_one_directory_are_refused_test() ->
    Root = bs_test_support:fixture_root(),
    Dir = Root ++ "/Two",
    ok = filelib:ensure_dir(Dir ++ "/x"),
    ok = file:write_file(Dir ++ "/a.bs", "module Two\npublic int One()\nOne() -> 1\n"),
    ok = file:write_file(Dir ++ "/b.bs", "module Other\npublic int Twice()\nTwice() -> 2\n"),
    Out = bs_test_support:run_cli("-o " ++ Root ++ "/out " ++ Dir),
    bad_rc(Out),
    has(Out, "one directory is one module"),
    %% Both files are named, because "which two?" is the first question.
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

%%% ---------------------------------------------------------------------------
%%% F15.5 / F15.7 — ticket 41 §5's path check (was F11.3)
%%% ---------------------------------------------------------------------------

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

%% THE SUFFIX CASE, AND IT IS THE REASON THE CHECK IS NOT A SUFFIX MATCH.
%%
%% "the declared path must be a suffix of the directory path" needs no source
%% root and looks like the frugal reading. It ACCEPTS this program, because
%% `Orders` is a suffix of `Shop/Orders` — and a module quietly dropping its
%% leading segments mints a different atom, which is the drift between 40 §1's
%% atom and the path on disk that §5 exists to stop. A rule that does not
%% discriminate the failure its ticket named is not a cheaper version of it.
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

%% The default root is the module directory's own PARENT, so a single-segment
%% module needs no flag at all. This is the property that makes the default safe:
%% it is never weaker than the explicit form.
a_single_segment_module_needs_no_src_root_test() ->
    Root = bs_test_support:fixture_root(),
    Path = bs_test_support:place(Root, "a.bs",
                                 "module Solo\npublic int One()\nOne() -> 1\n"),
    Out = bs_test_support:run_cli("-o " ++ Root ++ "/out " ++ filename:dirname(Path)),
    ok_rc(Out),
    ?assert(filelib:is_regular(Root ++ "/out/Solo.beam")).

%% ...and a multi-segment one fails LOUDLY until a root is named, rather than
%% being quietly accepted.
a_dotted_module_without_a_src_root_says_so_test() ->
    Root = bs_test_support:fixture_root(),
    Path = bs_test_support:place(Root, "a.bs",
                                 "module Deep.Down\npublic int One()\nOne() -> 1\n"),
    Out = bs_test_support:run_cli("-o " ++ Root ++ "/out " ++ filename:dirname(Path)),
    bad_rc(Out),
    has(Out, "does not match its directory"),
    has(Out, "--src-root").

%%% ---------------------------------------------------------------------------
%%% F15.6 — ticket 41 §4's `index.bs` check (was F11.13)
%%% ---------------------------------------------------------------------------

a_function_declared_in_index_is_refused_test() ->
    {_, _, Out} = compile_dir([{"index.bs", "module Idx\n"
                                            "public int Nope(int n)\n"
                                            "Nope(n) -> n\n"}]),
    bad_rc(Out),
    has(Out, "index.bs holds no functions"),
    has(Out, "Nope").

%% The error names `index.bs` itself, not the module's first file or its
%% directory. A raise site that knows its file has to say so.
the_index_error_names_index_bs_test() ->
    {_, _, Out} = compile_dir([{"index.bs", "module Idx\n"
                                            "public int Nope(int n)\n"
                                            "Nope(n) -> n\n"}]),
    has(Out, "index.bs:2").

%% F15.10 — `index.bs` is NOT mandatory. 41 §5's operative rule is that a
%% directory holding `.bs` files is a module; §4's "its presence is the module
%% marker" is a second, looser phrasing of the same idea. F15 builds §5's, which
%% is the one written as the test, and records the drift for the map rather than
%% settling it here.
a_module_without_an_index_is_accepted_test() ->
    {Root, _, Out} = compile_dir([{"Only.bs", "module Only\n"
                                              "public int One()\n"
                                              "One() -> 1\n"}]),
    ok_rc(Out),
    ?assert(filelib:is_regular(Root ++ "/out/Only.beam")).

%%% ---------------------------------------------------------------------------
%%% F15.8 / F15.11 — 41 §5's classification, which is per-directory and total
%%% ---------------------------------------------------------------------------

%% A directory holding only directories is a namespace: no atom, no beam,
%% nothing emitted. Naming one is a mistake with an exact name, so it gets one
%% rather than the general usage text.
a_namespace_emits_nothing_and_says_so_test() ->
    Root = bs_test_support:fixture_root(),
    bs_test_support:place(Root, "a.bs", "module Ns.Inner\npublic int One()\nOne() -> 1\n"),
    Out = bs_test_support:run_cli("--src-root " ++ Root ++ " -o " ++ Root ++
                                      "/out " ++ Root ++ "/Ns"),
    has(Out, "is a namespace, not a module"),
    %% and it points at what you probably meant
    has(Out, "Ns/Inner").

%% THE MIXED CASE, pinned rather than left to whatever falls out of a glob.
%%
%% 41 §5 glosses ticket 13 as having "made a directory inside a module a
%% source-only sub-module", which read literally would make this ONE aggregate.
%% 13's own measurement settles it the other way: its observed output is two
%% FILES in one beam and its `Order/` is the module directory, so 13's sub-module
%% is a file. "One `.beam` per aggregate" and "one `.beam` per directory" are the
%% same sentence, and §5's classification applies to each directory on its own.
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
    %% Two modules, two beams — and `Outer/Deep` between them is a namespace that
    %% emitted neither an atom nor a file.
    ?assert(filelib:is_regular(Root ++ "/out/Outer.beam")),
    ?assert(filelib:is_regular(Root ++ "/out/Outer.Deep.Inner.beam")),
    ?assertEqual([], filelib:wildcard(Root ++ "/out/Outer.Deep.beam")).

%%% ---------------------------------------------------------------------------
%%% F15.9 — ticket 13 §3's per-file attribution
%%% ---------------------------------------------------------------------------

%% The measured claim from prototype `13b`, reproduced by the compiler: two
%% functions in ONE beam reporting against TWO source files, with exact lines.
%%
%% This is what makes the aggregate rule survivable. Without it every crash in
%% every module names the directory, and one function per file — the whole
%% `write_scope` argument in 41 §4 — costs you the stack trace.
%%
%% The blank lines in `Apply.bs` are deliberate: the two clauses sit on different
%% line numbers, so a right answer cannot be two files that happen to look alike.
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

%% Where the B# frame says the crash happened. The innermost frame is `lists`
%% itself, so this takes the first frame belonging to the emitted module.
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

%% THE REASON THE CHECKER RUNS ITS FUNCTION PASS PER FILE.
%%
%% A diagnostic is `{error, Line, FnName, Descriptor}` — a name and no arity —
%% and ticket 40 §2 permits two arities of one name, which one function per file
%% then puts in two files. Any lookup keyed by name would point a human at the
%% wrong file with every check green. `examples/Shop/Collections/List/List.bs`
%% already has `Length/1` beside `Length/2`, so this is not hypothetical.
%%
%% Both files declare an inexhaustive function; each error must name its own.
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

%% ...AND THE SAME IS TRUE OF THE ERRORS THAT ARE RAISED RATHER THAN RETURNED.
%%
%% Found at the `ibs` prompt, not by the suite. A handful of conditions are
%% signalled by raising, below the level that carries a function name, and those
%% were reported against the module's FIRST file — which is `index.bs` whenever
%% there is one. A call to an unimported module in `Go.bs:6` came back as
%% `index.bs:6`, and `index.bs` was three lines long: a diagnostic pointing at a
%% line that does not exist in the file it names.
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

%% 41 §3 names both inputs: "a set of `.bs` files (as it already is) or a
%% directory to walk". Naming one file must not emit a beam missing the module's
%% other functions — a beam that loads, exports less than the module declares,
%% and fails at the call site.
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
