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

-record(opts, {outdir = ".", emit_abstr = true, verbose = false, repl = false}).

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
    io:format("usage: bsc [-o DIR] [-v] FILE.bs [FUNCTION] [ARG...]~n"
              "  with no ARGs, compiles. With ARGs, compiles then runs:~n"
              "      bsc fib.bs 5~n"),
    halt(2);
main(Args) ->
    {Opts, Files, Argv} = parse_args(Args, #opts{}, []),
    case {Opts#opts.repl, Files, Argv} of
        {true, [File], _} -> repl(File, Opts);
        {true, [], _} ->
            io:format(standard_error, "usage: ibs -S FILE.bs~n", []),
            halt(2);
        {false, F, A} -> compile_or_run(F, A, Opts)
    end.

compile_or_run(Files, Argv, Opts) ->
    case {Files, Argv} of
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

compile_set(Files, Opts) ->
    case load_all(Files) of
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
build([{Path, Decls, Mod} | Rest], Opts, World, Acc) ->
    case check_and_emit(Path, Opts, Decls, World) of
        {ok, Beam} ->
            World1 = World#{Mod => #{exports => bs_check:exports_of(Decls),
                                     behaviours => [B || {behaviour, _, B} <- Decls]}},
            build(Rest, Opts, World1, [{Path, Beam} | Acc]);
        Error ->
            Error
    end.

%% The given files, plus every module they reach through `using`. A dependency
%% that was not named on the command line is found in the source tree — which is
%% 41 §3's "`using Shop.Orders` is a path on disk; `bsc` resolves it".
load_all(Files) ->
    case parse_all(Files) of
        {error, R} -> {error, R};
        {ok, Given} ->
            Index = source_index(Files),
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

parse_all(Files) -> parse_all(Files, []).

parse_all([], Acc) -> {ok, lists:reverse(Acc)};
parse_all([F | Rest], Acc) ->
    case parse_path(F) of
        {ok, Decls} -> parse_all(Rest, [{F, Decls, module_of(Decls)} | Acc]);
        Error       -> Error
    end.

close_over(Units, Index, Have) ->
    Wanted = lists:usort(lists:append([import_targets(D, maps:keys(Index))
                                       || {_, D, _} <- Units])),
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

