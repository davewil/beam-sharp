%%% Boundary helpers: source text in, callable beam code out.

%%% Scenarios: compiler/features/F15-module-is-a-directory.md
%%% Scenarios: compiler/features/F14-pipe-and-valve.md
-module(bs_test_support).

-include_lib("eunit/include/eunit.hrl").

-export([compile/1, build_and_load/2, check_only/1, errors/1, project_root/0,
         escript/0, built/0, run_command_result/1, run_cli/1, run_cli_result/1,
         run_cli_split_result/1, run_cli_with_stdin_file_result/2, with_src/3,
         run_root/0, fixture_root/0, place/3,
         showcase_src/0, shop_src/0, an_order/0, count/2, validation_error/2]).

%% The generated ValidateAs<T> failure contains a ValidationError record.
validation_error(Path, Expected) ->
    {error, #{'Kind' => 'ValidationError', 'Path' => Path, 'Expected' => Expected}}.

-define(OUT, run_root()).

%%% --- Helpers ---

%%% F15 — each fixture occupies a directory named for its module.
%%% Files in one directory aggregate into one module; fixtures need isolation.
%%% The CLI checks the module name against its path. Read it from the source.

%% The checkout path isolates worktrees; pid and VM start time isolate runs.
%% Isolated roots keep recursive indexing within eunit's timeout.
run_root() ->
    Run = "run-" ++ os:getpid() ++ "-" ++
          integer_to_list(erlang:system_info(start_time)),
    D = filename:join([project_root(), "_build", "test", "bsc_eunit", Run]),
    ok = filelib:ensure_dir(D ++ "/x"),
    D.

fixture_root() ->
    D = ?OUT ++ "/fx-" ++ os:getpid() ++ "-" ++
        integer_to_list(erlang:unique_integer([positive])),
    ok = filelib:ensure_dir(D ++ "/x"),
    D.

%% Dotted modules need nested directories to match --src-root path checks.
place(Root, Name, Src) ->
    Dir = filename:join([Root | module_segments(Src)]),
    ok = filelib:ensure_dir(Dir ++ "/x"),
    Path = filename:join(Dir, Name),
    ok = file:write_file(Path, Src),
    Path.

module_segments(Src) ->
    Lines = [string:trim(L) || L <- string:lexemes(Src, "\n")],
    case [string:trim(R) || L <- Lines, (R = string:prefix(L, "module ")) =/= nomatch] of
        [M | _] -> string:lexemes(M, ".");
        []      -> ["Main"]
    end.

compile(Src) ->
    Path = place(fixture_root(), "in.bs", Src),
    %% The compiler entry point, without depending on its private opts record.
    Result = bsc:file_to_dir(Path, ?OUT),
    code:add_patha(?OUT),
    Result.

%% Compile and load the module so tests can call its exported functions.
build_and_load(Src, Mod) ->
    {ok, _} = compile(Src),
    code:purge(Mod),
    {module, Mod} = code:load_abs(?OUT ++ "/" ++ atom_to_list(Mod)),
    Mod.

check_only(Src) ->
    {ok, Toks, _} = bs_lexer:string(Src),
    {ok, Decls} = bs_parser:parse(Toks),
    %% F14 — lower valves between parsing and checking, as bsc does.
    %% Unlowered valves fall through to term without checking their contents.
    bs_check:check(bs_lower:valves(Decls)).

showcase_src() ->
    "module Readings\n"
    "type Verdict = :positive | :zero | :negative | :unknown\n"
    "type Reading = (:ok, int) | (:error, atom)\n"
    "public Verdict Classify(Reading r)\n"
    "Classify((:ok, n)) when n > 0 -> :positive\n"
    "Classify((:ok, 0))            -> :zero\n"
    "Classify((:ok, n))            -> :negative\n"
    "Classify((:error, e))         -> :unknown\n".

%% The pre-eunit hook builds the escript under the test profile.
%% Fall back to the default profile; if absent, name the artefact CI builds.
escript() ->
    Default = project_root() ++ "/_build/default/bin/bsc",
    Candidates = [project_root() ++ "/_build/test/bin/bsc", Default],
    case [P || P <- Candidates, filelib:is_regular(P)] of
        [Found | _] -> Found;
        []          -> Default
    end.

%% Announce a missing escript so skipped tests are distinguishable from passes.
built() ->
    case filelib:is_regular(escript()) of
        true  -> true;
        false ->
            io:format(user, "  SKIPPED (no escript — run `rebar3 escriptize`)~n", []),
            false
    end.

run_cli(Args) ->
    {Rc, Output} = run_cli_result(Args),
    Output ++ "rc:" ++ integer_to_list(Rc) ++ "\n".

run_command_result(Command) ->
    bs_process:run_merged(Command).

%% The shell parses argument strings; exec replaces it with the escript.
%% The port captures the CLI's exit status separately from its output.
run_cli_result(Args) ->
    run_command_result(escript() ++ " " ++ Args).

run_cli_with_stdin_file_result(Args, InputPath) ->
    run_command_result(escript() ++ " " ++ Args ++ " < " ++ InputPath).

run_cli_split_result(Args) ->
    CaptureRoot = fixture_root(),
    StdoutPath = filename:join(CaptureRoot, "stdout"),
    StderrPath = filename:join(CaptureRoot, "stderr"),
    {Rc, _} = run_command_result(escript() ++ " " ++ Args ++
                                 " > " ++ StdoutPath ++
                                 " 2> " ++ StderrPath),
    {Rc, read_capture(StdoutPath), read_capture(StderrPath)}.

read_capture(Path) ->
    {ok, Bin} = file:read_file(Path),
    binary_to_list(Bin).

with_src(Name, Src, Fun) ->
    Root = fixture_root(),
    Fun(place(Root, Name, Src), Root).

shop_src() ->
    "module Shop\n"
    "record Order { Id: int, Total: int }\n"
    "record Invoice { Id: int, Total: int }\n"
    "type Doc = Order | Invoice\n"
    "public Order Draft()\n"
    "Draft() -> Order { Id = 1, Total = 0 }\n"
    "public Order Pay(Order o)\n"
    "Pay(o) -> o with { Total = 500 }\n"
    "public int Amount(Order o)\n"
    "Amount(o) -> o.Total\n"
    "public int Either(Doc d)\n"
    "Either(d) -> d.Total\n"
    "public atom Which(Doc)\n"
    "Which(Order o) -> :order\n"
    "Which(Invoice i) -> :invoice\n"
    "public int Total(int n)\n"
    "Total(n) -> n + 1\n".

an_order() -> #{'Kind' => 'Shop.Order', 'Id' => 1, 'Total' => 0}.

%% Count atom occurrences throughout a nested term.
count(Atom, Atom) -> 1;
count(T, Atom) when is_tuple(T) -> count(tuple_to_list(T), Atom);
count(L, Atom) when is_list(L) -> lists:sum([count(E, Atom) || E <- L]);
count(_, _) -> 0.

errors(Src) ->
    {error, Diags} = check_only(Src),
    [D || D <- Diags, element(1, D) =:= error].

%% eunit runs from _build/test/lib/bsc, so walk back to the project.
project_root() ->
    filename:join(lists:takewhile(fun(C) -> C =/= "_build" end,
                                  filename:split(element(2, file:get_cwd())))).
