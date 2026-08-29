-module(api_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [project_root/0, place/3]).

%%% ---------------------------------------------------------------------------
%%% F17 — `bsc --api <Module>`, the compiler query mode
%%%
%%% Ticket 23 §10. Every test here drives the BUILT ESCRIPT and asserts on what
%%% it printed and what it exited with, because `--api` is a CLI channel and has
%%% no other boundary: refactor `bs_api` however you like and these still pass,
%%% which is the whole point of putting them here rather than against
%%% `bs_api:answer/3`.
%%%
%%% THERE IS NO SILENT SKIP IN THIS FILE, DELIBERATELY. `cli_tests` guarded
%%% itself with `is_regular(escript())` and returned `ok` when the artefact was
%%% absent — and CI ran `rebar3 eunit` BEFORE `rebar3 escriptize`, so the guard
%%% was always taken and a whole file of tests was green and empty for weeks.
%%% `escript/0` below throws instead, with the command to run.
%%%
%%% AND THE STREAMS ARE READ SEPARATELY. The suite's other CLI tests merge them
%%% with `2>&1`, which these cannot do: the answer goes to stdout and the prose
%%% that is NOT the answer — the refusals, and the "exports nothing" sentence —
%%% goes to stderr. Merging them would make every assertion here pass for the
%%% wrong reason.
%%% ---------------------------------------------------------------------------

escript() ->
    E = bs_test_support:escript(),
    case filelib:is_regular(E) of
        true  -> E;
        false -> throw({no_escript, E, "run `rebar3 escriptize` first"})
    end.

%% A FIXTURE ROOT OF THIS FILE'S OWN.
%%
%% These tests keep source in a unique per-case directory. The shared process
%% helper gives its stdout and stderr captures a separate unique per-case
%% directory, so another test or VM cannot replace either stream between the
%% shell redirect and the read. `_build/test` is rebar's, gitignored, and outside
%% every gate's `find`.
root() ->
    D = project_root() ++ "/_build/test/api_fixtures/fx-" ++ os:getpid() ++
        "-" ++ integer_to_list(erlang:unique_integer([positive])),
    ok = filelib:ensure_dir(D ++ "/x"),
    D.

%% {ExitCode, Stdout, Stderr}. Redirected to files rather than merged, so a test
%% can say which stream a line arrived on.
run(Args) ->
    _ = escript(),
    bs_test_support:run_cli_split_result(Args).

lines(S) -> [L || L <- string:split(string:trim(S), "\n", all), L =/= ""].

%% The framing contract this shares with F16: one term per line, so a consumer
%% splits on newlines and parses each. As naive as a consumer would be — if it
%% has to get cleverer, the channel has broken its promise.
terms(S) ->
    [begin
         {ok, Toks, _} = erl_scan:string(L ++ "."),
         {ok, Term} = erl_parse:parse_term(Toks),
         Term
     end || L <- lines(S)].

examples() -> project_root() ++ "/examples".

%%% --- F17.1 — what it looks like on a real example ---------------------------

%% `examples/Counter` rather than a fixture, because the features README is
%% explicit that a feature is done when you can SEE IT RUN. This is the sample
%% output in F17's own file, asserted.
the_api_of_a_real_example_test() ->
    {Rc, Out, _} = run("--api " ++ examples() ++ "/Counter"),
    ?assertEqual(0, Rc),
    ?assertEqual(["module Counter",
                  "behaviour GenServer",
                  "(:reply, int, int) HandleCall(:get | (:add, int), term, int)",
                  "(:noreply, int) HandleCast(:reset | (:add, int), int)",
                  "(:ok, int) Init(int)"],
                 lines(Out)).

