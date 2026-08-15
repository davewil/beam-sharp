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
    %% The checker signals a handful of conditions by raising rather than by
    %% returning a diagnostic, because they are found while RESOLVING types —
    %% below the level that carries a line and a function name. Uncaught, they
    %% reached the author as an escript stack trace, which is the worst
    %% diagnostic this compiler produced: found by running LANGUAGE.md's own
    %% examples through it, where two blocks hit `unknown_type`.
    try bs_check:check(Decls) of
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

resolve_error(Path, {unknown_type, N}) ->
    io:format(standard_error,
              "~s: error: no type named ~s~n"
              "  declare it with `type ~s = ...` or `record ~s { ... }`.~n",
              [Path, N, N, N]),
    handled;
resolve_error(Path, {unknown_builtin, B}) ->
    io:format(standard_error,
              "~s: error: ~s is not a builtin type~n"
              "  this slice has `int`, `atom`, `term`, `bool` and `list<T>`.~n",
              [Path, B]),
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
resolve_error(Path, {list_pattern_needs_rest, Line}) ->
    io:format(standard_error,
              "~s:~p: error: a list pattern needs a rest~n"
              "  write `[h, ..t]`. Prefix-plus-rest is the only list pattern.~n",
              [Path, Line]),
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
        [] -> io_lib:format("    ~s~n", [bs_types:to_pattern(Residual)]);
        _  -> [io_lib:format("    ~s(~s) -> ...~n",
                             [Fn, string:join([bs_types:to_pattern(C) || C <- P], ", ")])
               || P <- Products]
    end.
