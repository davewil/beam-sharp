%%% bsc — the beam-sharp walking-skeleton compiler.
%%%
%%%     .bs  ->  lex  ->  parse  ->  exhaustiveness check  ->  abstract format
%%%          ->  erlc +from_abstr  ->  .beam
%%%
%%% The slice deliberately covers only decisions the map has closed: multi-clause
%%% heads under a mandatory signature (01, 04, 08), atoms and structural unions
%%% (09, 10), the type algebra with exact unions and real integer intervals (20),
%%% the retained failure arm (12), and Abstract Format emission with a `-spec`
%%% (13). Records (26), generic syntax (28), modules and imports (fog), FFI and
%%% OTP behaviours are all out of the slice on purpose.

-module(bsc).

-export([main/1, file/1, file/2, file_to_dir/2, compile_string/2]).
%% F15 — exported so the corpus gates enumerate module directories through the
%% SAME function the compiler classifies with, rather than through a second
%% wildcard of their own. Same reason `bs_check:resolve/2` is exported instead of
%% copied: a classification rule with two implementations has two answers.
%% F17 — `bs_api` is the second reader of those same rules, which is why
%% `expected_module/2`, `parse_path/1` and `module_dir_of/1` join them here
%% rather than being written a second time inside the query mode: the module
%% a path implies (41 §5), the parse that publishes its own diagnostics, and
%% "naming a file names its module" are all rules this file already owns.
-export([module_dirs/1, dir_kind/1, expected_module/2, parse_path/1,
         module_dir_of/1]).

