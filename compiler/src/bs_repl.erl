%%% bs_repl — an interactive shell over a compiled .bs file.
%%%
%%%     ibs -S fib.bs
%%%     Fib(5)
%%%     5
%%%
%%% Deliberately *not* a beam-sharp expression evaluator. The parser in this
%%% slice reads declarations, not expressions, so the REPL reads exactly one
%%% form — a **call** — which is the form you want at a prompt anyway. Anything
%%% wider waits on the surface growing an expression parser.
%%%
%%% `:reload` is the point of the thing: edit the file, reload, call again,
%%% without leaving the shell. Development is driven by runnable code.
-module(bs_repl).

-export([start/3]).

start(File, Dir, Mod) ->
    banner(File, Mod),
    loop(File, Dir, Mod).

banner(File, Mod) ->
    io:format("beam-sharp REPL — ~s~n", [File]),
    io:format("~s~n", [exports_line(Mod)]),
    io:format("  :reload   recompile the file    :exports  list functions~n"
              "  :quit     leave                 Ctrl-D    leave~n~n").

exports_line(Mod) ->
    case exports(Mod) of
        []  -> "  (no functions)";
        Fns -> ["  ", lists:join("  ", [[atom_to_list(F), "/", integer_to_list(A)]
                                        || {F, A} <- Fns])]
    end.

exports(Mod) ->
    try [{F, A} || {F, A} <- Mod:module_info(exports), F =/= module_info]
    catch _:_ -> [] end.

loop(File, Dir, Mod) ->
    case io:get_line("bs> ") of
        eof -> io:format("~n"), ok;
        {error, _} -> ok;
        Line -> dispatch(string:trim(Line), File, Dir, Mod)
    end.

dispatch("", File, Dir, Mod) -> loop(File, Dir, Mod);
dispatch(":quit", _, _, _) -> ok;
dispatch(":q", _, _, _) -> ok;
dispatch(":exports", File, Dir, Mod) ->
    io:format("~s~n", [exports_line(Mod)]),
    loop(File, Dir, Mod);
dispatch(":reload", File, Dir, Mod) ->
    case bsc:file_to_dir(File, Dir) of
        {ok, _} ->
            code:purge(Mod),
            code:delete(Mod),
            code:purge(Mod),
            {module, Mod} = code:ensure_loaded(Mod),
            io:format("reloaded ~s~n", [File]);
        _ ->
            io:format(standard_error, "not reloaded~n", [])
    end,
    loop(File, Dir, Mod);
dispatch([$: | Unknown], File, Dir, Mod) ->
    io:format(standard_error, "unknown command :~s~n", [Unknown]),
    loop(File, Dir, Mod);
dispatch(Line, File, Dir, Mod) ->
    eval(Line, Mod),
    loop(File, Dir, Mod).

%%% ---------------------------------------------------------------------------
%%% One form: Name(arg, arg, ...)
%%% ---------------------------------------------------------------------------

%% `apply/3` here is constrained to a {name, arity} pair checked against the
%% module's own export list, on a module the user just compiled from their own
%% source, in a local dev shell. That is what a REPL is; there is no wider
%% evaluation and no untrusted input path.
eval(Line, Mod) ->
    case parse_call(Line) of
        {error, R} ->
            io:format(standard_error, "~s~n", [R]);
        {Fn, RawArgs} ->
            Args = [bs_run:parse_arg(A) || A <- RawArgs],
            case lists:member({Fn, length(Args)}, exports(Mod)) of
                false ->
                    io:format(standard_error, "no ~s/~p — try :exports~n",
                              [Fn, length(Args)]);
                true ->
                    try apply(Mod, Fn, Args) of
                        V -> io:format("~s~n", [bs_run:format_value(V)])
                    catch
                        C:R -> io:format(standard_error, "crashed: ~p:~p~n", [C, R])
                    end
            end
    end.

parse_call(Line) ->
    case string:split(Line, "(") of
        [Name, Rest0] ->
            case lists:reverse(string:trim(Rest0)) of
                [$) | RevInner] ->
                    Inner = string:trim(lists:reverse(RevInner)),
                    {list_to_atom(string:trim(Name)), bs_run:split_top_level(Inner)};
                _ ->
                    {error, "missing closing )"}
            end;
        _ ->
            {error, "expected a call, e.g. Fib(5)"}
    end.
