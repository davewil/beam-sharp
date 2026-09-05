%%% bsc — the beam-sharp compiler's command line.
%%%
%%% A module is a DIRECTORY. One holding `.bs` files is a module and those
%%% files are its source; one holding only directories is a namespace, which
%%% is erased. Naming a file names its module. `bsc PATH` compiles the module
%%% and every module it reaches through `using`, dependencies first;
%%% `bsc PATH FUNCTION ARG...` compiles and then runs one exported function;
%%% `--api PATH` reports what operations a module offers, with nothing built;
%%% `--repl` (`ibs -S FILE`) opens a prompt over the compiled module; and
%%% `--batch MANIFEST RESULTS` runs many invocations in this one VM.
%%%
%%% Each source file passes through:
%%%
%%%     lex -> parse -> lower valves -> check (types, exhaustiveness, path)
%%%         -> abstract format -> .abstr -> compile:file from_abstr -> .beam
%%%
%%% Every diagnostic is a term rendered once, in `bs_diag`; nothing here
%%% prints one of its own.

-module(bsc).

-export([main/1, file/1, file/2, file_to_dir/2, compile_string/2]).
%% The corpus gates and `bs_api` classify directories and parse files through
%% these same functions rather than through copies of their own: a
%% classification rule with two implementations has two answers (F15, F17).
-export([module_dirs/1, dir_kind/1, expected_module/2, parse_path/1,
         module_dir_of/1]).
%% `status/2` returns one invocation's exit status instead of halting, which
%% is what lets `bs_batch` run many in one VM; `exit_with/1` is how every
%% exit site, `bs_api` included, reaches it (ENG-314).
-export([status/2, exit_with/1]).

-record(opts, {outdir = ".", emit_abstr = true, verbose = false, repl = false,
               %% The source root is a build-tool input (ticket 41 §3).
               %% `undefined` means the default in `expected_module/2`,
               %% not "no check".
               src_root = undefined,
               %% The CLI always has a root and always checks the `module`
               %% line against the path; `file/2` is a library entry point
               %% with no root, so it aggregates the directory without the
               %% check rather than inventing a root (ticket 41 §5).
               check_path = true,
               %% The channel the CLI publishes on, `prose` or `term` (F16).
               diagnostics = prose,
               %% Query mode: report what a module offers instead of
               %% compiling it (F17).
               api = false}).

%% The cap on printed residual cases (ticket 43). The cap is applied in
%% `bs_diag`, which carries its own copy; nothing in this module reads this
%% one.
-define(RESIDUAL_CASES, 3).