-record(opts, {outdir = ".", emit_abstr = true, verbose = false, repl = false,
               %% F15 / ticket 41 §3. The source root is a BUILD-TOOL input, and
               %% §3 said so before anything needed it: "a build tool's job is
               %% which files, WHERE THE SOURCE ROOT IS, and what to do with the
               %% output — not in what sequence". `undefined` means the default
               %% below, not "no check".
               src_root = undefined,
               %% Ticket 41 §5's check needs a source root, and a caller that
               %% hands over a bare path has not named one. The CLI always has a
               %% root (the flag, or the module directory's parent by default) and
               %% always checks; `file/2` is a library entry point that does not,
               %% so it aggregates the directory WITHOUT the path check rather
               %% than inventing a root to check against.
               check_path = true,
               %% F16 / ticket 23 §1. The channel the CLI publishes on.
               diagnostics = prose,
               %% F17 / ticket 23 §10. The query mode: report what a module
               %% offers, rather than compiling it.
               api = false}).

%% Ticket 43's threshold. One number, used at both depths the inexhaustive
%% diagnostic enumerates — see `heads/2` and `truncated/1` at the bottom of the
%% file. It is not a tunable and there is no flag: the truncated form IS the
%% exact form at three cases or fewer, so "always on" costs a small residual
%% nothing and there is no second shape to switch into.
-define(RESIDUAL_CASES, 3).

%% For callers outside the CLI (the REPL's `:reload`) that have a directory
%% rather than an #opts{}.
file_to_dir(Path, Dir) -> file(Path, #opts{outdir = Dir}).

%%% ---------------------------------------------------------------------------
%%% CLI
%%% ---------------------------------------------------------------------------

main([]) ->
    io:format("usage: bsc [-o DIR] [-v] [--src-root DIR] [--diagnostics term]~n"
              "           [--api] PATH [FUNCTION] [ARG...]~n"
              "  PATH is a module, which is a DIRECTORY — naming one of its~n"
              "  files means the same thing. With no ARGs it compiles; with~n"
              "  ARGs it compiles then runs:~n"
              "      bsc examples/Fib 5~n"
              "      bsc --src-root examples examples/Shop/Reports Restate 3~n"
              "  --api reports what operations the module offers, in~n"
              "  beam-sharp's own types and with nothing built:~n"
              "      bsc --api examples/Counter~n"),
    halt(2);
main(Args) ->
    {Opts, Files, Argv} = parse_args(Args, #opts{}, []),
    %% F16 — set HERE and nowhere else. A library caller and every
    %% in-process test therefore gets `prose`, and cannot be polluted by
    %% another test: the CLI is a fresh OS process every time it runs.
    %%
    %% REFUSED IN THE REPL RATHER THAN IGNORED THERE. `ibs` prints values on
    %% stdout, so the flag's own contract — stdout carries descriptors — cannot
    %% hold, and a consumer redirecting the stream would get a mix. Accepting a
    %% flag and quietly not honouring it is the worse of the two failures: it
    %% costs the flag its credibility everywhere else it is used.
    case {Opts#opts.repl, Opts#opts.diagnostics} of
        {true, term} ->
            io:format(standard_error,
                      "bsc: --diagnostics term is not available in the REPL~n"
                      "  the prompt prints values on stdout, so a descriptor~n"
                      "  there would be indistinguishable from a result.~n", []),
            halt(2);
        _ -> ok
    end,
    %% F17 — AND `--api` IS REFUSED THERE FOR THE SAME REASON, not silently
    %% preferred. The query answers and exits; the prompt is a session over a
    %% module. Honouring one and dropping the other is the failure the clause
    %% above exists to avoid: a flag accepted and not honoured costs the flag
    %% its credibility everywhere else it is used.
    case {Opts#opts.repl, Opts#opts.api} of
        {true, true} ->
            io:format(standard_error,
                      "bsc: --api is not available in the REPL~n"
                      "  the query answers and exits; the prompt is a session~n"
                      "  over a module. Ask for one or the other.~n", []),
            halt(2);
        _ -> ok
    end,
    bs_diag:set_channel(Opts#opts.diagnostics),
    %% F17 / ticket 23 §10 — BEFORE the REPL and before the compile path,
    %% because `--api` does neither: it reads source and reports what the
    %% module offers. `bs_api:answer/3` halts, so this returns only when the
    %% flag was absent.
    case Opts#opts.api of
        true  -> bs_api:answer(Files, Argv, Opts#opts.src_root);
        false -> ok
    end,
    case {Opts#opts.repl, Files, Argv} of
        {true, [File], _} -> repl(File, Opts);
        {true, [], _} ->
            io:format(standard_error, "usage: ibs -S FILE.bs~n", []),
            halt(2);
        {false, F, A} -> compile_or_run(F, A, Opts)
    end.

compile_or_run(Files, Argv, Opts) ->
    case {Files, Argv} of
        %% F15 — a NAMESPACE named on the command line reaches here, because
        %% `is_path_arg/1` only counts a directory as a path if it is a module.
        %% Falling through to the usage text would answer a precise mistake with
        %% a general message; 41 §5 gives it an exact name, so use it.
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
                    halt(2);
                false -> main([])
            end;
        {[], _}           -> main([]);
        {[File], [_ | _]} -> run(File, Opts, Argv);
        {_, [_ | _]}     ->
            io:format(standard_error, "bsc: cannot run more than one file~n", []),
            halt(2);
        {_, []}          -> compile_only(Files, Opts)
    end.

compile_only(Files, Opts) ->
    case compile_set(Files, Opts) of
        {ok, _Beams} -> halt(0);
        {error, _}   -> halt(1)
    end.

%%% ---------------------------------------------------------------------------
%%% F11 — compiling a SET of modules, in dependency order
%%%
%%% Ticket 41 §3, fork A: the compiler resolves `using` edges itself, checks a
%%% dependency before its dependents, and keeps the dependency's signatures in
%%% one environment threaded through the build. No artefact, nothing to go
%%% stale, correct by construction.
%%%
%%% The ticket's own opening premise — "the compiler is single-file" — was FALSE
%%% and the correction is what made this cheap: `compile_only/2` was already a
%%% map over a file list. What was single-file was the ENVIRONMENT, not the
%%% invocation, so this is the fold that loop already was, carrying an
%%% accumulator. No new CLI, no new entry point, no new artefact.
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
                                     %% F12 — carried BESIDE the exports, not
                                     %% subtracted from them, so a dependent's
                                     %% refusal can say `private` rather than
                                     %% `unknown`.
                                     private => bs_check:private_of(Decls),
                                     behaviours => [B || {behaviour, _, B} <- Decls]}},
            build(Rest, Opts, World1, [{Dir, Beam} | Acc]);
        Error ->
            Error
    end.

decls(Sources) -> lists:append([D || {_, D} <- Sources]).

%% The given module directories, plus every module they reach through `using`. A
%% dependency that was not named on the command line is found in the source tree —
%% which is 41 §3's "`using Shop.Orders` is a path on disk; `bsc` resolves it".
load_all(Paths, Opts) ->
    Dirs = lists:usort([module_dir_of(P) || P <- Paths]),
    case parse_all(Dirs) of
        {error, R} -> {error, R};
        {ok, Given} ->
            Index = source_index(Dirs, Opts#opts.src_root),
            close_over(Given, Index, [M || {_, _, M} <- Given])
    end.

%% WHAT A `using` LINE ACTUALLY DEPENDS ON, which is not always what it names.
%%
%% 41 §5 decides the tier by what the path resolves to rather than by its
%% spelling, so `using Shop` may name a NAMESPACE — and a namespace is erased,
%% meaning the real dependencies are the modules underneath it. Both discovery
%% and ordering need that expansion: without it `using Shop` pulled in nothing,
%% and `Shop.Reports` was checked against a world that had never heard of
%% `Shop.List`.
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

%% F15 — a unit is now `{Dir, [{Path, Decls}], Mod}` rather than one file's
%% `{Path, Decls, Mod}`. The per-file list survives all the way to the checker and
%% the emitter, because both need to know which file a thing came from: the
%% checker to put a diagnostic beside the right path, the emitter to put 13 §3's
%% `file` attribute in front of the right functions.
%% THIS IS REACHED BY A PATH THAT DOES NOT EXIST, which is not the case it looks
%% like it is for. `is_path_arg/1` keeps a real namespace out and
%% `compile_or_run/3` names that mistake, so the way in is an unmatched shell
%% glob: `bsc examples/*.bs` with no top-level `.bs` files passes the literal
%% string through, the `.bs` extension makes it a file argument, and its
%% directory holds no sources. Two of this repo's own gate scripts did exactly
%% that, and the first version of this function answered them with
%% `no match of right hand side value namespace` — an escript stack trace, from
%% a mistake with an obvious sentence attached to it.
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
%%% F15 — what a directory IS. Ticket 41 §5's classification, in ONE function.
%%%
%%%   a directory holding `.bs` files -> a MODULE, and those files are its source
%%%   a directory holding only dirs   -> a NAMESPACE: no atom, no beam, nothing
%%%
%%% Decidable by `ls`, no marker and no keyword, which is 41 §5 verbatim.
%%%
%%% IT IS ONE FUNCTION BECAUSE TWO WOULD DISAGREE. Before F15 the source index
%%% globbed `**/*.bs` from each root while a per-directory unit would naturally
%%% glob `*.bs`, and the two answers differ for exactly the file that matters: one
%%% sitting in a SUBDIRECTORY of a module directory. The index would map its
%%% module atom to a path, `using` would resolve against it, and the unit former
%%% would never compile it — a call the checker passes and the runtime cannot
%%% make. That is the `undef`-from-green-source shape F11 already hit once, and
%%% the repo's answer to it is the same every time: resolve once, in one place.
%%% ---------------------------------------------------------------------------

dir_kind(Dir) ->
    case bs_here(Dir) of
        []    -> namespace;
        Files -> {module, Files}
    end.

%% NON-RECURSIVE, and that is the whole of F15.11. A subdirectory is its own
%% directory and gets its own classification: `Shop/` may hold `.bs` files AND a
%% `Collections/` subdirectory, in which case `Shop` is a module and what is under
%% `Collections` is decided by applying this same rule again.
%%
%% `index.bs` sorts FIRST, which is not cosmetic. 41 §4 makes it the declaration
%% file, so at the head of the list its `module` line and its `using` lines are the
%% first the checker sees — and every sibling file that declares no module of its
%% own then inherits from it.
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

%% The module directory a command-line argument names: itself if it is one, and
%% otherwise the directory the named file sits in. Naming a file names its module,
%% which is what keeps `bsc examples/Fib/fib.bs 5` working now that the unit is the
%% directory.
module_dir_of(P) ->
    case filelib:is_dir(P) of
        true  -> P;
        false -> filename:dirname(P)
    end.

%% Module atom -> module DIRECTORY, over every module directory under the roots.
%%
%% BUILT BY PARSING RATHER THAN BY NAMING. Resolving `Shop.Orders` to
%% `Shop/Orders` would be cheaper and would still be wrong to rely on here: the
%% index has to answer for the tree as it IS, including a directory whose
%% declaration does not match its path, because that mismatch is a diagnostic
%% F15 wants to report rather than a file it wants to lose. A directory that
%% fails to parse is skipped: it is not a dependency anybody asked for, and if it
%% is, the error arrives when it is compiled.
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
%%% F15 — the module atom a DIRECTORY PATH implies, which is what ticket 41 §5's
%%% check compares a declaration against.
%%%
%%% THE DEFAULT ROOT IS THE MODULE DIRECTORY'S OWN PARENT, not the cwd. That
%%% makes a single-segment module need no flag — `bsc examples/Fib` checks `Fib`
%%% against `module Fib` — and makes a multi-segment one fail LOUDLY until a root
%%% is named: `bsc examples/Shop/Reports` defaults to a root of `examples/Shop`,
%%% expects `module Reports`, finds `module Shop.Reports` and says so.
%%%
%%% That is the property a default here has to have. It is never silently weaker
%%% than the explicit form, and it teaches the flag at the moment the flag is
%%% needed. The cwd was the other candidate and loses on the same test: every
%%% gate in this repo runs from a directory that is not the source root, so
%%% `examples/Fib` would have had to declare `module examples.Fib`.
%%%
%%% A SUFFIX MATCH WAS THE OTHER TEMPTING READING AND IT IS A WEAKER RULE, not a
%%% cheaper one — it needs no root at all and it ACCEPTS `Shop/Orders/Total.bs`
%%% declaring `module Orders`, because `Orders` is a suffix of `…/Shop/Orders`. A
%%% module quietly dropping its leading segments mints a different atom, which is
%%% the drift between 40 §1's atom and the path on disk that §5 exists to stop.
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

%% Absolute and `..`-free, so that a root given as `examples` and a directory
%% reached as `./examples/Fib` still share a prefix. Without this the check
%% silently does not apply, which is the one outcome a check must never have.
norm(Path) ->
    lists:foldl(fun("..", [_ | Up]) -> Up;
                   ("..", [])       -> [];
                   (".", Acc)       -> Acc;
                   (Seg, Acc)       -> Acc ++ [Seg]
                end, [], filename:split(filename:absname(Path))).

%% Dependencies before dependents. A cycle is refused BY NAME rather than
%% followed — F6's cyclic-alias precedent, which shipped after a hang that no
%% green suite could see, and the same hazard is here.
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
                    %% `D =/= M` because a namespace expands to everything under
                    %% it, and a module sitting in the namespace it imports is
                    %% under it too. Without this `module Shop.Reports` with
                    %% `using Shop` depended on itself and was reported as a
                    %% cycle with one member, twice.
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

%% Bare arguments ending in `.bs` are files; the first that does not begins the
%% run argv, so `bsc fib.bs 5` and `bsc a.bs b.bs` both read correctly without a
%% separator.
parse_args(["-o", Dir | Rest], O, Fs) -> parse_args(Rest, O#opts{outdir = Dir}, Fs);
parse_args(["-v" | Rest], O, Fs)      -> parse_args(Rest, O#opts{verbose = true}, Fs);
parse_args(["--repl" | Rest], O, Fs)  -> parse_args(Rest, O#opts{repl = true}, Fs);
%% `-S FILE` is iex's spelling and costs nothing to accept; the file is picked up
%% by the ordinary bare-argument rule below.
parse_args(["-S" | Rest], O, Fs)      -> parse_args(Rest, O, Fs);
%% F15 / ticket 41 §3: "a build tool's job is which files, WHERE THE SOURCE ROOT
%% IS, and what to do with the output — not in what sequence to compile them."
parse_args(["--src-root", Dir | Rest], O, Fs) ->
    parse_args(Rest, O#opts{src_root = Dir}, Fs);
%% F16 / ticket 23 §1. The ticket names no flag anywhere — it says only
%% that "the CLI publishes both" — so the spelling is F16's, and it splits
%% by STREAM: prose stays on stderr, the term goes to stdout, and a
%% consumer redirects rather than parses.
parse_args(["--diagnostics", "term" | Rest], O, Fs) ->
    parse_args(Rest, O#opts{diagnostics = term}, Fs);
parse_args(["--diagnostics", "prose" | Rest], O, Fs) ->
    parse_args(Rest, O#opts{diagnostics = prose}, Fs);
%% F17 / ticket 23 §10. A query rather than a compilation, so it takes no
%% argument of its own: the module it answers about is the ordinary PATH
%% argument every other mode already takes.
parse_args(["--api" | Rest], O, Fs)   -> parse_args(Rest, O#opts{api = true}, Fs);
parse_args(["--diagnostics", Other | _], _O, _Fs) ->
    io:format(standard_error,
              "bsc: --diagnostics takes `prose` or `term`, not ~s~n", [Other]),
    halt(2);
parse_args([A | Rest], O, Fs) ->
    case is_path_arg(A) of
        true  -> parse_args(Rest, O, [A | Fs]);
        false -> {O, lists:reverse(Fs), [A | Rest]}
    end;
parse_args([], O, Fs)                 -> {O, lists:reverse(Fs), []}.

%% A `.bs` file, or a DIRECTORY THAT IS A MODULE — 41 §3 names both as inputs:
%% "`bsc` is given a set of `.bs` files (as it already is) or a directory to walk".
%%
%% The module test matters and is not pedantry. Bare arguments that are not paths
%% begin the run argv, so `bsc examples/Fib Fib 5` must not read `Fib` as a
%% directory just because something called `Fib` happens to exist in the cwd. A
%% directory only counts if it actually holds `.bs` files.
is_path_arg(A) ->
    filename:extension(A) =:= ".bs"
        orelse (filelib:is_dir(A) andalso dir_kind(A) =/= namespace).

%%% ---------------------------------------------------------------------------
%%% Running
%%%
%%% Development is driven by runnable code (David, 2026-08-14): `bsc fib.bs 5`
%%% should print Fib of 5 without a second `erl -pa` invocation.
%%% ---------------------------------------------------------------------------

run(File, Opts0, Argv) ->
    Opts = case Opts0#opts.outdir of
               "." -> Opts0#opts{outdir = tmpdir()};
               _   -> Opts0
           end,
    %% F11 — through the SET path, not `file/2`. A file with a `using` line needs
    %% its dependencies compiled and on the code path before it can run, and the
    %% same is true at the `ibs` prompt below. Four features in a row found a
    %% hole at that prompt because a new capability was wired into the compile
    %% path and not into this one.
    case compile_set([File], Opts) of
        {ok, Beams} ->
            Beam = beam_for(File, Beams),
            Mod = list_to_atom(filename:basename(Beam, ".beam")),
            report_run(bs_run:run(filename:dirname(Beam), Mod, Argv));
        _ ->
            halt(1)
    end.

%% F15 — the build's results are keyed by MODULE DIRECTORY, because that is the
%% unit now. The argument may still be a file, and `bsc fib.bs 5` and `ibs -S
%% fib.bs` both arrive here with one.
%%
%% THIS IS THE SIXTH FEATURE TO FIND A HOLE AT THIS SEAM and the comment on
%% `run/3` above predicted it in so many words: a capability gets wired into the
%% compile path and not into this one. It was a `no match of right hand side
%% value false` at the `ibs` prompt — an escript stack trace, which is the worst
%% diagnostic this compiler produces.
beam_for(Path, Beams) ->
    {_, Beam} = lists:keyfind(module_dir_of(Path), 1, Beams),
    Beam.

report_run({ok, Value}) ->
    io:format("~s~n", [bs_run:format_value(Value)]),
    halt(0);
report_run({crashed, error, {Tag, Detail}, _}) when is_atom(Tag) ->
    io:format(standard_error, "crashed: ~p ~s~n", [Tag, bs_run:format_value(Detail)]),
    halt(1);
report_run({crashed, Class, Reason, _}) ->
    io:format(standard_error, "crashed: ~p:~p~n", [Class, Reason]),
    halt(1);
%% F12, amended 2026-08-17 — THE MOMENT THE DEFAULT BITES.
%%
%% Private is now the default, so a module nobody has marked exports nothing and
%% the clause below would print "the module exports " with an empty list after
%% it. Measured on a fresh one-function module: `erlc` first says
%% `function 'Go'/1 is unused` — because an unexported function nothing calls is
%% deleted — and then this prints a question with no answers in it. That is the
%% default arriving at exactly the moment the language is least able to explain
%% itself, and the harness exists to make code runnable.
%%
%% So the empty case is its own sentence, and it teaches the one word being
%% asked for rather than reporting an absence.
report_run({error, {ambiguous, []}}) ->
    io:format(standard_error,
              "bsc: this module exports nothing, so there is no function to run~n"
              "  a signature with no `public` in front of it is private, and a~n"
              "  private function is not exported. Mark the one you want to run~n"
              "  `public`.~n", []),
    halt(2);
report_run({error, {ambiguous, Names}}) ->
    io:format(standard_error,
              "bsc: which function? the module exports ~s~n"
              "  bsc FILE.bs FUNCTION ARG...~n",
              [lists:join(", ", [atom_to_list(N) || N <- Names])]),
    halt(2);
%% F12. Exit 2 rather than 1: this is the same class as `ambiguous` and
%% `bad_arity` above — the compiler succeeded and the INVOCATION is wrong.
report_run({error, {private, Mod, Fn}}) ->
    io:format(standard_error,
              "bsc: ~s is private in ~s~n"
              "  it is defined, and not exported, so it cannot be called from~n"
              "  outside its module. Mark it `public` to run it directly.~n",
              [Fn, Mod]),
    halt(2);
report_run({error, {bad_arity, Fn, Got, Want}}) ->
    io:format(standard_error, "bsc: ~s takes ~s argument(s), got ~p~n",
              [Fn, lists:join(" or ", [integer_to_list(A) || A <- Want]), Got]),
    halt(2);
%% The reader already built the sentence; printing it with `~p` would hand back
%% a list of character codes, which is the generic clause below doing exactly
%% the kind of damage this message exists to undo.
report_run({error, {unreadable_argument, Msg}}) ->
    io:format(standard_error, "bsc: ~ts~n", [Msg]),
    halt(2);
report_run({error, R}) ->
    io:format(standard_error, "bsc: ~p~n", [R]),
    halt(1).

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
            halt(0);
        _ ->
            halt(1)
    end.

tmpdir() ->
    Base = case os:getenv("TMPDIR") of false -> "/tmp"; T -> T end,
    Dir = filename:join(Base, "bsc-" ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_dir(filename:join(Dir, "x")),
    Dir.

%%% ---------------------------------------------------------------------------
%%% Compiling a file
%%% ---------------------------------------------------------------------------

file(Path) -> file(Path, #opts{}).

%% F15 — NAMING A FILE NAMES ITS MODULE, and its module is now its directory.
%%
%% This used to read one file and compile it alone, which was the same thing when
%% one file was one module. It is not any more: compiling `Shop/Orders/Total.bs`
%% by itself emits a `'Shop.Orders'` beam with `Apply/1` missing from it — a beam
%% that loads, exports less than the module declares, and fails at the call site.
%%
%% So it goes through the set path like everything else. The path check does not
%% run here; see `check_path` on `#opts{}`.
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
        %% The one remaining single-source caller, and legitimately so: a string
        %% has no directory to aggregate and no path to check against.
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
                %% The tokens travel with the error because ticket 63's hint is
                %% a SHAPE in the token stream (`not` in prefix position), not
                %% the token yecc happened to stop on — guard and refinement
                %% stop on different ones. `bs_diag` falls back to the plain
                %% parse error when the shape is absent.
                {error, Err} ->
                    report_fatal(Path, {parse, Err, Tokens}), {error, parse};
                %% F14. The valve is the one construct the parser cannot finish
                %% on its own — its lowering needs names that are unique across
                %% the FILE, and a yecc action has nowhere to keep a counter. So
                %% it lands here, between parsing and everything else, and no
                %% later stage ever sees an unlowered `e_valve`.
                {ok, Decls} ->
                    {ok, bs_lower:valves(Decls)}
            end
    end.

parse_path(Path) ->
    case file:read_file(Path) of
        {ok, Bin}  -> parse_string(Path, binary_to_list(Bin));
        {error, R} -> report_fatal(Path, {cannot_read, R}), {error, R}
    end.

%% The same, with nothing reported — used only to build the module index, where
%% an unrelated broken file must not stop the build of the files that were asked
%% for.
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
    %% The checker signals a handful of conditions by raising rather than by
    %% returning a diagnostic, because they are found while RESOLVING types —
    %% below the level that carries a line and a function name. Uncaught, they
    %% reached the author as an escript stack trace, which is the worst
    %% diagnostic this compiler produced: found by running LANGUAGE.md's own
    %% examples through it, where two blocks hit `unknown_type`.
    try bs_check:check_dir(Sources, World, expect(Dir, Opts)) of
        {error, Diags} ->
            %% F15 — each diagnostic arrives already tagged with the file it came
            %% from, which is why the checker runs its function pass per file.
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

%% Which file a RAISED condition is reported against. The returned diagnostics
%% carry their own path; these are found while resolving over the whole
%% directory's declarations, so the best available answer is the module's
%% declaration file — `index.bs` when there is one, since `bs_here/1` sorts it
%% first. A raise site that can do better wraps itself in `{in_file, Path, …}`.
primary(_Dir, [{P, _} | _]) when is_list(P) -> P;
primary(Dir, _)                             -> Dir.

expect(_Dir, #opts{check_path = false}) -> undefined;
expect(Dir, #opts{src_root = Root})     -> expected_module(Dir, Root).

%% F16 / ticket 23 §1 — THE RAISE PATH IS NOT A SECOND CHANNEL. A raised
%% condition gets a descriptor exactly like a returned one, and `bs_diag`
%% owns both its shape and its prose. `unhandled` still means re-raise: a
%% raised tuple with no clause there would otherwise be swallowed, and what
%% the author sees instead is an escript stack trace.
resolve_error(Path, Reason) ->
    case bs_diag:descriptor(Path, Reason) of
        unhandled -> unhandled;
        Desc      -> bs_diag:emit(bs_diag:channel(), Desc), handled
    end.

emit(_Path, Opts = #opts{outdir = Dir}, Module) ->
    Forms = bs_emit:forms(Module),
    Mod = maps:get(module, Module),
    %% Ticket 13 measured that `erlc` enforces module-name/filename matching on
    %% the `from_abstr` path, so the file must be named for the module atom.
    AbstrPath = filename:join(Dir, atom_to_list(Mod) ++ ".abstr"),
    ok = filelib:ensure_dir(AbstrPath),
    ok = file:write_file(AbstrPath, bs_emit:to_abstr(Forms)),
    verbose(Opts, "wrote ~s~n", [AbstrPath]),
    build(AbstrPath, Dir, Opts).

%% The whole point of ticket 13's contract: OTP does the translation, from
%% serialised text, with no `.erl` anywhere on disk.
build(AbstrPath, Dir, Opts) ->
    Cmd = lists:flatten(io_lib:format("erlc +from_abstr +debug_info -o ~s ~s",
                                      [Dir, AbstrPath])),
    {Rc, Out} = bs_process:run_merged(Cmd),
    Beam = filename:rootname(AbstrPath) ++ ".beam",
    %% erlc reports warnings on the same stream as errors, so the exit status is
    %% the only honest discriminator — treating any output as failure made the
    %% first green build look red.
    case Rc of
        0 ->
            case string:trim(Out) of
                ""   -> ok;
                Warn -> io:format(standard_error, "erlc: ~s~n", [Warn])
            end,
            verbose(Opts, "built ~s~n", [Beam]),
            {ok, Beam};
        _ ->
            io:format(standard_error, "erlc: ~s~n", [Out]),
            {error, {erlc, Out}}
    end.

verbose(#opts{verbose = true}, F, A) -> io:format(F, A);
verbose(_, _, _) -> ok.


%%% ---------------------------------------------------------------------------
%%% Diagnostics
%%%
%%% Ticket 04 established that the exhaustiveness residual *is* the missing case,
%%% and ticket 23 decided the rest: the diagnostic is a TERM and prose is a pure
%%% function of it. F16 built that, and it moved every message this compiler can
%%% print into `bs_diag` — including the head synthesis, which is a real
%%% compilation step (23 §2) rather than a printing detail.
%%%
%%% What is left here is the two call sites, because a diagnostic is reported
%%% from where the checking happened and rendered from exactly one place.
%%% `bin/check-diagnostics.sh` is what keeps it that way: the drift this closes
%%% reopens silently, since a new site calling `io:format` directly would pass
%%% every test with the prose still right.
%%% ---------------------------------------------------------------------------

report(Path, Diag)       -> publish(Path, Diag).

report_fatal(Path, Reason) -> publish(Path, Reason).

%% A shape `bs_diag` does not know still gets reported rather than crashing —
%% the behaviour both printers had, kept, because the alternative is an escript
%% stack trace at the one moment the compiler is already confused.
publish(Path, D) ->
    Desc = case bs_diag:descriptor(Path, D) of
               unhandled -> #{tag => unclassified, severity => error,
                              file => Path, detail => D};
               Found     -> Found
           end,
    bs_diag:emit(bs_diag:channel(), Desc).
