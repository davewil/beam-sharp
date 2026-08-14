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
    Results = [file(F, Opts) || F <- Files],
    case [R || R <- Results, element(1, R) =/= ok] of
        [] -> halt(0);
        _  -> halt(1)
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
    case file(File, Opts) of
        {ok, Beam} ->
            Mod = list_to_atom(filename:basename(Beam, ".beam")),
            report_run(bs_run:run(filename:dirname(Beam), Mod, Argv));
        _ ->
            halt(1)
    end.

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
report_run({error, R}) ->
    io:format(standard_error, "bsc: ~p~n", [R]),
    halt(1).

repl(File, Opts0) ->
    Opts = case Opts0#opts.outdir of
               "." -> Opts0#opts{outdir = tmpdir()};
               _   -> Opts0
           end,
    case file(File, Opts) of
        {ok, Beam} ->
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
    case bs_lexer:string(Src) of
        {error, Err, _} ->
            report_fatal(Path, {lex, Err}), {error, lex};
        {ok, Tokens, _} ->
            case bs_parser:parse(Tokens) of
                {error, Err} ->
                    report_fatal(Path, {parse, Err}), {error, parse};
                {ok, Decls} ->
                    check_and_emit(Path, Opts, Decls)
            end
    end.

check_and_emit(Path, Opts, Decls) ->
    case bs_check:check(Decls) of
        {error, Diags} ->
            [report(Path, D) || D <- Diags],
            {error, check};
        {ok, Module, Diags} ->
            [report(Path, D) || D <- Diags],
            emit(Path, Opts, Module)
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
report(Path, {error, Line, Fn, no_clauses}) ->
    io:format(standard_error, "~s:~p: error: ~s has a signature but no clauses~n",
              [Path, Line, Fn]);
report(Path, {warning, Line, Fn, {unreachable_clause, N}}) ->
    io:format(standard_error,
              "~s:~p: warning: clause ~p of ~s is unreachable~n"
              "  every value it matches is matched by an earlier clause.~n",
              [Path, Line, N, Fn]);
report(Path, D) ->
    io:format(standard_error, "~s: ~p~n", [Path, D]).

report_fatal(Path, Reason) ->
    io:format(standard_error, "~s: ~p~n", [Path, Reason]).

%% The residual's tuple part is the *argument list*, so each product prints as a
%% clause head the author can paste in.
heads(Fn, Residual) ->
    #{tuples := Products} = Residual,
    case Products of
        [] -> io_lib:format("    ~s~n", [bs_types:to_string(Residual)]);
        _  -> [io_lib:format("    ~s(~s) -> ...~n",
                             [Fn, string:join([bs_types:to_string(C) || C <- P], ", ")])
               || P <- Products]
    end.
