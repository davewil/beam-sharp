%%% Scenarios: compiler/features/F17-compiler-query-mode.md
%%% Scenarios: compiler/features/F50-to-json.md
-module(api_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [project_root/0, place/3]).

%%% F17 — the CLI answers module API queries.
%%% Keep streams separate: answers go to stdout, explanatory prose to stderr.

escript() ->
    E = bs_test_support:escript(),
    case filelib:is_regular(E) of
        true  -> E;
        false -> throw({no_escript, E, "run `rebar3 escriptize` first"})
    end.

%% Unique directories isolate fixtures across tests and VMs.
root() ->
    D = project_root() ++ "/_build/test/api_fixtures/fx-" ++ os:getpid() ++
        "-" ++ integer_to_list(erlang:unique_integer([positive])),
    ok = filelib:ensure_dir(D ++ "/x"),
    D.

run(Args) ->
    _ = escript(),
    bs_test_support:run_cli_split_result(Args).

lines(S) -> [L || L <- string:split(string:trim(S), "\n", all), L =/= ""].

%% Parse each line independently to check the framing seen by consumers.
terms(S) ->
    [begin
         {ok, Toks, _} = erl_scan:string(L ++ "."),
         {ok, Term} = erl_parse:parse_term(Toks),
         Term
     end || L <- lines(S)].

examples() -> project_root() ++ "/examples".

%%% F17.1 — a real example exposes its public API.

the_api_of_a_real_example_test() ->
    {Rc, Out, _} = run("--api " ++ examples() ++ "/Counter"),
    ?assertEqual(0, Rc),
    ?assertEqual(["module Counter",
                  "behaviour GenServer",
                  "(:reply, int, int) HandleCall(:get | (:add, int), term, int)",
                  "(:noreply, int) HandleCast(:reset | (:add, int), int)",
                  "(:ok, int) Init(int)"],
                 lines(Out)).

