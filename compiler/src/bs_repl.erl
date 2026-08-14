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
            case read_args(RawArgs) of
                {error, Msg} -> io:format(standard_error, "~ts~n", [Msg]);
                {ok, Args}   -> apply_call(Mod, Fn, Args)
            end
    end.

read_args(Raw) ->
    lists:foldr(fun(_, {error, M}) -> {error, M};
                   (A, {ok, Acc}) ->
                        case bs_run:read_arg(A) of
                            {ok, V}      -> {ok, [V | Acc]};
                            {error, Msg} -> {error, Msg}
                        end
                end, {ok, []}, Raw).

apply_call(Mod, Fn, Args) ->
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
    end.

parse_call(Line) ->
    case string:split(Line, "(") of
        [Name, Rest0] ->
            case lists:reverse(string:trim(Rest0)) of
                [$) | RevInner] ->
                    Inner = string:trim(lists:reverse(RevInner)),
                    {list_to_atom(string:trim(Name)), bs_run:split_top_level(Inner)};
                _ ->
                    {error, io_lib:format("missing closing ) in ~ts", [Line])}
            end;
        _ ->
            {error, no_call(Line)}
    end.

%% The prompt reads one call, so anything else has to say what it got rather
%% than only what it wanted — `expected a call, e.g. Fib(5)` left a reader who
%% typed `Which` or `o = Order{...}` to guess which half was wrong.
no_call(Line) ->
    case {binding(Line), construction(Line)} of
        {true, _} ->
            io_lib:format("~ts is a binding, and beam-sharp has none -- a name is "
                          "bound by a clause head, and a function body is one "
                          "expression. At this prompt, call a function: Fib(5)",
                          [Line]);
        {_, true} ->
            io_lib:format("~ts constructs a record, and this prompt evaluates a "
                          "call. Pass the value to one: Pay({Kind = :'Shop.Order', "
                          "Id = 1, Total = 0})", [Line]);
        _ ->
            io_lib:format("~ts is a name, not a call -- write Fib(5), and :exports "
                          "lists what there is", [Line])
    end.

%% `o = ...`, the mistake a C# or TypeScript reader makes first.
binding(Line) ->
    case string:split(Line, "=") of
        [Lhs, _] -> Lhs =/= Line andalso is_name(string:trim(Lhs));
        _        -> false
    end.

is_name([C | Rest]) when C >= $a, C =< $z ->
    lists:all(fun(X) ->
                      (X >= $a andalso X =< $z) orelse (X >= $A andalso X =< $Z)
                          orelse (X >= $0 andalso X =< $9) orelse X =:= $_
              end, Rest);
is_name(_) -> false.

construction([C | Rest]) when C >= $A, C =< $Z -> lists:member(${, Rest);
construction(_) -> false.
