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
    loop(File, Dir, Mod, #{}).

banner(File, Mod) ->
    io:format("beam-sharp REPL — ~s~n", [File]),
    io:format("~s~n", [exports_line(Mod)]),
    io:format("  :reload   recompile the file    :exports  list functions~n"
              "  :quit     leave                 :env      list bindings~n~n").

exports_line(Mod) ->
    case exports(Mod) of
        []  -> "  (no functions)";
        Fns -> ["  ", lists:join("  ", [[atom_to_list(F), "/", integer_to_list(A)]
                                        || {F, A} <- Fns])]
    end.

exports(Mod) ->
    try [{F, A} || {F, A} <- Mod:module_info(exports), F =/= module_info]
    catch _:_ -> [] end.

loop(File, Dir, Mod, Env) ->
    case io:get_line("bs> ") of
        eof -> io:format("~n"), ok;
        {error, _} -> ok;
        Line -> dispatch(string:trim(Line), File, Dir, Mod, Env)
    end.

dispatch("", File, Dir, Mod, Env) -> loop(File, Dir, Mod, Env);
dispatch(":quit", _, _, _, _) -> ok;
dispatch(":q", _, _, _, _) -> ok;
dispatch(":exports", File, Dir, Mod, Env) ->
    io:format("~s~n", [exports_line(Mod)]),
    loop(File, Dir, Mod, Env);
dispatch(":env", File, Dir, Mod, Env) ->
    case maps:size(Env) of
        0 -> io:format("  (no bindings)~n");
        _ -> [io:format("  ~s = ~s~n", [K, bs_run:format_value(V)])
              || {K, V} <- lists:sort(maps:to_list(Env))]
    end,
    loop(File, Dir, Mod, Env);
dispatch(":reload", File, Dir, Mod, Env) ->
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
    loop(File, Dir, Mod, Env);
dispatch([$: | Unknown], File, Dir, Mod, Env) ->
    io:format(standard_error, "unknown command :~s~n", [Unknown]),
    loop(File, Dir, Mod, Env);
dispatch(Line, File, Dir, Mod, Env) ->
    loop(File, Dir, Mod, run(Line, Mod, Env)).

%%% ---------------------------------------------------------------------------
%%% Bindings at the prompt.
%%%
%%% Ticket 34 put bindings in the LANGUAGE, where they belong to a body. Holding
%%% one across prompts is a different thing — a property of this shell, not of
%%% beam-sharp — and it is here because a REPL you cannot name a value in makes
%%% you retype the value instead, which is exactly what the tool exists to avoid.
%%%
%%% The environment does not survive `:reload`; that is deliberate, since the
%%% values in it were produced by code that has just been replaced.
%%% ---------------------------------------------------------------------------

run(Line, Mod, Env) ->
    case binding(Line) of
        {Name, Rhs} ->
            case value_of(Rhs, Mod, Env) of
                {ok, V} ->
                    io:format("~s = ~s~n", [Name, bs_run:format_value(V)]),
                    Env#{Name => V};
                {error, Msg} ->
                    io:format(standard_error, "~ts~n", [Msg]),
                    Env
            end;
        none ->
            case value_of(Line, Mod, Env) of
                {ok, V}      -> io:format("~s~n", [bs_run:format_value(V)]), Env;
                {error, Msg} -> io:format(standard_error, "~ts~n", [Msg]), Env
            end
    end.

%% `x = ...` where the name is a beam-sharp variable. Split on the FIRST `=`,
%% since the right-hand side may contain more of them — a record is
%% `{Kind = ..., Id = ...}`.
binding(Line) ->
    case string:split(Line, "=") of
        [Lhs, Rhs] ->
            case is_name(string:trim(Lhs)) of
                %% Keyed by the name AS TYPED, because that is what the reader
                %% has to match when it meets the name nested in a literal.
                true  -> {string:trim(Lhs), string:trim(Rhs)};
                false -> none
            end;
        _ -> none
    end.

%% A call, or a value — the two things worth typing at a prompt.
value_of(S, Mod, Env) ->
    case parse_call(S) of
        {error, CallMsg} ->
            case resolve(S, Env) of
                {ok, V} -> {ok, V};
                %% A PascalCase word is a function name someone forgot the
                %% parentheses on, not a value that failed to read.
                {error, ValueMsg} ->
                    case construction(S) orelse pascal(S) of
                        true  -> {error, CallMsg};
                        false -> {error, ValueMsg}
                    end
            end;
        {Fn, RawArgs} ->
            case read_args(RawArgs, Env) of
                {error, Msg} -> {error, Msg};
                {ok, Args}   -> apply_call(Mod, Fn, Args)
            end
    end.

%% A bare name resolves from the environment before anything else tries to read
%% it — otherwise `Squared(t)` would pass the ATOM `t`, which is the Erlang
%% reader's fallback showing through and never what anyone meant. beam-sharp
%% spells an atom `:t`, so nothing is lost.
resolve(S, Env) ->
    case maps:find(S, Env) of
        {ok, V} -> {ok, V};
        error ->
            case is_name(S) of
                true  -> {error, io_lib:format("~ts is not bound -- :env lists "
                                               "what is", [S])};
                %% Anything compound goes to the reader WITH the environment, so
                %% a bound name nested in a literal resolves too.
                false -> bs_run:read_arg(S, Env)
            end
    end.

%%% ---------------------------------------------------------------------------
%%% One form: Name(arg, arg, ...)
%%% ---------------------------------------------------------------------------

%% `apply/3` here is constrained to a {name, arity} pair checked against the
%% module's own export list, on a module the user just compiled from their own
%% source, in a local dev shell. That is what a REPL is; there is no wider
%% evaluation and no untrusted input path.
read_args(Raw, Env) ->
    lists:foldr(fun(_, {error, M}) -> {error, M};
                   (A, {ok, Acc}) ->
                        case resolve(A, Env) of
                            {ok, V}      -> {ok, [V | Acc]};
                            {error, Msg} -> {error, Msg}
                        end
                end, {ok, []}, Raw).

apply_call(Mod, Fn, Args) ->
    case lists:member({Fn, length(Args)}, exports(Mod)) of
        false ->
            {error, io_lib:format("no ~s/~p -- try :exports", [Fn, length(Args)])};
        true ->
            try {ok, apply(Mod, Fn, Args)}
            catch C:R -> {error, io_lib:format("crashed: ~p:~p", [C, R])} end
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

%% The prompt reads a call or a value, so anything else has to say what it got
%% rather than only what it wanted.
%%
%% This used to carry a third branch telling the reader that **beam-sharp has no
%% bindings**. It did not, for about half an hour: ticket 34 shipped them, and
%% the message outlived the fact it was describing — which is the same failure
%% as LANGUAGE.md showing syntax the compiler had never had, in the opposite
%% direction. A diagnostic that states a language rule is a claim, and it goes
%% stale exactly like a reference does.
no_call(Line) ->
    case construction(Line) of
        true ->
            io_lib:format("~ts constructs a record, and this prompt evaluates a "
                          "call or a value. Pass the value to one: "
                          "Pay({Kind = :'Shop.Order', Id = 1, Total = 0})", [Line]);
        false ->
            io_lib:format("~ts is a name, not a call -- write Fib(5), bind it with "
                          "x = ..., or :exports to see what there is", [Line])
    end.

pascal([C | _]) when C >= $A, C =< $Z -> true;
pascal(_) -> false.

is_name([C | Rest]) when C >= $a, C =< $z ->
    lists:all(fun(X) ->
                      (X >= $a andalso X =< $z) orelse (X >= $A andalso X =< $Z)
                          orelse (X >= $0 andalso X =< $9) orelse X =:= $_
              end, Rest);
is_name(_) -> false.

construction([C | Rest]) when C >= $A, C =< $Z -> lists:member(${, Rest);
construction(_) -> false.