%% For callers outside the CLI (the REPL's `:reload`) that have a directory
%% rather than an #opts{}.
file_to_dir(Path, Dir) -> file(Path, #opts{outdir = Dir}).

%%% ---------------------------------------------------------------------------
%%% CLI
%%% ---------------------------------------------------------------------------

%% `--batch` is dispatched before anything else and takes exactly its two
%% arguments. Every other invocation is one `status/2`, and the VM halts with
%% what it returns (ENG-314).
main(["--batch", Manifest, Results]) ->
    erlang:halt(bs_batch:run(Manifest, Results));
main(Args) ->
    erlang:halt(status(Args, standalone)).

%% One invocation, as its exit status. `Context` is `standalone` for the CLI
%% and `batch` for an entry run in a shared VM; only the REPL refusal reads it.
%%
%% The exit is a throw, and `halt/1` is not called below this line: every
%% exit site calls `exit_with/1`, which throws `{bsc_exit, N}`, caught only
%% here. A `try` in between must never catch a throw it did not raise, or an
%% exit status becomes a normal return.
status(Args, Context) ->
    try dispatch(Args, Context) of
        _ -> 0
    catch
        throw:{bsc_exit, N} -> N
    end.

exit_with(Status) when is_integer(Status) -> throw({bsc_exit, Status}).

usage() ->
    io:format("usage: bsc [-o DIR] [-v] [--src-root DIR] [--diagnostics term]~n"
              "           [--api] PATH [FUNCTION] [ARG...]~n"
              "       bsc --batch MANIFEST RESULTS~n"
              "  PATH is a module, which is a DIRECTORY — naming one of its~n"
              "  files means the same thing. With no ARGs it compiles; with~n"
              "  ARGs it compiles then runs:~n"
              "      bsc examples/Fib 5~n"
              "      bsc --src-root examples examples/Shop/Reports Restate 3~n"
              "  --api reports what operations the module offers, in~n"
              "  beam-sharp's own types and with nothing built:~n"
              "      bsc --api examples/Counter~n"
              "  --batch runs every invocation listed in MANIFEST in this one~n"
              "  VM and writes each one's stdout, stderr, merged output and~n"
              "  exit status under RESULTS as <id>.stdout, .stderr, .output~n"
              "  and .status. The manifest is `entry ID`, an optional `cwd DIR`,~n"
              "  one `arg TEXT` line per argument, and `end`.~n"),
    exit_with(2).

dispatch([], _Context) ->
    usage();
dispatch(Args, Context) ->
    {Opts, Files, Argv} = parse_args(Args, #opts{}, []),
    %% `--repl` is refused in a batch rather than ignored: the prompt is a
    %% session on stdin, and a batch entry has none (ENG-314).
    case {Opts#opts.repl, Context} of
        {true, batch} ->
            io:format(standard_error,
                      "bsc: --repl is not available in a batch entry~n"
                      "  the prompt is a session on stdin, and a batch entry has~n"
                      "  no stdin. Run `bsc --repl FILE` on its own.~n", []),
            exit_with(2);
        _ -> ok
    end,
    %% The channel is set HERE and nowhere else, so a library caller and every
    %% in-process test gets `prose` (F16). `--diagnostics term` is refused in
    %% the REPL rather than ignored: the prompt prints values on stdout, so
    %% the flag's contract that stdout carries descriptors cannot hold, and a
    %% flag accepted and not honoured costs it its credibility everywhere.
    case {Opts#opts.repl, Opts#opts.diagnostics} of
        {true, term} ->
            io:format(standard_error,
                      "bsc: --diagnostics term is not available in the REPL~n"
                      "  the prompt prints values on stdout, so a descriptor~n"
                      "  there would be indistinguishable from a result.~n", []),
            exit_with(2);
        _ -> ok
    end,
    %% `--api` is refused in the REPL for the same reason: the query answers
    %% and exits, the prompt is a session, and neither may be silently
    %% dropped in favour of the other (F17).
    case {Opts#opts.repl, Opts#opts.api} of
        {true, true} ->
            io:format(standard_error,
                      "bsc: --api is not available in the REPL~n"
                      "  the query answers and exits; the prompt is a session~n"
                      "  over a module. Ask for one or the other.~n", []),
            exit_with(2);
        _ -> ok
    end,
    bs_diag:set_channel(Opts#opts.diagnostics),
    %% `--api` runs before the REPL and the compile path because it does
    %% neither (F17). `bs_api:answer/3` ends in `exit_with/1`, so this
    %% returns only when the flag was absent.
    case Opts#opts.api of
        true  -> bs_api:answer(Files, Argv, Opts#opts.src_root);
        false -> ok
    end,
    case {Opts#opts.repl, Files, Argv} of
        {true, [File], _} -> repl(File, Opts);
        {true, [], _} ->
            io:format(standard_error, "usage: ibs -S FILE.bs~n", []),
            exit_with(2);
        {false, F, A} -> compile_or_run(F, A, Opts)
    end.

compile_or_run(Files, Argv, Opts) ->
    case {Files, Argv} of
        %% A namespace named on the command line arrives in the argv, not the
        %% paths, because `is_path_arg/1` counts a directory as a path only
        %% if it is a module. It gets its exact name rather than the usage
        %% text (ticket 41 §5).
        {[], [A | _]} ->
            case filelib:is_dir(A) andalso dir_kind(A) =:= namespace of
                true ->
                    io:format(standard_error,
                              "bsc: ~s is a namespace, not a module~n"
                              "  it holds no `.bs` files of its own, so there is~n"
                              "  nothing to compile and nothing to emit — a~n"
                              "  namespace is erased entirely (41 §5). Name one of~n"
                              "  the modules under it:~n"
                              "~s",
                              [A, [io_lib:format("      ~s~n", [D])
                                   || D <- module_dirs(A)]]),
                    exit_with(2);
                false -> usage()
            end;
        {[], _}           -> usage();
        {[File], [_ | _]} -> run(File, Opts, Argv);
        {_, [_ | _]}     ->
            io:format(standard_error, "bsc: cannot run more than one file~n", []),
            exit_with(2);
        {_, []}          -> compile_only(Files, Opts)
    end.

compile_only(Files, Opts) ->
    case compile_set(Files, Opts) of
        {ok, _Beams} -> exit_with(0);
        {error, _}   -> exit_with(1)
    end.

%%% ---------------------------------------------------------------------------
%%% Compiling a SET of modules, in dependency order
%%%
%%% The compiler resolves `using` edges itself, checks a dependency before
%%% its dependents, and threads the dependency's signatures through one
%%% environment for the whole build. No artefact, nothing to go
%%% stale (F11, ticket 41 §3).
%%% ---------------------------------------------------------------------------

compile_set(Paths, Opts) ->
    case load_all(Paths, Opts) of
        {error, R}  -> {error, R};
        {ok, Units} ->
            case order(Units) of
                {error, {cycle, C}} ->
                    resolve_error("", {import_cycle, C}), {error, cycle};
                {ok, Ordered} ->
                    build(Ordered, Opts, #{}, [])
            end
    end.

build([], _Opts, _World, Acc) -> {ok, lists:reverse(Acc)};
build([{Dir, Sources, Mod} | Rest], Opts, World, Acc) ->
    case check_and_emit(Dir, Sources, Opts, World) of
        {ok, Beam} ->
            Decls = decls(Sources),
            World1 = World#{Mod => #{exports => bs_check:exports_of(Decls),
                                     %% Carried BESIDE the exports, not
                                     %% subtracted from them, so a dependent's
                                     %% refusal can say `private` rather than
                                     %% `unknown` (F12).
                                     private => bs_check:private_of(Decls),
                                     behaviours => [B || {behaviour, _, B} <- Decls]}},
            build(Rest, Opts, World1, [{Dir, Beam} | Acc]);
        Error ->
            Error
    end.

decls(Sources) -> lists:append([D || {_, D} <- Sources]).

%% The given module directories, plus every module they reach through
%% `using`. A dependency not named on the command line is found in the source
%% tree: `using Shop.Orders` is a path on disk (ticket 41 §3).
load_all(Paths, Opts) ->
    Dirs = lists:usort([module_dir_of(P) || P <- Paths]),
    case parse_all(Dirs) of
        {error, R} -> {error, R};
        {ok, Given} ->
            Index = source_index(Dirs, Opts#opts.src_root),
            close_over(Given, Index, [M || {_, _, M} <- Given])
    end.

%% What a `using` line depends on, which is not always what it names: `using
%% Shop` may name a NAMESPACE, and a namespace is erased, so the real
%% dependencies are the modules under it (ticket 41 §5). Discovery and
%% ordering both need the expansion.
import_targets(Decls, Known) ->
    lists:append([case lists:member(M, Known) of
                      true  -> [M];
                      false -> under(M, Known)
                  end || {import, _, M} <- Decls]).

under(Prefix, Known) ->
    P = atom_to_list(Prefix) ++ ".",
    [M || M <- Known, lists:prefix(P, atom_to_list(M))].

parse_all(Dirs) -> parse_all(Dirs, []).

parse_all([], Acc) -> {ok, lists:reverse(Acc)};
parse_all([D | Rest], Acc) ->
    case load_unit(D) of
        {ok, U} -> parse_all(Rest, [U | Acc]);
        Error   -> Error
    end.

%% A unit is `{Dir, [{Path, Decls}], Mod}`: the per-file list reaches the
%% checker and the emitter, so a diagnostic lands beside the right path and
%% the emitted `file` attribute precedes the right functions (F15, ticket 13
%% §3). The `namespace` arm is reached by a path that does not exist, such
%% as an unmatched shell glob `bsc examples/*.bs`, and it gets a sentence
%% rather than a stack trace.
load_unit(Dir) ->
    case dir_kind(Dir) of
        namespace ->
            report_fatal(Dir, no_sources_here), {error, no_sources_here};
        {module, Files} ->
            case load_sources(Files, []) of
                {error, R}    -> {error, R};
                {ok, Sources} -> {ok, {Dir, Sources, module_of(decls(Sources))}}
            end
    end.

load_sources([], Acc) -> {ok, lists:reverse(Acc)};
load_sources([F | Rest], Acc) ->
    case parse_path(F) of
        {ok, Decls} -> load_sources(Rest, [{F, Decls} | Acc]);
        Error       -> Error
    end.

close_over(Units, Index, Have) ->
    Wanted = lists:usort(lists:append([import_targets(decls(S), maps:keys(Index))
                                       || {_, S, _} <- Units])),
    case [M || M <- Wanted, not lists:member(M, Have),
               maps:is_key(M, Index)] of
        [] -> {ok, Units};
        New ->
            case parse_all([maps:get(M, Index) || M <- New]) of
                {error, R} -> {error, R};
                {ok, More} ->
                    close_over(Units ++ More, Index,
                               Have ++ [M || {_, _, M} <- More])
            end
    end.

%%% ---------------------------------------------------------------------------
%%% What a directory IS, in one function (F15, ticket 41 §5)
%%%
%%%   a directory holding `.bs` files -> a MODULE; those files are its source
%%%   a directory holding only dirs   -> a NAMESPACE: no atom, no beam, nothing
%%%
%%% Decidable by `ls`, with no marker and no keyword. It is one function
%%% because two would disagree: a `**/*.bs` index and a `*.bs` unit differ on
%%% a file in a subdirectory of a module, which the index would resolve and
%%% the build would never compile.
%%% ---------------------------------------------------------------------------

dir_kind(Dir) ->
    case bs_here(Dir) of
        []    -> namespace;
        Files -> {module, Files}
    end.

%% Non-recursive: a subdirectory is its own directory and gets its own
%% classification (F15.11). `index.bs` sorts FIRST because it is the
%% declaration file (ticket 41 §4): its `module` and `using` lines are the
%% first the checker sees, and every sibling that declares no module of its
%% own inherits from it.
bs_here(Dir) ->
    Files = filelib:wildcard(filename:join(Dir, "*.bs")),
    Index = [F || F <- Files, filename:basename(F) =:= "index.bs"],
    Index ++ lists:sort(Files -- Index).

%% Every module directory at or under `Dir`, walking through namespaces.
module_dirs(Dir) ->
    Subs = lists:sort([P || P <- filelib:wildcard(filename:join(Dir, "*")),
                            filelib:is_dir(P)]),
    Here = case dir_kind(Dir) of
               namespace   -> [];
               {module, _} -> [Dir]
           end,
    Here ++ lists:append([module_dirs(S) || S <- Subs]).

%% The module directory an argument names: itself if it is one, otherwise the
%% directory the named file sits in. Naming a file names its module, which is
%% what keeps `bsc examples/Fib/fib.bs 5` working when the unit is the
%% directory.
module_dir_of(P) ->
    case filelib:is_dir(P) of
        true  -> P;
        false -> filename:dirname(P)
    end.

%% Module atom -> module DIRECTORY, over every module directory under the
%% roots. Built by parsing rather than by naming, because the index must
%% answer for the tree as it is, including a directory whose declaration does
%% not match its path: that mismatch is a diagnostic to report, not a file to
%% lose (F15). A directory that fails to parse is skipped; if it is a
%% dependency, the error arrives when it is compiled.
source_index(Dirs, Root) ->
    Roots = case Root of
                undefined -> lists:usort([filename:dirname(D) || D <- Dirs]);
                _         -> [Root]
            end,
    All = lists:usort(lists:append([module_dirs(R) || R <- Roots])),
    lists:foldl(fun(D, Acc) ->
                        case dir_module(D) of
                            undefined -> Acc;
                            M -> maps:put(M, D, Acc)
                        end
                end, #{}, All).

%% The module a directory declares, without committing to compiling it.
dir_module(Dir) ->
    {module, Files} = dir_kind(Dir),
    module_of(lists:append([case parse_quietly(F) of
                                {ok, D} -> D;
                                error   -> []
                            end || F <- Files])).

module_of(Decls) ->
    case [N || {module, _, N} <- Decls] of
        [N | _] -> N;
        []      -> undefined
    end.

%%% ---------------------------------------------------------------------------
%%% The module atom a directory path implies, which the `module` line is
%%% checked against (F15, ticket 41 §5)
%%%
%%% The default root is the module directory's own parent, not the cwd, so a
%%% single-segment module needs no flag (`bsc examples/Fib` expects
%%% `module Fib`) and a multi-segment one fails LOUDLY until a root is named
%%% (`bsc examples/Shop/Reports` expects `module Reports` and finds
%%% `module Shop.Reports`). The default is never silently weaker than the
%%% explicit form; a suffix match would accept `Shop/Orders/Total.bs`
%%% declaring `module Orders`, an atom that has drifted from the path.
%%% ---------------------------------------------------------------------------

expected_module(Dir, Root0) ->
    Root = case Root0 of
               undefined -> filename:dirname(Dir);
               R         -> R
           end,
    DParts = norm(Dir),
    RParts = norm(Root),
    case lists:prefix(RParts, DParts) of
        false -> erlang:error({src_root_mismatch, Dir, Root});
        true  ->
            case lists:nthtail(length(RParts), DParts) of
                []  -> erlang:error({src_root_is_the_module, Dir});
                Rel -> list_to_atom(lists:flatten(lists:join(".", Rel)))
            end
    end.

%% Absolute and `..`-free, so a root given as `examples` and a directory
%% reached as `./examples/Fib` share a prefix; otherwise the check silently
%% does not apply.
norm(Path) ->
    lists:foldl(fun("..", [_ | Up]) -> Up;
                   ("..", [])       -> [];
                   (".", Acc)       -> Acc;
                   (Seg, Acc)       -> Acc ++ [Seg]
                end, [], filename:split(filename:absname(Path))).

%% Dependencies before dependents. A cycle is refused by name rather than
%% followed, since following one hangs (F6's cyclic-alias precedent).
order(Units) ->
    Index = maps:from_list([{M, U} || U = {_, _, M} <- Units]),
    visit(Units, Index, [], [], []).

visit([], _Index, _Path, _Done, Acc) -> {ok, lists:reverse(Acc)};
visit([U | Rest], Index, Path, Done, Acc) ->
    case emit_one(U, Index, Path, Done, Acc) of
        {error, R}        -> {error, R};
        {ok, Done1, Acc1} -> visit(Rest, Index, Path, Done1, Acc1)
    end.

emit_one({_, Sources, M} = U, Index, Path, Done, Acc) ->
    Decls = decls(Sources),
    case lists:member(M, Done) of
        true  -> {ok, Done, Acc};
        false ->
            case lists:member(M, Path) of
                true  -> {error, {cycle, lists:reverse([M | Path])}};
                false ->
                    %% `D =/= M` because a namespace expands to everything
                    %% under it, and a module inside the namespace it imports
                    %% is under it too; without this `module Shop.Reports`
                    %% with `using Shop` depended on itself.
                    Deps = [maps:get(D, Index)
                            || D <- import_targets(Decls, maps:keys(Index)),
                               D =/= M, maps:is_key(D, Index)],
                    case deps(Deps, Index, [M | Path], Done, Acc) of
                        {error, R}        -> {error, R};
                        {ok, Done1, Acc1} -> {ok, [M | Done1], [U | Acc1]}
                    end
            end
    end.

deps([], _Index, _Path, Done, Acc) -> {ok, Done, Acc};
deps([D | Rest], Index, Path, Done, Acc) ->
    case emit_one(D, Index, Path, Done, Acc) of
        {error, R}        -> {error, R};
        {ok, Done1, Acc1} -> deps(Rest, Index, Path, Done1, Acc1)
    end.

%% Bare arguments that are paths are files; the first that is not begins the
%% run argv, so `bsc fib.bs 5` and `bsc a.bs b.bs` both read without a
%% separator.
parse_args(["-o", Dir | Rest], O, Fs) -> parse_args(Rest, O#opts{outdir = Dir}, Fs);
parse_args(["-v" | Rest], O, Fs)      -> parse_args(Rest, O#opts{verbose = true}, Fs);
parse_args(["--repl" | Rest], O, Fs)  -> parse_args(Rest, O#opts{repl = true}, Fs);
%% `-S FILE` is iex's spelling and costs nothing to accept; the file is picked
%% up by the ordinary bare-argument rule below.
parse_args(["-S" | Rest], O, Fs)      -> parse_args(Rest, O, Fs);
%% The source root is a build-tool input: which files, where the root is, and
%% what to do with the output (ticket 41 §3).
parse_args(["--src-root", Dir | Rest], O, Fs) ->
    parse_args(Rest, O#opts{src_root = Dir}, Fs);
%% `--diagnostics` splits by STREAM: prose stays on stderr, the term goes to
%% stdout, and a consumer redirects rather than parses (F16, ticket 23 §1).
parse_args(["--diagnostics", "term" | Rest], O, Fs) ->
    parse_args(Rest, O#opts{diagnostics = term}, Fs);
parse_args(["--diagnostics", "prose" | Rest], O, Fs) ->
    parse_args(Rest, O#opts{diagnostics = prose}, Fs);
%% `--api` takes no argument of its own: the module it answers about is the
%% ordinary PATH argument every other mode takes (F17).
parse_args(["--api" | Rest], O, Fs)   -> parse_args(Rest, O#opts{api = true}, Fs);
%% `--batch` is matched whole in `main/1`; reaching it here means it was
%% combined with something else, which is refused rather than guessed at,
%% since every entry carries its own flags (ENG-314).
parse_args(["--batch" | _], _O, _Fs) ->
    io:format(standard_error,
              "bsc: --batch takes a manifest and a results directory, and nothing else~n"
              "      bsc --batch MANIFEST RESULTS~n"
              "  each entry of the manifest carries its own flags.~n", []),
    exit_with(2);
parse_args(["--diagnostics", Other | _], _O, _Fs) ->
    io:format(standard_error,
              "bsc: --diagnostics takes `prose` or `term`, not ~s~n", [Other]),
    exit_with(2);
parse_args([A | Rest], O, Fs) ->
    case is_path_arg(A) of
        true  -> parse_args(Rest, O, [A | Fs]);
        false -> {O, lists:reverse(Fs), [A | Rest]}
    end;
parse_args([], O, Fs)                 -> {O, lists:reverse(Fs), []}.

%% A `.bs` file, or a directory that is a MODULE (ticket 41 §3). The module
%% test matters: bare arguments that are not paths begin the run argv, so
%% `bsc examples/Fib Fib 5` must not read `Fib` as a directory just because
%% something called `Fib` exists in the cwd.
is_path_arg(A) ->
    filename:extension(A) =:= ".bs"
        orelse (filelib:is_dir(A) andalso dir_kind(A) =/= namespace).

%%% ---------------------------------------------------------------------------
%%% Running
%%%
%%% `bsc fib.bs 5` prints Fib of 5 without a second `erl -pa` invocation.
%%% ---------------------------------------------------------------------------

run(File, Opts0, Argv) ->
    Opts = case Opts0#opts.outdir of
               "." -> Opts0#opts{outdir = tmpdir()};
               _   -> Opts0
           end,
    %% Through the SET path, not `file/2`: a file with a `using` line needs
    %% its dependencies compiled and on the code path before it can run, and
    %% the same is true at the `ibs` prompt below (F11).
    case compile_set([File], Opts) of
        {ok, Beams} ->
            Beam = beam_for(File, Beams),
            Mod = list_to_atom(filename:basename(Beam, ".beam")),
            report_run(bs_run:run(filename:dirname(Beam), Mod, Argv));
        _ ->
            exit_with(1)
    end.

%% The build's results are keyed by MODULE DIRECTORY, the unit, while the
%% argument may still be a file: `bsc fib.bs 5` and `ibs -S fib.bs` both
%% arrive here with one (F15).
beam_for(Path, Beams) ->
    {_, Beam} = lists:keyfind(module_dir_of(Path), 1, Beams),
    Beam.

report_run({ok, Value}) ->
    io:format("~s~n", [bs_run:format_value(Value)]),
    exit_with(0);
report_run({crashed, error, {Tag, Detail}, _}) when is_atom(Tag) ->
    io:format(standard_error, "crashed: ~p ~s~n", [Tag, bs_run:format_value(Detail)]),
    exit_with(1);
report_run({crashed, Class, Reason, _}) ->
    io:format(standard_error, "crashed: ~p:~p~n", [Class, Reason]),
    exit_with(1);
%% Private is the default (F12), so a module nobody has marked exports
%% nothing, and the clause below would print "the module exports " with an
%% empty list after it. The empty case is its own sentence and teaches the one
%% word being asked for.
report_run({error, {ambiguous, []}}) ->
    io:format(standard_error,
              "bsc: this module exports nothing, so there is no function to run~n"
              "  a signature with no `public` in front of it is private, and a~n"
              "  private function is not exported. Mark the one you want to run~n"
              "  `public`.~n", []),
    exit_with(2);
report_run({error, {ambiguous, Names}}) ->
    io:format(standard_error,
              "bsc: which function? the module exports ~s~n"
              "  bsc FILE.bs FUNCTION ARG...~n",
              [lists:join(", ", [atom_to_list(N) || N <- Names])]),
    exit_with(2);
%% Exit 2 rather than 1: as with `ambiguous` and `bad_arity`, the compiler
%% succeeded and the INVOCATION is wrong (F12).
report_run({error, {private, Mod, Fn}}) ->
    io:format(standard_error,
              "bsc: ~s is private in ~s~n"
              "  it is defined, and not exported, so it cannot be called from~n"
              "  outside its module. Mark it `public` to run it directly.~n",
              [Fn, Mod]),
    exit_with(2);
report_run({error, {bad_arity, Fn, Got, Want}}) ->
    io:format(standard_error, "bsc: ~s takes ~s argument(s), got ~p~n",
              [Fn, lists:join(" or ", [integer_to_list(A) || A <- Want]), Got]),
    exit_with(2);
%% The reader already built the sentence; the generic clause's `~p` would
%% print it as a list of character codes.
report_run({error, {unreadable_argument, Msg}}) ->
    io:format(standard_error, "bsc: ~ts~n", [Msg]),
    exit_with(2);
report_run({error, R}) ->
    io:format(standard_error, "bsc: ~p~n", [R]),
    exit_with(1).

repl(File, Opts0) ->
    Opts = case Opts0#opts.outdir of
               "." -> Opts0#opts{outdir = tmpdir()};
               _   -> Opts0
           end,
    case compile_set([File], Opts) of
        {ok, Beams} ->
            Beam = beam_for(File, Beams),
            Dir = filename:dirname(Beam),
            Mod = list_to_atom(filename:basename(Beam, ".beam")),
            true = code:add_patha(Dir),
            {module, Mod} = code:ensure_loaded(Mod),
            bs_repl:start(File, Dir, Mod),
            exit_with(0);
        _ ->
            exit_with(1)
    end.

%% The scratch directory is named for this OS process, because
%% `unique_integer` alone restarts with every VM (12 distinct values from 30
%% fresh VMs, ENG-318) and two runs without `-o` could share one `Fib.beam`.
%% The counter still separates two calls within one VM.
tmpdir() ->
    Base = case os:getenv("TMPDIR") of false -> "/tmp"; T -> T end,
    Dir = filename:join(Base, "bsc-" ++ os:getpid() ++ "-" ++
                              integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_dir(filename:join(Dir, "x")),
    Dir.

%%% ---------------------------------------------------------------------------
%%% Compiling a file
%%% ---------------------------------------------------------------------------

file(Path) -> file(Path, #opts{}).

%% Naming a file names its module, and its module is its directory (F15):
%% compiling `Shop/Orders/Total.bs` alone would emit a `'Shop.Orders'` beam
%% missing every sibling file's function, so this goes through the set path.
%% The path check does not run here; see `check_path` on `#opts{}`.
file(Path, Opts) ->
    case filelib:is_file(Path) of
        true  -> compile_set([Path], Opts#opts{check_path = false});
        false -> report_fatal(Path, {cannot_read, enoent}), {error, enoent}
    end.

compile_string(Src, Opts) -> compile_string(Src, Opts, "<string>").

compile_string(Src, Opts, Path) ->
    with_stages(Path, Opts, Src).

with_stages(Path, Opts, Src) ->
    case parse_string(Path, Src) of
        {error, R}  -> {error, R};
        %% The one single-source caller: a string has no directory to
        %% aggregate and no path to check against.
        {ok, Decls} ->
            check_and_emit(filename:dirname(Path), [{Path, Decls}],
                           Opts#opts{check_path = false}, #{})
    end.

parse_string(Path, Src) ->
    case bs_lexer:string(Src) of
        {error, Err, _} ->
            report_fatal(Path, {lex, Err}), {error, lex};
        {ok, Tokens, _} ->
            case bs_parser:parse(Tokens) of
                %% The tokens travel with the error because the hint for a
                %% `not` in prefix position is a SHAPE in the token stream,
                %% not the token yecc stopped on (ticket 63). `bs_diag` falls
                %% back to the plain parse error when the shape is absent.
                {error, Err} ->
                    report_fatal(Path, {parse, Err, Tokens}), {error, parse};
                %% Valves are lowered here, between parsing and everything
                %% else, because their lowering needs names unique across the
                %% FILE and a yecc action has nowhere to keep a counter (F14).
                %% No later stage sees an unlowered `e_valve`.
                {ok, Decls} ->
                    {ok, bs_lower:valves(Decls)}
            end
    end.

parse_path(Path) ->
    case file:read_file(Path) of
        {ok, Bin}  -> parse_string(Path, binary_to_list(Bin));
        {error, R} -> report_fatal(Path, {cannot_read, R}), {error, R}
    end.

%% The same with nothing reported, for the module index: an unrelated broken
%% file must not stop the build of the files that were asked for.
parse_quietly(Path) ->
    case file:read_file(Path) of
        {ok, Bin} ->
            case bs_lexer:string(binary_to_list(Bin)) of
                {ok, Tokens, _} ->
                    case bs_parser:parse(Tokens) of
                        {ok, Decls} -> {ok, bs_lower:valves(Decls)};
                        _           -> error
                    end;
                _ -> error
            end;
        _ -> error
    end.

check_and_emit(Dir, Sources, Opts, World) ->
    %% The checker raises a handful of conditions found while RESOLVING types,
    %% below the level that carries a line and a function name. They are
    %% caught here so they reach the author as a diagnostic, not a stack trace.
    try bs_check:check_dir(Sources, World, expect(Dir, Opts)) of
        {error, Diags} ->
            %% Each diagnostic arrives tagged with the file it came from,
            %% which is why the checker runs its function pass per file (F15).
            [report(P, D) || {P, D} <- Diags],
            {error, check};
        {ok, Module, Diags} ->
            [report(P, D) || {P, D} <- Diags],
            emit(Dir, Opts, Module)
    catch
        error:Reason when is_tuple(Reason) ->
            case resolve_error(primary(Dir, Sources), Reason) of
                handled  -> {error, check};
                unhandled -> erlang:error(Reason)
            end
    end.

%% A RAISED condition is reported against the module's declaration file,
%% `index.bs` when there is one, since it was found over the whole directory
%% and carries no path of its own. A raise site that can do better wraps
%% itself in `{in_file, Path, …}`.
primary(_Dir, [{P, _} | _]) when is_list(P) -> P;
primary(Dir, _)                             -> Dir.

expect(_Dir, #opts{check_path = false}) -> undefined;
expect(Dir, #opts{src_root = Root})     -> expected_module(Dir, Root).

%% The raise path is not a second channel: a raised condition gets a
%% descriptor exactly like a returned one, and `bs_diag` owns both shape and
%% prose (F16). `unhandled` means re-raise, so a tuple `bs_diag` has no
%% clause for is not swallowed.
resolve_error(Path, Reason) ->
    case bs_diag:descriptor(Path, Reason) of
        unhandled -> unhandled;
        Desc      -> bs_diag:emit(bs_diag:channel(), Desc), handled
    end.

emit(_Path, Opts = #opts{outdir = Dir}, Module) ->
    Forms = bs_emit:forms(Module),
    Mod = maps:get(module, Module),
    %% The file must be named for the module atom: `erlc` enforces
    %% module-name/filename matching on the `from_abstr` path (ticket 13).
    AbstrPath = filename:join(Dir, atom_to_list(Mod) ++ ".abstr"),
    ok = filelib:ensure_dir(AbstrPath),
    ok = file:write_file(AbstrPath, bs_emit:to_abstr(Forms)),
    verbose(Opts, "wrote ~s~n", [AbstrPath]),
    build(AbstrPath, Dir, Opts).

%% OTP does the translation from serialised text, with no `.erl` anywhere on
%% disk (ticket 13). `compile:file/2` with `from_abstr` is the function `erlc`
%% itself calls, run in-process over the same `.abstr` on disk, so `.abstr`
%% plus an external `erlc` always works; a second VM per module was two
%% thirds of a block's cost (ENG-314). The compiler's report text is captured
%% and still arrives on stderr, under the `compile: ` prefix.
build(AbstrPath, Dir, Opts) ->
    Options = [from_abstr, debug_info, {outdir, Dir},
               report_errors, report_warnings],
    {Outcome, {_Stdout, _Stderr, Merged}} =
        bs_capture:run(fun() -> compile:file(AbstrPath, Options) end, infinity),
    Out = case unicode:characters_to_list(Merged) of
              L when is_list(L) -> L;
              _                 -> binary_to_list(Merged)
          end,
    Beam = filename:rootname(AbstrPath) ++ ".beam",
    %% The compiler reports warnings on the same stream as errors, so its
    %% return value is the only honest discriminator.
    case Outcome of
        {ok, {ok, _Mod}} ->
            case string:trim(Out) of
                ""   -> ok;
                Warn -> io:format(standard_error, "compile: ~ts~n", [Warn])
            end,
            verbose(Opts, "built ~s~n", [Beam]),
            {ok, Beam};
        {ok, _Failed} ->
            io:format(standard_error, "compile: ~ts~n", [Out]),
            {error, {compile, Out}};
        {crashed, Class, Reason} ->
            Text = Out ++ lists:flatten(io_lib:format("~w:~p", [Class, Reason])),
            io:format(standard_error, "compile: ~ts~n", [Text]),
            {error, {compile, Text}}
    end.

verbose(#opts{verbose = true}, F, A) -> io:format(F, A);
verbose(_, _, _) -> ok.


%%% ---------------------------------------------------------------------------
%%% Diagnostics
%%%
%%% A diagnostic is a TERM and prose is a pure function of it, so every
%%% message this compiler prints lives in `bs_diag` (F16, ticket 23 §1). What
%%% is left here is the call sites: a diagnostic is reported from where the
%%% checking happened and rendered from exactly one place. A new site calling
%%% `io:format` directly would pass every test with the prose still right,
%%% which is why `bin/check-diagnostics.sh` exists.
%%% ---------------------------------------------------------------------------

report(Path, Diag)       -> publish(Path, Diag).

report_fatal(Path, Reason) -> publish(Path, Reason).

%% A shape `bs_diag` does not know is still reported rather than crashing,
%% because the alternative is a stack trace when the compiler is already lost.
publish(Path, D) ->
    Desc = case bs_diag:descriptor(Path, D) of
               unhandled -> #{tag => unclassified, severity => error,
                              file => Path, detail => D};
               Found     -> Found
           end,
    bs_diag:emit(bs_diag:channel(), Desc).