the_operations_are_sorted_by_name_and_arity_test() ->
    {0, Out, _} = run("--diagnostics term --api " ++ examples() ++ "/Shop"),
    [_Module | Ops] = terms(Out),
    Keys = [{N, A} || #{tag := operation, name := N, arity := A} <- Ops],
    ?assert(length(Keys) >= 5),
    ?assertEqual(lists:sort(Keys), Keys).

%%% F17.2 — private functions are absent from the API.

private_src() ->
    "module Guarded\n"
    "public int Open(int n)\n"
    "Open(n) -> Hidden(n)\n"
    "int Hidden(int n)\n"
    "Hidden(n) -> n + 1\n"
    "private int Marked(int n)\n"
    "Marked(n) -> n + 2\n".

a_private_function_is_not_part_of_the_api_test() ->
    Root = root(),
    Path = place(Root, "in.bs", private_src()),
    {Rc, Out, _} = run("--src-root " ++ Root ++ " --api " ++ Path),
    ?assertEqual(0, Rc),
    ?assertEqual(["module Guarded", "int Open(int)"], lines(Out)),
    ?assertEqual(nomatch, string:find(Out, "Hidden")),
    ?assertEqual(nomatch, string:find(Out, "Marked")).

%%% F17.3 — the API resolves module-local type aliases.

alias_src() ->
    "module Aliased\n"
    "type Verdict = :yes | :no\n"
    "public Verdict Decide(int n)\n"
    "Decide(n) when n > 0 -> :yes\n"
    "Decide(n) when n <= 0 -> :no\n".

a_type_alias_is_resolved_because_the_name_is_module_local_test() ->
    Root = root(),
    Path = place(Root, "in.bs", alias_src()),
    {0, Out, _} = run("--src-root " ++ Root ++ " --api " ++ Path),
    ?assertEqual(["module Aliased", ":no | :yes Decide(int)"], lines(Out)),
    ?assertEqual(nomatch, string:find(Out, "Verdict")).

%%% F17.4 — record parameters expose their tag and fields.

record_src() ->
    "module Boxed\n"
    "record Parcel { Id: int, Weight: int }\n"
    "public int Weigh(Parcel p)\n"
    "Weigh(p) -> p.Weight\n".

a_record_parameter_names_its_tag_and_its_fields_test() ->
    Root = root(),
    Path = place(Root, "in.bs", record_src()),
    {0, Out, _} = run("--src-root " ++ Root ++ " --api " ++ Path),
    ?assertEqual(["module Boxed",
                  "int Weigh({ Kind: :'Boxed.Parcel', Id: int, Weight: int })"],
                 lines(Out)).

%%% F17.5 — the query produces no build artifacts.

%% Correct output alone cannot show whether the query also builds the module.
the_query_builds_nothing_test() ->
    Root = root(),
    Path = place(Root, "in.bs", alias_src()),
    Out = Root ++ "/out",
    {0, _, _} = run("-o " ++ Out ++ " --src-root " ++ Root ++ " --api " ++ Path),
    ?assertEqual([], filelib:wildcard(Root ++ "/**/*.beam")),
    ?assertEqual([], filelib:wildcard(Root ++ "/**/*.abstr")),
    ?assertNot(filelib:is_dir(Out)).

%%% F17.6 — files in a module produce one aggregated answer.

index_src() ->
    "module Deep.Thing\n"
    "type Signal = :up | :down\n"
    "public Signal Flip(Signal s)\n"
    "Flip(:up) -> :down\n"
    "Flip(:down) -> :up\n".

sibling_src() ->
    "public int Twice(int n)\n"
    "Twice(n) -> n * 2\n".

a_module_split_across_files_answers_once_test() ->
    Root = root(),
    place(Root, "index.bs", index_src()),
    ok = file:write_file(Root ++ "/Deep/Thing/Other.bs", sibling_src()),
    Dir = Root ++ "/Deep/Thing",
    {Rc, Out, _} = run("--src-root " ++ Root ++ " --api " ++ Dir),
    ?assertEqual(0, Rc),
    ?assertEqual(["module Deep.Thing",
                  ":down | :up Flip(:down | :up)",
                  "int Twice(int)"],
                 lines(Out)),
    %% The aggregate prose cannot identify each operation's declaring file.
    {0, Term, _} = run("--diagnostics term --src-root " ++ Root ++
                           " --api " ++ Dir),
    Files = [F || #{tag := operation, file := F} <- terms(Term)],
    ?assertEqual([Dir ++ "/index.bs", Dir ++ "/Other.bs"], Files).

%%% F17.7 — the query rejects a module whose directory disagrees with its name.

the_answer_never_names_a_module_that_could_not_be_built_test() ->
    Root = root(),
    place(Root, "index.bs", index_src()),
    {Rc, Out, Err} = run("--api " ++ Root ++ "/Deep/Thing"),
    ?assertEqual(1, Rc),
    ?assertEqual("", Out),
    ?assertNotEqual(nomatch, string:find(Err, "does not match its directory")).

%%% F17.8 — the answer contains one term per line.

the_answer_is_a_term_one_map_per_line_test() ->
    {Rc, Out, _} = run("--diagnostics term --api " ++ examples() ++ "/Counter"),
    ?assertEqual(0, Rc),
    [Module | Ops] = terms(Out),
    ?assertMatch(#{tag := module, module := 'Counter',
                   behaviours := ['GenServer'], operations := 3}, Module),
    ?assertEqual(3, length(Ops)),
    ?assertEqual([{'HandleCall', 3}, {'HandleCast', 2}, {'Init', 1}],
                 [{N, A} || #{tag := operation, name := N, arity := A} <- Ops]),
    %% The term retains parameter names omitted by the prose.
    [_, _, Init] = Ops,
    ?assertMatch(#{params := [#{name := seed, type := "int"}],
                   result := "(:ok, int)"}, Init),
    %% Positions need separate keys, not a line key holding the whole pair.
    ?assertMatch(#{line := 16, column := 19}, Init).

%%% F17.9 — zero public operations is a valid answer.

nothing_public_src() ->
    "module Reticent\n"
    "int Inner(int n)\n"
    "Inner(n) -> n\n".

a_module_that_exports_nothing_answers_zero_operations_test() ->
    Root = root(),
    Path = place(Root, "in.bs", nothing_public_src()),
    {Rc, Out, Err} = run("--src-root " ++ Root ++ " --api " ++ Path),
    ?assertEqual(0, Rc),
    ?assertEqual(["module Reticent"], lines(Out)),
    %% Guidance stays off stdout so it cannot be parsed as an operation.
    ?assertNotEqual(nomatch, string:find(Err, "public")).

%%% F17.10 — an unreadable declaration is refused.

unknown_type_src() ->
    "module Broken\n"
    "public Nowhere Reach(int n)\n"
    "Reach(n) -> n\n".

a_signature_naming_an_unknown_type_is_refused_test() ->
    Root = root(),
    Path = place(Root, "in.bs", unknown_type_src()),
    {Rc, Out, Err} = run("--src-root " ++ Root ++ " --api " ++ Path),
    ?assertEqual(1, Rc),
    ?assertEqual("", Out),
    ?assertNotEqual(nomatch, string:find(Err, "no type named Nowhere")).

%%% F50.11 — a ToJson refusal also refuses the query.

to_json_refused_src() ->
    "module TjApi\n"
    "record Order { Id: int, Total: int }\n"
    "public string Outcome(result<Order, ValidationError> r)\n"
    "Outcome(r) -> ToJson<result<Order, ValidationError>>(r)\n".

%% This refusal occurs in a body, beyond signature type resolution.
a_to_json_refusal_refuses_the_query_test() ->
    Root = root(),
    Path = place(Root, "in.bs", to_json_refused_src()),
    {Rc, Out, Err} = run("--src-root " ++ Root ++ " --api " ++ Path),
    ?assertEqual(1, Rc),
    ?assertEqual("", Out),
    ?assertNotEqual(nomatch,
                    string:find(Err, "calls ToJson over a type with no wire form")).

%%% F17.11 — a query does not run the module.

the_query_does_not_run_the_module_test() ->
    {Rc, Out, Err} = run("--api " ++ examples() ++ "/Fib 5"),
    ?assertEqual(2, Rc),
    ?assertEqual("", Out),
    ?assertNotEqual(nomatch, string:find(Err, "does not run one")).

%%% F17.12 — a query needs no dependency build.

%% The dependency is deliberately absent; resolving it would refuse the query.
importing_src() ->
    "module Dependent\n"
    "using Absent.Somewhere\n"
    "public int Local(int n)\n"
    "Local(n) -> n + 1\n".

a_module_with_imports_answers_without_its_dependencies_test() ->
    Root = root(),
    Path = place(Root, "in.bs", importing_src()),
    {Rc, Out, _} = run("--src-root " ++ Root ++ " --api " ++ Path),
    ?assertEqual(0, Rc),
    ?assertEqual(["module Dependent", "int Local(int)"], lines(Out)),
    %% Compiling the same module fails because it needs the dependency.
    {Rc2, _, _} = run("-o " ++ Root ++ "/out --src-root " ++ Root ++ " " ++ Path),
    ?assertEqual(1, Rc2).

%%% F17.13 — an inexhaustive function still has an API.

inexhaustive_src() ->
    "module Partial\n"
    "type Signal = :red | :amber | :green\n"
    "public int Rank(Signal s)\n"
    "Rank(:red) -> 1\n"
    "Rank(:green) -> 3\n".

an_inexhaustive_function_still_has_an_api_test() ->
    Root = root(),
    Path = place(Root, "in.bs", inexhaustive_src()),
    {Rc, Out, _} = run("--src-root " ++ Root ++ " --api " ++ Path),
    ?assertEqual(0, Rc),
    ?assertEqual(["module Partial", "int Rank(:amber | :green | :red)"],
                 lines(Out)),
    %% The compile control checks exhaustiveness even though the query succeeds.
    {Rc2, _, _} = run("-o " ++ Root ++ "/out --src-root " ++ Root ++ " " ++ Path),
    ?assertEqual(1, Rc2).

%%% --- Invocation refusals ---

%% A namespace enters as an argument, since only module directories are paths.
a_namespace_is_not_a_module_test() ->
    {Rc, Out, Err} = run("--api " ++ examples() ++ "/Shop/Collections"),
    ?assertEqual(2, Rc),
    ?assertEqual("", Out),
    ?assertNotEqual(nomatch, string:find(Err, "is a namespace, not a module")),
    ?assertNotEqual(nomatch, string:find(Err, "Shop/Collections/Ints")).

%% The missing file sits in a valid module; the directory must not stand in.
a_path_that_does_not_exist_is_refused_test() ->
    Root = root(),
    place(Root, "in.bs", alias_src()),
    {Rc, Out, Err} = run("--api " ++ Root ++ "/Aliased/gone.bs"),
    ?assertEqual(2, Rc),
    ?assertEqual("", Out),
    ?assertNotEqual(nomatch, string:find(Err, "is not a module")).

api_with_no_module_says_so_test() ->
    {Rc, Out, Err} = run("--api"),
    ?assertEqual(2, Rc),
    ?assertEqual("", Out),
    ?assertNotEqual(nomatch, string:find(Err, "--api needs a module")).

the_usage_text_names_the_flag_test() ->
    {Rc, Out, _} = run(""),
    ?assertEqual(2, Rc),
    ?assertNotEqual(nomatch, string:find(Out, "--api")).

%%% --- Query inputs ---

a_file_that_will_not_parse_has_no_api_test() ->
    Root = root(),
    Path = place(Root, "in.bs", "module Bent\npublic int Half(int n\n"),
    {Rc, Out, Err} = run("--src-root " ++ Root ++ " --api " ++ Path),
    ?assertEqual(1, Rc),
    ?assertEqual("", Out),
    ?assertNotEqual(nomatch, string:find(Err, "syntax error")).

a_file_with_no_module_line_is_Main_test() ->
    Root = root(),
    ok = filelib:ensure_dir(Root ++ "/Main/x"),
    ok = file:write_file(Root ++ "/Main/in.bs",
                         "public int Twice(int n)\nTwice(n) -> n * 2\n"),
    {Rc, Out, _} = run("--src-root " ++ Root ++ " --api " ++ Root ++ "/Main"),
    ?assertEqual(0, Rc),
    ?assertEqual(["module Main", "int Twice(int)"], lines(Out)).

%% No module declaration is available to locate this path mismatch.
the_default_module_name_is_checked_against_the_path_too_test() ->
    Root = root(),
    ok = filelib:ensure_dir(Root ++ "/Elsewhere/x"),
    ok = file:write_file(Root ++ "/Elsewhere/in.bs",
                         "public int Twice(int n)\nTwice(n) -> n * 2\n"),
    {Rc, Out, Err} = run("--src-root " ++ Root ++ " --api " ++ Root ++
                             "/Elsewhere"),
    ?assertEqual(1, Rc),
    ?assertEqual("", Out),
    ?assertNotEqual(nomatch, string:find(Err, "does not match its directory")).

%% These path checks raise; the CLI must render them instead of a stack trace.
a_source_root_that_is_not_a_prefix_is_named_test() ->
    Root = root(),
    Path = place(Root, "in.bs", alias_src()),
    Other = root(),
    {Rc, Out, Err} = run("--src-root " ++ Other ++ " --api " ++ Path),
    ?assertEqual(1, Rc),
    ?assertEqual("", Out),
    ?assertNotEqual(nomatch, string:find(Err, "does not contain")).

a_source_root_that_is_the_module_is_named_test() ->
    Root = root(),
    place(Root, "in.bs", alias_src()),
    Dir = Root ++ "/Aliased",
    {Rc, Out, Err} = run("--src-root " ++ Dir ++ " --api " ++ Dir),
    ?assertEqual(1, Rc),
    ?assertEqual("", Out),
    ?assertNotEqual(nomatch, string:find(Err, "is the module directory itself")).

%%% --- Channel framing ---

%% Refusals must replace the answer, so consumers never receive a partial API.
the_term_channel_carries_the_refusal_instead_of_the_answer_test() ->
    Root = root(),
    Path = place(Root, "in.bs", unknown_type_src()),
    {Rc, Out, _} = run("--diagnostics term --src-root " ++ Root ++
                           " --api " ++ Path),
    ?assertEqual(1, Rc),
    ?assertMatch([#{tag := unknown_type, severity := error}], terms(Out)),
    ?assertEqual([], [T || T = #{tag := module} <- terms(Out)]).

%% A path refusal reaches the channel separately from declaration refusals.
the_term_channel_carries_a_path_refusal_the_same_way_test() ->
    Root = root(),
    place(Root, "index.bs", index_src()),
    {Rc, Out, _} = run("--diagnostics term --api " ++ Root ++ "/Deep/Thing"),
    ?assertEqual(1, Rc),
    ?assertMatch([#{tag := module_path_mismatch}], terms(Out)).

the_repl_and_the_query_are_not_asked_for_together_test() ->
    {Rc, Out, Err} = run("--repl --api " ++ examples() ++ "/Counter"),
    ?assertEqual(2, Rc),
    ?assertEqual("", Out),
    ?assertNotEqual(nomatch, string:find(Err, "not available in the REPL")).

%%% --- Example modules ---

%% One subprocess per module can exceed eunit's default five-second timeout.
every_example_module_answers_test_() ->
    {timeout, 120, fun every_example_module_answers/0}.

every_example_module_answers() ->
    Root = examples(),
    %% Exemplar sources include syntax outside the supported language.
    Dirs = [D || D <- bsc:module_dirs(Root),
                 string:find(D, "/exemplars/") =:= nomatch],
    ?assert(length(Dirs) >= 6),
    [begin
         {Rc, Out, Err} = run("--src-root " ++ Root ++ " --api " ++ D),
         ?assertEqual({D, 0, ""}, {D, Rc, Err}),
         ?assertMatch(["module " ++ _ | _], lines(Out))
     end || D <- Dirs].