%% Module atom -> source path, over every `.bs` file under the roots of the files
%% being compiled.
%%
%% BUILT BY PARSING RATHER THAN BY NAMING. Resolving `Shop.Orders` to
%% `Shop/Orders.bs` would be cheaper and would be wrong here: the repo's own
%% files do not keep that correspondence — `aoc/2019/day01/day01.bs` declares
%% `module Day01` — and inventing a filename rule is ticket 41 §5's
%% `module_path_mismatch`, which belongs with the directory-as-module work and
%% not here. A file that fails to parse is skipped: it is not a dependency
%% anybody asked for, and if it is, the error arrives when it is compiled.
source_index(Files) ->
    Roots = lists:usort([filename:dirname(F) || F <- Files]),
    Sources = lists:usort(lists:append([bs_files(R) || R <- Roots])),
    lists:foldl(fun(P, Acc) ->
                        case parse_quietly(P) of
                            {ok, Decls} ->
                                case module_of(Decls) of
                                    undefined -> Acc;
                                    M -> maps:put(M, P, Acc)
                                end;
                            error -> Acc
                        end
                end, #{}, Sources).

bs_files(Dir) ->
    filelib:wildcard(filename:join(Dir, "**/*.bs")) ++
        filelib:wildcard(filename:join(Dir, "*.bs")).

module_of(Decls) ->
    case [N || {module, _, N} <- Decls] of
        [N | _] -> N;
        []      -> undefined
    end.

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

emit_one({_, Decls, M} = U, Index, Path, Done, Acc) ->
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
parse_args([A | Rest], O, Fs) ->
    case filename:extension(A) =:= ".bs" of
        true  -> parse_args(Rest, O, [A | Fs]);
        false -> {O, lists:reverse(Fs), [A | Rest]}
    end;
parse_args([], O, Fs)                 -> {O, lists:reverse(Fs), []}.

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

beam_for(File, Beams) ->
    {_, Beam} = lists:keyfind(File, 1, Beams),
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
report_run({error, {ambiguous, Names}}) ->
    io:format(standard_error,
              "bsc: which function? the module exports ~s~n"
              "  bsc FILE.bs FUNCTION ARG...~n",
              [lists:join(", ", [atom_to_list(N) || N <- Names])]),
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

file(Path, Opts) ->
    case file:read_file(Path) of
        {ok, Bin} -> compile_string(binary_to_list(Bin), Opts#opts{}, Path);
        {error, R} -> report_fatal(Path, {cannot_read, R}), {error, R}
    end.

compile_string(Src, Opts) -> compile_string(Src, Opts, "<string>").

compile_string(Src, Opts, Path) ->
    with_stages(Path, Opts, Src).

with_stages(Path, Opts, Src) ->
    case parse_string(Path, Src) of
        {error, R}  -> {error, R};
        {ok, Decls} -> check_and_emit(Path, Opts, Decls, #{})
    end.

parse_string(Path, Src) ->
    case bs_lexer:string(Src) of
        {error, Err, _} ->
            report_fatal(Path, {lex, Err}), {error, lex};
        {ok, Tokens, _} ->
            case bs_parser:parse(Tokens) of
                {error, Err} ->
                    report_fatal(Path, {parse, Err}), {error, parse};
                {ok, Decls} ->
                    {ok, Decls}
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
                        {ok, Decls} -> {ok, Decls};
                        _           -> error
                    end;
                _ -> error
            end;
        _ -> error
    end.

check_and_emit(Path, Opts, Decls, World) ->
    %% The checker signals a handful of conditions by raising rather than by
    %% returning a diagnostic, because they are found while RESOLVING types —
    %% below the level that carries a line and a function name. Uncaught, they
    %% reached the author as an escript stack trace, which is the worst
    %% diagnostic this compiler produced: found by running LANGUAGE.md's own
    %% examples through it, where two blocks hit `unknown_type`.
    try bs_check:check(Decls, World) of
        {error, Diags} ->
            [report(Path, D) || D <- Diags],
            {error, check};
        {ok, Module, Diags} ->
            [report(Path, D) || D <- Diags],
            emit(Path, Opts, Module)
    catch
        error:Reason when is_tuple(Reason) ->
            case resolve_error(Path, Reason) of
                handled  -> {error, check};
                unhandled -> erlang:error(Reason)
            end
    end.

%% Ticket 35 §3. The message names the callbacks in the spelling the AUTHOR must
%% write — `HandleCast(term, int)`, not `handle_cast/2` — because the residual is
%% the missing case (04) and the compiler synthesises the head, never the body
%% (23). Naming OTP's spelling here would hand back a name that does not lex.
resolve_error(Path, {behaviour_not_satisfied, Line, Behaviour, Missing}) ->
    io:format(standard_error,
              "~s:~p: error: behaviour ~s is declared and not satisfied~n"
              "  these callbacks are mandatory and this module does not define them:~n"
              "~s"
              "  a `behaviour` attribute is emitted for the whole contract, so a~n"
              "  partial one would fail when the process starts rather than here.~n",
              [Path, Line, Behaviour,
               [io_lib:format("    ~s/~p~n", [N, A]) || {N, A} <- Missing]]),
    handled;
resolve_error(Path, {unknown_behaviour, B}) ->
    io:format(standard_error,
              "~s: error: no behaviour named ~s~n"
              "  the compiler knows `GenServer`, `Supervisor`, `Application`,~n"
              "  `GenStatem` and `GenEvent`.~n",
              [Path, B]),
    handled;
resolve_error(Path, {unknown_type, N}) ->
    io:format(standard_error,
              "~s: error: no type named ~s~n"
              "  declare it with `type ~s = ...` or `record ~s { ... }`.~n",
              [Path, N, N, N]),
    handled;
resolve_error(Path, {unknown_builtin, B}) ->
    io:format(standard_error,
              "~s: error: ~s is not a builtin type~n"
              "  this slice has `int`, `atom`, `term`, `bool`, `binary`,~n"
              "  `string` and `list<T>`.~n",
              [Path, B]),
    handled;
%% F9.11. The message names the replacement, because the fix is always the same
%% edit and the reason is not obvious from the rule: `string` is `binary` refined
%% by valid UTF-8 (20 §4), the refinement is O(n) over a length the sender
%% chooses, and a foreign return type may only say what a guard decides in O(1)
%% (18 §2). So the boundary takes the base type and the refinement is
%% established afterwards.
resolve_error(Path, {opaque_ret_at_boundary, Line, Mod, Fun}) ->
    io:format(standard_error,
              "~s:~p: error: ~s.~s returns `string`, which a guard cannot decide~n"
              "  `string` is `binary` refined by valid UTF-8, and checking that~n"
              "  reads every byte of a value the sender sizes.~n"
              "  declare it `binary`. Establishing the refinement is the UTF-8~n"
              "  entry check, which this compiler does not have yet.~n",
              [Path, Line, bs_types:atom_str(Mod), Fun]),
    handled;
resolve_error(Path, {unknown_generic, N}) ->
    io:format(standard_error,
              "~s: error: no type named ~s takes a type argument~n"
              "  the prelude has `list<T>`, `option<T>` and `result<T, E>`;~n"
              "  your own take one with `type ~s<T> = ...`.~n",
              [Path, N, N]),
    handled;
%% F6.6. A bracket the compiler KNOWS at the wrong arity is a different mistake
%% from a bracket it does not know, and the fix is a different edit.
resolve_error(Path, {generic_arity, N, Want, Got}) ->
    io:format(standard_error,
              "~s: error: ~s takes ~p type argument~s, and got ~p~n",
              [Path, N, Want, plural(Want), Got]),
    handled;
resolve_error(Path, {needs_type_args, N, Want}) ->
    io:format(standard_error,
              "~s: error: ~s is parametric and was written without a bracket~n"
              "  it takes ~p type argument~s: write `~s<...>`.~n",
              [Path, N, Want, plural(Want), N]),
    handled;
resolve_error(Path, {not_parametric, N}) ->
    io:format(standard_error,
              "~s: error: ~s takes no type arguments~n"
              "  declare it as `type ~s<T> = ...` if it should.~n",
              [Path, N, N]),
    handled;
%% F6.8. The alternative is not a worse message — it is no message, because the
%% resolver loops. Ticket 09 decided recursion is equirecursive and contractive;
%% the algebra cannot hold one, so this refuses by name rather than pretending.
resolve_error(Path, {cyclic_type, N}) ->
    io:format(standard_error,
              "~s: error: the type ~s is defined in terms of itself~n"
              "  a recursive type has no representation in the checker's algebra~n"
              "  yet, so it is refused rather than expanded forever.~n",
              [Path, N]),
    handled;
resolve_error(Path, {kind_field_is_minted, Line, Name}) ->
    io:format(standard_error,
              "~s:~p: error: ~s declares a field named Kind~n"
              "  the tag is minted from the type's qualified name, so a record~n"
              "  cannot also declare one. Rename the field.~n",
              [Path, Line, Name]),
    handled;
%% F2 / ticket 20 §5. The two tiers are told apart by what the predicate SAYS,
%% so the message has to say which half of the language the author has landed in
%% — and name the O(n) tier as *permitted but unplaceable*, because ticket 29
%% amended §5 to allow declaring one and still bar it from a clause head. Saying
%% only "not supported" would misdescribe a decision that was actually taken.
resolve_error(Path, {opaque_refinement, Line}) ->
    io:format(standard_error,
              "~s:~p: error: this refinement is not a predicate the checker can read~n"
              "  a refinement narrows a type, so the compiler has to be able to~n"
              "  reason about it: comparisons on `value`, joined with `and`/`or`.~n"
              "  `int where value >= 0 and value <= 255` is one.~n"
              "  A predicate that reads the value instead — `WellFormed(value)` —~n"
              "  is the O(n) tier. It is established once at a boundary and never~n"
              "  reasoned about, and this compiler has no site to establish it at.~n",
              [Path, Line]),
    handled;
resolve_error(Path, {empty_refinement, Line}) ->
    io:format(standard_error,
              "~s:~p: error: this refinement admits no values at all~n"
              "  the predicate contradicts itself, so nothing has this type and~n"
              "  no call to a function over it could ever be written.~n",
              [Path, Line]),
    handled;
%% F2's scope call, made legible. The grammar admits this because a record field
%% and a tuple component both take a `pattern`; the feature ships the construct in
%% the parameter position only, and a message that just said "syntax error" would
%% make a chosen omission look like an oversight.
resolve_error(Path, {relational_pattern_nested, Line}) ->
    io:format(standard_error,
              "~s:~p: error: a relational pattern goes where a whole argument goes~n"
              "  `Classify(>= 4 and <= 7)` is the shipped form. Inside a record~n"
              "  pattern, a tuple or a list it is not built yet — write the~n"
              "  comparison as a guard there: `when o.Total > 100`.~n",
              [Path, Line]),
    handled;
resolve_error(Path, {list_pattern_needs_rest, Line}) ->
    io:format(standard_error,
              "~s:~p: error: a list pattern needs a rest~n"
              "  write `[h, ..t]`. Prefix-plus-rest is the only list pattern.~n",
              [Path, Line]),
    handled;
%%% --- F11, the module system -------------------------------------------------

%% Ticket 40 §2. Before this, two same-arity signatures were MERGED into one
%% N-clause function and the later clauses reported as unreachable — a remark
%% about the code where the truth was a duplicate declaration — and the program
%% was then stopped by `erlc` against `Silent.abstr:0`: no line, no `.bs`
%% filename, a message about a file the author never wrote.
resolve_error(Path, {name_redeclared, Name, Arity, Line}) ->
    io:format(standard_error,
              "~s:~p: error: ~s/~p is declared more than once~n"
              "  a name may carry MORE THAN ONE ARITY, so ~s/~p and ~s/~p would~n"
              "  be two functions — but two signatures of the SAME arity are one~n"
              "  function declared twice, and its clauses would merge silently.~n",
              [Path, Line, Name, Arity, Name, Arity, Name, Arity + 1]),
    handled;

%% 41 §2 requirement 1. The candidates print QUALIFIED because a qualified call
%% is legal regardless of what is in scope — so the message is pasteable source,
%% which is the property ticket 23 gives the residual.
resolve_error(Path, {ambiguous_call, Name, Arity, Mods, Line}) ->
    io:format(standard_error,
              "~s:~p: error: ~s/~p is ambiguous — ~p imports declare it~n"
              "  name one of these instead:~n"
              "~s",
              [Path, Line, Name, Arity, length(Mods),
               [io_lib:format("    ~s.~s(...)~n", [M, Name]) || M <- Mods]]),
    handled;

%% 41 §2 requirement 2, and the ticket is careful that this is NOT the analogy
%% ticket 40 §2 refused: there each overload had a defined meaning, here the
%% unqualified name has none at all.
resolve_error(Path, {import_shadows_local, Name, Arity, Mod, Line}) ->
    io:format(standard_error,
              "~s:~p: error: importing ~s brings in ~s/~p, which this module also declares~n"
              "  the unqualified name would have no defined meaning. Call the~n"
              "  import as ~s.~s(...) and the local one as ~s(...).~n",
              [Path, Line, Mod, Name, Arity, Mod, Name, Name]),
    handled;

resolve_error(Path, {unknown_module, Mod, Line}) ->
    io:format(standard_error,
              "~s:~p: error: `using ~s` names no module and no namespace~n"
              "  a module is a source file this invocation can reach; a namespace~n"
              "  is a path that other modules sit under. Neither matched.~n",
              [Path, Line, Mod]),
    handled;

%% 41 §1 reason 3 met rather than decided: a file's `using` lines ARE its
%% dependency list, in the file and checkable (ticket 23 §11). A qualified call
%% that skipped the list would make the list a lie.
resolve_error(Path, {module_not_imported, Mod, Line}) ->
    io:format(standard_error,
              "~s:~p: error: ~s is called but never imported~n"
              "  add `using ~s` — a file's `using` lines are its dependency list,~n"
              "  and a call that skips them makes that list wrong.~n",
              [Path, Line, Mod, Mod]),
    handled;

resolve_error(Path, {ambiguous_module, Short, Mods, Line}) ->
    io:format(standard_error,
              "~s:~p: error: ~s is ambiguous — ~p namespaces hold a module of that name~n"
              "  name one of these in full instead:~n"
              "~s",
              [Path, Line, Short, length(Mods),
               [io_lib:format("    ~s~n", [M]) || M <- Mods]]),
    handled;

%% Two modules importing each other. 41 explicitly leaves the cycle rule to "the
%% implementing feature", and F6's cyclic-ALIAS guard is the precedent it names:
%% refuse by name rather than expand. That guard shipped after a HANG, which no
%% green suite could see, and the same hazard is here — resolving a cycle by
%% following it is a loop.
resolve_error(_Path, {import_cycle, Cycle}) ->
    io:format(standard_error,
              "error: these modules import each other in a cycle~n"
              "~s"
              "  the compiler checks a dependency before its dependents, so a~n"
              "  cycle has no order to check them in. Break it by moving the~n"
              "  shared declarations into a module both can import.~n",
              [[io_lib:format("    ~s~n", [M]) || M <- Cycle]]),
    handled;

resolve_error(_Path, _Other) ->
    unhandled.

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
    Cmd = lists:flatten(io_lib:format("erlc +from_abstr +debug_info -o ~s ~s 2>&1; echo \"bsc_exit:$?\"",
                                      [Dir, AbstrPath])),
    Out = os:cmd(Cmd),
    Beam = filename:rootname(AbstrPath) ++ ".beam",
    %% erlc reports warnings on the same stream as errors, so the exit status is
    %% the only honest discriminator — treating any output as failure made the
    %% first green build look red.
    case lists:suffix("bsc_exit:0\n", Out) of
        true ->
            case string:trim(strip_status(Out)) of
                ""   -> ok;
                Warn -> io:format(standard_error, "erlc: ~s~n", [Warn])
            end,
            verbose(Opts, "built ~s~n", [Beam]),
            {ok, Beam};
        false ->
            io:format(standard_error, "erlc: ~s~n", [strip_status(Out)]),
            {error, {erlc, strip_status(Out)}}
    end.

strip_status(Out) ->
    Lines = string:split(Out, "\n", all),
    string:join([L || L <- Lines, not lists:prefix("bsc_exit:", L)], "\n").

verbose(#opts{verbose = true}, F, A) -> io:format(F, A);
verbose(_, _, _) -> ok.

plural(1) -> "";
plural(_) -> "s".

%%% ---------------------------------------------------------------------------
%%% Diagnostics
%%%
%%% Ticket 04 established that the exhaustiveness residual *is* the missing case,
%%% and ticket 23 will decide whether it also gets a machine-readable form. Until
%%% then it at least has to read as the clause the author must write, which means
%%% rendering the residual as a **clause head** rather than as a type expression.
%%% ---------------------------------------------------------------------------

report(Path, {error, Line, Fn, {inexhaustive, Residual}}) ->
    io:format(standard_error,
              "~s:~p: error: ~s is not exhaustive~n"
              "  no clause matches:~n~s",
              [Path, Line, Fn, heads(Fn, Residual)]);
%% TICKET 12 §2 — a catch-all is legal only over an OPEN residual, and this is
%% the message that has to carry a *conditionally legal* `_` to a reader who has
%% never met one. Neither borrowed audience expects that: C#'s `_` in a switch
%% arm is just a pattern and TypeScript's `default` is just a branch. 12 accepted
%% the cost because the alternative puts the headline guarantee one character
%% from being switched off, silently, with no trace in the diff.
%%
%% So the message says WHY it is closed and hands back the cases, which is ticket
%% 04's finding doing the work: the residual IS the missing case, so the thing
%% that makes the error legitimate is the same thing that answers it.
report(Path, {error, Line, Fn, {catch_all_over_closed, Residual}}) ->
    io:format(standard_error,
              "~s:~p: error: ~s discards cases the compiler can name~n"
              "  every value left here comes from a type you declared, so `_`~n"
              "  hides a case rather than admitting an unknown one:~n~s"
              "  a catch-all is for a residual with an unbounded top in it — a~n"
              "  `term` argument, or the open atom universe — where a foreign~n"
              "  sender chooses the inhabitants and there is nothing to enumerate.~n",
              [Path, Line, Fn, heads(Fn, Residual)]);
%% F2. The construct is a head's, and the message says where to put it rather
%% than only that it is wrong.
report(Path, {error, Line, Fn, relational_in_bind}) ->
    io:format(standard_error,
              "~s:~p: error: ~s binds a relational pattern~n"
              "  `>= 4` names a span of values and introduces no name, so there~n"
              "  is nothing for a bind to bind. A bind must also be provably~n"
              "  irrefutable, and a span is the refutable construct itself.~n"
              "  Dispatch on it in a clause head instead.~n",
              [Path, Line, Fn]);
report(Path, {error, Line, Fn, no_clauses}) ->
    io:format(standard_error, "~s:~p: error: ~s has a signature but no clauses~n",
              [Path, Line, Fn]);
%% Ticket 17 §6, and ticket 04's residual at a third site. Deliberately NOT
%% routed through `heads/2`: that prints `Fn(:cancelled) -> ...`, and a switch
%% has no function name and its arrow is `=>`. What is printed is the arm, which
%% `to_pattern/1` already renders for every shape the subject can have — a tuple
%% subject as `(false, false, true)`, a union of records as its discriminator.
report(Path, {error, Line, Fn, {switch_inexhaustive, Residual}}) ->
    io:format(standard_error,
              "~s:~p: error: this switch in ~s is not exhaustive~n"
              "  no arm matches:~n"
              "    ~s => ...~n",
              [Path, Line, Fn, bs_types:to_pattern(Residual)]);
%% Arm, not clause. The word is the whole of the message's usefulness: a
%% construct with no clauses in it cannot be told which clause is dead.
report(Path, {warning, Line, Fn, {unreachable_arm, N}}) ->
    io:format(standard_error,
              "~s:~p: warning: arm ~p of this switch in ~s is unreachable~n"
              "  every value it matches is matched by an earlier arm.~n",
              [Path, Line, N, Fn]);
%% F7's own grammar opens this, the way F5's opened `_`-as-a-value: a guard
%% shares the whole expression grammar, so a switch parses inside one. Erlang's
%% guards are a restricted sublanguage with no `case`, so this would otherwise
%% arrive as `illegal guard expression` from `erlc`.
report(Path, {error, Line, Fn, switch_in_guard}) ->
    io:format(standard_error,
              "~s:~p: error: ~s has a switch in a guard~n"
              "  a guard asks a question about the values a clause already~n"
              "  matched; it cannot branch. Move the switch into the body.~n",
              [Path, Line, Fn]);
report(Path, {warning, Line, Fn, {unreachable_clause, N}}) ->
    io:format(standard_error,
              "~s:~p: warning: clause ~p of ~s is unreachable~n"
              "  every value it matches is matched by an earlier clause.~n",
              [Path, Line, N, Fn]);
%% Ticket 34. Both of these would otherwise reach the author as an `erlc` error
%% against the emitted `.abstr` — a file they did not write and cannot fix.
report(Path, {error, Line, Fn, {rebinding, V}}) ->
    io:format(standard_error,
              "~s:~p: error: ~s binds ~s twice~n"
              "  a name means one thing in a clause. There is no mutation to~n"
              "  assign with, so rename the second one.~n",
              [Path, Line, Fn, V]);
%% F8.10. The same offence as `rebinding` and a DIFFERENT fix, which is why it is
%% a different descriptor rather than a shared one: in a body you rename, in a
%% head you almost always meant *the same value again*, and ticket 45 supplies
%% the spelling for saying so. A message that named the wrong fix would be worse
%% than terse, because this is the case where the author's intent is guessable.
report(Path, {error, Line, Fn, {repeated_in_head, V}}) ->
    io:format(standard_error,
              "~s:~p: error: ~s binds ~s twice in one head~n"
              "  a name means one thing in a clause, so this introduces ~s and~n"
              "  then introduces it again. To match the value the first one~n"
              "  holds, write `== ~s`.~n",
              [Path, Line, Fn, V, V, V]);
report(Path, {error, Line, Fn, {unbound_variable, V}}) ->
    io:format(standard_error,
              "~s:~p: error: ~s uses ~s, which nothing binds~n"
              "  a name comes from a clause head or a binding above it.~n",
              [Path, Line, Fn, V]);
%%% Ticket 33's five sites, F5. Four of them carry a residual the printer above
%%% already renders as a clause head, which is why the language does not acquire
%%% its first empty-handed diagnostic here — ticket 23's cost does not fall due.
%%% Construction is the exception and says so in field names instead.

%% SITE 1. The residual is the clause the CALLER must write. It proposes an edit
%% to the function being checked and never to the callee: ticket 18 §4's
%% function-local rule is what stops this from suggesting you widen `Update`.
report(Path, {error, Line, Fn, {arg_not_accepted, Callee, Pos, Residual, Head}}) ->
    io:format(standard_error,
              "~s:~p: error: ~s hands ~s an argument it does not accept~n"
              "  argument ~p is not covered by ~s's declared type:~n"
              "    ~s~n~s",
              [Path, Line, Fn, Callee, Pos, Callee,
               bs_types:to_pattern(Residual), caller_head(Fn, Head, Residual)]);
%% SITE 2. `Order{Id} \ Order` names the type you were BUILDING rather than the
%% field you forgot — correct, and worthless — so this one site answers in field
%% names. It still hands back something to write, which is what ticket 23 asks.
report(Path, {error, Line, Fn, {field_set_mismatch, Record, Missing, Extra}}) ->
    io:format(standard_error,
              "~s:~p: error: ~s builds an ~s with the wrong fields~n~s~s",
              [Path, Line, Fn, Record,
               field_list("  missing, and must be supplied", Missing),
               field_list("  not declared by " ++ atom_to_list(Record), Extra)]);
%% SITE 3. The residual IS the member that lacks the field, which is the tag to
%% discriminate on — the sentence F3.8 deferred, needing no new machinery.
report(Path, {error, Line, Fn, {field_absent, Field, Residual}}) ->
    io:format(standard_error,
              "~s:~p: error: ~s projects ~s from a value that may not carry it~n"
              "  this member has no ~s:~n"
              "    ~s~n"
              "  discriminate on the tag first, in a clause head.~n",
              [Path, Line, Fn, Field, Field, bs_types:to_pattern(Residual)]);
%% SITE 4. Without this, beam-sharp emits a `-spec` claiming what its own body
%% does not deliver — the defect ticket 18 measured in Gleam, from a body rather
%% than from an FFI declaration.
report(Path, {error, Line, Fn, {return_not_declared, Residual}}) ->
    io:format(standard_error,
              "~s:~p: error: ~s returns a value its signature does not declare~n"
              "  not covered by the declared return type:~n"
              "    ~s~n",
              [Path, Line, Fn, bs_types:to_pattern(Residual)]);
%% SITE 5. Ticket 34 deferred the destructuring bind here rather than refusing
%% it: provably irrefutable exactly when this residual is empty.
report(Path, {error, Line, Fn, {bind_may_fail, Residual}}) ->
    io:format(standard_error,
              "~s:~p: error: this bind in ~s can fail~n"
              "  the pattern does not match:~n"
              "    ~s~n"
              "  a bind that can fail is a branch the exhaustiveness checker~n"
              "  never sees. Match it in a clause head instead.~n",
              [Path, Line, Fn, bs_types:to_pattern(Residual)]);
report(Path, {error, Line, Fn, {unknown_callee, Callee, Arity}}) ->
    io:format(standard_error,
              "~s:~p: error: ~s calls ~s/~p, which nothing declares~n"
              "  every function has a signature. Write one, or fix the name.~n",
              [Path, Line, Fn, Callee, Arity]);
report(Path, {error, Line, Fn, {arity_mismatch, Callee, Got, Want}}) ->
    io:format(standard_error,
              "~s:~p: error: ~s calls ~s with ~p arguments, and it takes ~p~n",
              [Path, Line, Fn, Callee, Got, Want]);
%% Ticket 40 §2 permits arity overloading, so this is not "wrong number of
%% arguments" — it is a function that has not been declared, next to ones that
%% have. Naming the arities that DO exist is what keeps it a fix rather than a
%% verdict.
report(Path, {error, Line, Fn, {arity_not_declared, Callee, Got, Have}}) ->
    io:format(standard_error,
              "~s:~p: error: ~s calls ~s/~p, which nothing declares~n"
              "  ~s is declared at ~s. Arity overloading is permitted, so~n"
              "  ~s/~p would be a new function and needs its own signature.~n",
              [Path, Line, Fn, Callee, Got, Callee,
               lists:join(", ", [[$/ | integer_to_list(A)] || A <- Have]),
               Callee, Got]);
report(Path, {error, Line, Fn, {unknown_record, Name}}) ->
    io:format(standard_error,
              "~s:~p: error: ~s builds an ~s, which no record or type declares~n",
              [Path, Line, Fn, Name]);
%% F5's own grammar opens this hole: `_` is an expression only so that
%% `(a, _) = pair` parses. Caught here rather than by `erlc` against a file the
%% author did not write, which is F4.7's rule.
report(Path, {error, Line, Fn, wildcard_as_value}) ->
    io:format(standard_error,
              "~s:~p: error: ~s uses `_` as a value~n"
              "  `_` is a pattern. It may stand on the left of `=` or in a~n"
              "  clause head; it names nothing to read back.~n",
              [Path, Line, Fn]);
report(Path, D) ->
    io:format(standard_error, "~s: ~p~n", [Path, D]).

%% The caller's head with the rejected values in the position that rejected
%% them. Only synthesised when the argument IS a whole parameter — an arbitrary
%% expression has no position in the head to put a pattern in, and inventing one
%% would hand back something that does not compile.
caller_head(_Fn, none, _Residual) -> "";
caller_head(Fn, {Pos, Arity}, Residual) ->
    Slots = [case I of
                 Pos -> bs_types:to_pattern(Residual);
                 _   -> "_"
             end || I <- lists:seq(1, Arity)],
    io_lib:format("  the clause to add here:~n    ~s(~s) -> ...~n",
                  [Fn, string:join(Slots, ", ")]).

field_list(_Label, [])     -> "";
field_list(Label, Fields)  ->
    io_lib:format("~s:~n    ~s~n",
                  [Label, string:join([atom_to_list(F) || F <- Fields], ", ")]).

%% beam-sharp has no statement terminator, and both audiences type one from
%% habit — so this is the most likely error in the language and it gets the
%% sharpest message rather than leex's raw tuple.
report_fatal(Path, {lex, {Line, _Mod, {illegal, ";"}}}) ->
    io:format(standard_error,
              "~s:~p: error: beam-sharp has no `;`~n"
              "  a declaration ends where the next one begins. Remove it.~n",
              [Path, Line]);
report_fatal(Path, {lex, {Line, Mod, Reason}}) ->
    io:format(standard_error, "~s:~p: error: ~s~n",
              [Path, Line, Mod:format_error(Reason)]);
report_fatal(Path, {parse, {Line, Mod, Reason}}) ->
    io:format(standard_error, "~s:~p: error: ~s~n",
              [Path, Line, Mod:format_error(Reason)]);
report_fatal(Path, Reason) ->
    io:format(standard_error, "~s: ~p~n", [Path, Reason]).

%% The residual's tuple part is the *argument list*, so each product prints as a
%% clause head the author can paste in.
heads(Fn, Residual) ->
    #{tuples := Products} = Residual,
    case Products of
        [] -> io_lib:format("    ~s~n", [truncated(Residual)]);
        _  -> cap([io_lib:format("    ~s(~s) -> ...~n",
                                 [Fn, string:join([truncated(C) || C <- P], ", ")])
                   || P <- Products])
    end.

%% THE RULE APPLIES TO HEAD LINES TOO, AND IT IS NEEDED TODAY RATHER THAN AFTER
%% TICKET 23 §2. 43 §3's table puts the head-counting half in the future tense —
%% *"after §2 it enumerates one head line per case"* — and its own reason for
%% having that half is what makes it reachable now:
%%
%%     A residual over a two-argument function is a PRODUCT, so the head count is
%%     the product of the parts. A rule that stayed on intervals would print an
%%     unbounded number of lines the moment a second argument had a residual too.
%%
%% `heads/2` has always printed one line per product, so a second argument is all
%% it takes. Measured before this was added: forty singleton clauses over
%% `(int, atom)` print **41 head lines**, one of them itself truncated. §2 is not
%% involved; it will only change what fills the sequence.
%%
%% So both units are live at once and 43's rule is honoured at both, which is what
%% *"at most three of whatever it is enumerating"* says when the printer is
%% enumerating two things at two depths. The marker is its own line here rather
%% than a trailing fragment, exactly as 43 §5 renders it.
cap(Lines) when length(Lines) =< ?RESIDUAL_CASES -> Lines;
cap(Lines) ->
    {Shown, Rest} = lists:split(?RESIDUAL_CASES, Lines),
    Shown ++ [io_lib:format("    ... (~p more)~n", [length(Rest)])].

%%% ---------------------------------------------------------------------------
%%% Ticket 43 — the residual at width
%%%
%%% 25c measured that forty singleton clauses leave a residual of forty-one
%%% disjoint intervals. Measured again by `43a`, that prints as ONE head line of
%%% 453 characters — `heads/2` splits on the tuple part, one product per argument
%%% position, and a union of intervals lives inside a single argument.
%%%
%%% THE SHAPE IS THE EXACT FORM WITH A STOP IN IT, and that is what makes it one
%%% format rather than two. At three items or fewer it prints byte-identically to
%%% what the compiler printed before this existed, so there is no threshold to
%%% tune, no flag, and no *"why did the format change"* to explain. Every other
%%% candidate 43 priced has to switch formats, because none can render a
%%% two-interval residual without being longer than the enumeration and less
%%% useful: bounds-and-count is 49 characters against 20, and cardinality is 24
%%% characters that do not say what is missing.
%%%
%%% Cardinality lost for a second reason worth keeping in view: over `int` the
%%% residual is unbounded, so a count reads *"unbounded unnamed values"*. A shape
%%% that degenerates on the OPEN residual cannot be the general one, and until
%%% this very feature landed every residual was open.
%%%
%%% ASCII `...`, not `…`. A diagnostic goes to stderr through terminals the
%%% compiler does not control, and the ellipsis character buys two columns.
%%%
%%% THE UNIT IS STAGE-DEPENDENT AND THIS IS THE FIRST STAGE. Today the printer
%%% enumerates intervals inside one argument of one head line, so three counts
%%% intervals. After ticket 23 §2's lowering it enumerates one head line per case,
%%% and three counts heads. Naming the stage is not pedantry: 43's first draft
%%% said "three heads", which truncates NOTHING today, because one head is under
%%% any threshold. That is why this runs over the RENDERED SEQUENCE rather than
%%% over intervals as a type-level idea — when §2 lands it changes what fills the
%%% sequence and nothing here.
%%%
%%% ONE THING 43 DEFAULTED RATHER THAN SETTLED, recorded because F2 is what
%%% creates the case: over a CLOSED residual ticket 12 §2 bars the catch-all, so
%%% every truncated case is a clause somebody must still write, and three of
%%% forty-one is a third of a percent of the checklist. It truncates anyway — the
%%% descriptor keeps all forty-one and 23 §10's `bsc --api` is the full-fidelity
%%% channel. If that flips, the delta is one argument here and nothing else moves.
truncated(Ty) ->
    case bs_types:pattern_parts(Ty) of
        Parts when length(Parts) =< ?RESIDUAL_CASES ->
            string:join(Parts, " | ");
        Parts ->
            {Shown, Rest} = lists:split(?RESIDUAL_CASES, Parts),
            string:join(Shown, " | ")
                ++ io_lib:format(" | ... (~p more)", [length(Rest)])
    end.