%% The operations are sorted by name and arity rather than printed in source
%% order — a module is a directory, so source order is an artefact of how the
%% author split the files.
the_operations_are_sorted_by_name_and_arity_test() ->
    {0, Out, _} = run("--diagnostics term --api " ++ examples() ++ "/Shop"),
    [_Module | Ops] = terms(Out),
    Keys = [{N, A} || #{tag := operation, name := N, arity := A} <- Ops],
    ?assert(length(Keys) >= 5),
    ?assertEqual(lists:sort(Keys), Keys).

%%% --- F17.2 — a private function is not part of the API ----------------------

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

%%% --- F17.3 — a type name is module-local, so it is resolved -----------------

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
    %% The name the author wrote is NOT what a caller can use: `import_env/3`
    %% carries no table of types, so `Verdict` means nothing outside `Aliased`.
    ?assertEqual(nomatch, string:find(Out, "Verdict")).

%%% --- F17.4 — a record parameter names its minted tag and its fields ---------

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

%%% --- F17.5 — 23 §10's "with no build", asserted rather than assumed ---------

%% The central claim of the whole mode, and the one thing no other test here
%% would notice going wrong: `--api` could compile the module, throw the beam
%% away and print the same answer.
the_query_builds_nothing_test() ->
    Root = root(),
    Path = place(Root, "in.bs", alias_src()),
    Out = Root ++ "/out",
    {0, _, _} = run("-o " ++ Out ++ " --src-root " ++ Root ++ " --api " ++ Path),
    ?assertEqual([], filelib:wildcard(Root ++ "/**/*.beam")),
    ?assertEqual([], filelib:wildcard(Root ++ "/**/*.abstr")),
    ?assertNot(filelib:is_dir(Out)).

%%% --- F17.6 — a module is a directory, and may be several files --------------

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
    %% Each operation carries the file that declares it, which is what the
    %% aggregate makes impossible to work out from outside.
    {0, Term, _} = run("--diagnostics term --src-root " ++ Root ++
                           " --api " ++ Dir),
    Files = [F || #{tag := operation, file := F} <- terms(Term)],
    ?assertEqual([Dir ++ "/index.bs", Dir ++ "/Other.bs"], Files).

%%% --- F17.7 — the answer never names a module that could not be built --------

the_answer_never_names_a_module_that_could_not_be_built_test() ->
    Root = root(),
    place(Root, "index.bs", index_src()),
    {Rc, Out, Err} = run("--api " ++ Root ++ "/Deep/Thing"),
    ?assertEqual(1, Rc),
    ?assertEqual("", Out),
    ?assertNotEqual(nomatch, string:find(Err, "does not match its directory")).

%%% --- F17.8 — the answer as a term -------------------------------------------

the_answer_is_a_term_one_map_per_line_test() ->
    {Rc, Out, _} = run("--diagnostics term --api " ++ examples() ++ "/Counter"),
    ?assertEqual(0, Rc),
    [Module | Ops] = terms(Out),
    ?assertMatch(#{tag := module, module := 'Counter',
                   behaviours := ['GenServer'], operations := 3}, Module),
    ?assertEqual(3, length(Ops)),
    ?assertEqual([{'HandleCall', 3}, {'HandleCast', 2}, {'Init', 1}],
                 [{N, A} || #{tag := operation, name := N, arity := A} <- Ops]),
    %% The parameter names the prose drops are here, which is F16's split: the
    %% term is full fidelity and the prose is the lossy function of it.
    [_, _, Init] = Ops,
    ?assertMatch(#{params := [#{name := seed, type := "int"}],
                   result := "(:ok, int)"}, Init).

%%% --- F17.9 — zero operations is an answer, not an error ---------------------

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
    %% The teaching sentence is on stderr, so a consumer reading stdout gets an
    %% answer of zero operations and nothing else to parse.
    ?assertNotEqual(nomatch, string:find(Err, "public")).

%%% --- F17.10 — a declaration that cannot be read is refused ------------------

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

%%% --- F17.11 — it answers about a module; it does not run one ----------------

the_query_does_not_run_the_module_test() ->
    {Rc, Out, Err} = run("--api " ++ examples() ++ "/Fib 5"),
    ?assertEqual(2, Rc),
    ?assertEqual("", Out),
    ?assertNotEqual(nomatch, string:find(Err, "does not run one")).

%%% --- F17.12 — no world, and therefore no build ------------------------------

%% The dependency named here DOES NOT EXIST ANYWHERE, which is the point:
%% `check_dir/3` would raise `unknown_module` and refuse, and the declaration
%% pass never asks. That is the property that makes 23 §10's "with no build"
%% true rather than aspirational.
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
    %% ...and the same module does NOT compile, so the two are really different
    %% questions rather than the same one asked twice.
    {Rc2, _, _} = run("-o " ++ Root ++ "/out --src-root " ++ Root ++ " " ++ Path),
    ?assertEqual(1, Rc2).

%%% --- F17.13 — the API is the signatures, not the bodies ---------------------

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
    %% And it does not compile, which is what makes this scenario worth having:
    %% withholding the answer exactly when the module is half-written is the
    %% worst possible input to a feedback loop (23 §7).
    {Rc2, _, _} = run("-o " ++ Root ++ "/out --src-root " ++ Root ++ " " ++ Path),
    ?assertEqual(1, Rc2).

%%% --- The invocation refusals ------------------------------------------------

%% A namespace reaches `--api` through the ARGV rather than the paths, because
%% `is_path_arg/1` counts a directory only if it is a module. Answering it with
%% the "does not run one" message would answer a precise mistake generally.
a_namespace_is_not_a_module_test() ->
    {Rc, Out, Err} = run("--api " ++ examples() ++ "/Shop/Collections"),
    ?assertEqual(2, Rc),
    ?assertEqual("", Out),
    ?assertNotEqual(nomatch, string:find(Err, "is a namespace, not a module")),
    ?assertNotEqual(nomatch, string:find(Err, "Shop/Collections/List")).

%% `.bs` on the end makes an argument a path whether the file is there or not,
%% and its directory may be a perfectly good module — so without this the query
%% answers about a module nobody named.
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

%%% --- The rest of what the query can be handed --------------------------------

%% A file that will not parse has no declarations to read, so there is no answer
%% to give. The diagnostic is the parser's own, published on the channel by
%% `bsc:parse_path/1` — this feature mints no tag of its own.
a_file_that_will_not_parse_has_no_api_test() ->
    Root = root(),
    Path = place(Root, "in.bs", "module Bent\npublic int Half(int n\n"),
    {Rc, Out, Err} = run("--src-root " ++ Root ++ " --api " ++ Path),
    ?assertEqual(1, Rc),
    ?assertEqual("", Out),
    ?assertNotEqual(nomatch, string:find(Err, "syntax error")).

%% The same default the checker applies: a file with no `module` line is `Main`.
a_file_with_no_module_line_is_Main_test() ->
    Root = root(),
    ok = filelib:ensure_dir(Root ++ "/Main/x"),
    ok = file:write_file(Root ++ "/Main/in.bs",
                         "public int Twice(int n)\nTwice(n) -> n * 2\n"),
    {Rc, Out, _} = run("--src-root " ++ Root ++ " --api " ++ Root ++ "/Main"),
    ?assertEqual(0, Rc),
    ?assertEqual(["module Main", "int Twice(int)"], lines(Out)).

%% ...and the path check still applies to that default, which is the only route
%% to a mismatch reported against a file with no `module` line in it to point at.
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

%% `expected_module/2` raises rather than returning for these two, and both
%% already have a descriptor and a message in `bs_diag`. Uncaught they arrive as
%% an escript stack trace, which this project calls the worst diagnostic it
%% produces — so the catch is the test.
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

%%% --- The channel's own promise ----------------------------------------------

%% F16's landing note, one feature along: A ONE-OF-A-THING FIXTURE CANNOT SEE A
%% FRAMING ERROR, AND FRAMING IS THE WHOLE OF WHAT A MACHINE CHANNEL PROMISES.
%% Every other term test here runs a module that answers, so all of them see one
%% `module` map followed by `operation` maps. This is the case a consumer meets
%% when it matters: stdout carries the diagnostics INSTEAD of the answer, never
%% both, so a consumer dispatches on `tag` and never has to decide whether a
%% partial answer is trustworthy.
the_term_channel_carries_the_refusal_instead_of_the_answer_test() ->
    Root = root(),
    Path = place(Root, "in.bs", unknown_type_src()),
    {Rc, Out, _} = run("--diagnostics term --src-root " ++ Root ++
                           " --api " ++ Path),
    ?assertEqual(1, Rc),
    ?assertMatch([#{tag := unknown_type, severity := error}], terms(Out)),
    ?assertEqual([], [T || T = #{tag := module} <- terms(Out)]).

%% ...and the same holds for the refusal that is about the PATH rather than the
%% declarations, which reaches the channel from a different function.
the_term_channel_carries_a_path_refusal_the_same_way_test() ->
    Root = root(),
    place(Root, "index.bs", index_src()),
    {Rc, Out, _} = run("--diagnostics term --api " ++ Root ++ "/Deep/Thing"),
    ?assertEqual(1, Rc),
    ?assertMatch([#{tag := module_path_mismatch}], terms(Out)).

%% A query answers and exits; the prompt is a session over a module. Refused
%% rather than silently preferred, which is `--diagnostics term`'s precedent in
%% the same place.
the_repl_and_the_query_are_not_asked_for_together_test() ->
    {Rc, Out, Err} = run("--repl --api " ++ examples() ++ "/Counter"),
    ?assertEqual(2, Rc),
    ?assertEqual("", Out),
    ?assertNotEqual(nomatch, string:find(Err, "not available in the REPL")).

%%% --- The done-when sweep ----------------------------------------------------

%% "answers for every module in `examples/` without compiling anything". It
%% shells out once per module directory, which is what blew eunit's 5s default
%% for `every_example_still_compiles` — so it carries a timeout fixture from the
%% start rather than being given one after a "cancelled" run reads like a
%% regression somebody just introduced.
every_example_module_answers_test_() ->
    {timeout, 120, fun every_example_module_answers/0}.

every_example_module_answers() ->
    Root = examples(),
    %% `exemplars/` is ticket 25's backlog and does not parse yet by design.
    Dirs = [D || D <- bsc:module_dirs(Root),
                 string:find(D, "/exemplars/") =:= nomatch],
    ?assert(length(Dirs) >= 6),
    [begin
         {Rc, Out, Err} = run("--src-root " ++ Root ++ " --api " ++ D),
         ?assertEqual({D, 0, ""}, {D, Rc, Err}),
         ?assertMatch(["module " ++ _ | _], lines(Out))
     end || D <- Dirs].
