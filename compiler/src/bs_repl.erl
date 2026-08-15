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
        {match, Pat, Rhs} ->
            case value_of(Rhs, Mod, Env) of
                {ok, V} ->
                    case match(Pat, V, Env) of
                        {ok, Env1} ->
                            io:format("~s~n", [bs_run:format_value(V)]),
                            Env1;
                        {error, Msg} ->
                            io:format(standard_error, "~ts~n", [Msg]), Env
                    end;
                {error, Msg} ->
                    io:format(standard_error, "~ts~n", [Msg]), Env
            end;
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
%% A LINE THAT IS A CALL IS NEVER A BINDING, and this guard is not decoration:
%% a record argument carries `=` inside it, so `Squared({Kind = :'M.Order',
%% Id = 1})` split on the first `=` and — once the left side stopped having to be
%% a plain name — was read as a pattern match against `Squared({Kind`. Caught by
%% the two oldest tests in this file, which is the whole point of having them.
binding(Line) ->
    %% `{error, _}` first: a call result is also a two-tuple, so the general
    %% clause would swallow it.
    case parse_call(Line) of
        {error, _}   -> split_binding(Line);
        {_Fn, _Args} -> none
    end.

split_binding(Line) ->
    case string:split(Line, "=") of
        [Lhs0, Rhs] ->
            Lhs = string:trim(Lhs0),
            case {is_name(Lhs), Lhs} of
                %% Keyed by the name AS TYPED, because that is what the reader
                %% has to match when it meets the name nested in a literal.
                {true, _}  -> {Lhs, string:trim(Rhs)};
                {false, ""} -> none;
                %% Anything else on the left is a PATTERN, not a name — David,
                %% 2026-08-15: *"I do want Elixir matching behaviour. e.g x = 1,
                %% then 1 = x, 2 = x is an error."*
                {false, _} -> {match, Lhs, string:trim(Rhs)}
            end;
        _ -> none
    end.

%%% ---------------------------------------------------------------------------
%%% `=` is a MATCH, not an assignment
%%%
%%% The language already had this and the prompt did not. In a file:
%%%
%%%     x = 1
%%%     1 = x        accepted — F5 proves the bind cannot fail
%%%     2 = x        error: "this bind in Bad can fail"
%%%
%%% and beam-sharp's version is STRONGER than the one being asked for, because
%%% F5 rejects the second at COMPILE TIME where Elixir raises `MatchError` at run
%%% time. The residual it prints is the value the name can hold that the pattern
%%% does not cover.
%%%
%%% At the prompt there is no compile step for a bind, so the check happens
%%% against the value the name actually holds. Same rule, same message shape,
%%% earlier information.
%%%
%%% A name already bound is matched against, never rebound — which is ticket 34's
%%% rule ("a name means one thing") and removes Elixir's need for a pin operator:
%%% there is no `^x` because there is nothing to disambiguate.
%%% ---------------------------------------------------------------------------

match(Text, Value, Env) ->
    case pattern(string:trim(Text), Env) of
        {error, Msg} -> {error, Msg};
        %% The whole value travels with the recursion so a nested failure
        %% reports what the author typed against what they typed it at —
        %% reporting the failing COMPONENT said "(9, _) does not match 1",
        %% which names a number nobody wrote.
        {ok, Pat}    -> unify(Pat, Value, Env, {Text, Value})
    end.

%% A pattern is read from the same surface the value reader takes, with one
%% difference: an unbound lowercase name is a BINDER rather than an error.
pattern("_", _Env) -> {ok, wild};
pattern(S, Env) ->
    case is_name(S) of
        true ->
            case maps:find(S, Env) of
                %% ALREADY BOUND — so it MATCHES against the value it holds,
                %% rather than rebinding it. Every name is pinned, because
                %% ticket 34 says a name means one thing, which is why the
                %% language needs no `^`: there is nothing to disambiguate.
                {ok, V} -> {ok, {lit, V}};
                error   -> {ok, {bind, S}}
            end;
        false -> compound_pattern(S, Env)
    end.

compound_pattern(S, Env) ->
    case {hd(S), lists:last(S)} of
        {$(, $)} -> sub_patterns(S, Env, fun(Ps) -> {tuple, Ps} end);
        {$[, $]} -> sub_patterns(S, Env, fun(Ps) -> {list, Ps} end);
        _ ->
            %% Not a binder and not a structure, so it is a literal — read it
            %% with the ordinary value reader, which already knows atoms,
            %% integers, the keyword atoms and records.
            case bs_run:read_arg(S, Env) of
                {ok, V}      -> {ok, {lit, V}};
                {error, Msg} -> {error, Msg}
            end
    end.

sub_patterns(S, Env, Wrap) ->
    Inner = string:trim(lists:sublist(S, 2, length(S) - 2)),
    Parts = case Inner of "" -> []; _ -> bs_run:split_top_level(Inner) end,
    fold_patterns(Parts, Env, [], Wrap).

fold_patterns([], _Env, Acc, Wrap) -> {ok, Wrap(lists:reverse(Acc))};
fold_patterns([P | Rest], Env, Acc, Wrap) ->
    case pattern(string:trim(P), Env) of
        {error, Msg} -> {error, Msg};
        {ok, Pat}    -> fold_patterns(Rest, Env, [Pat | Acc], Wrap)
    end.

unify(wild, _V, Env, _T)        -> {ok, Env};
unify({bind, N}, V, Env, _T)    -> {ok, Env#{N => V}};
unify({lit, L}, V, Env, T)      ->
    case L =:= V of
        true  -> {ok, Env};
        false -> {error, no_match(T)}
    end;
unify({tuple, Ps}, V, Env, T) when is_tuple(V), length(Ps) =:= tuple_size(V) ->
    unify_all(Ps, tuple_to_list(V), Env, T);
unify({list, Ps}, V, Env, T) when is_list(V), length(Ps) =:= length(V) ->
    unify_all(Ps, V, Env, T);
unify(_Pat, _V, _Env, T) ->
    {error, no_match(T)}.

unify_all([], [], Env, _T) -> {ok, Env};
unify_all([P | Ps], [V | Vs], Env, T) ->
    case unify(P, V, Env, T) of
        {error, Msg} -> {error, Msg};
        {ok, Env1}   -> unify_all(Ps, Vs, Env1, T)
    end.

%% Says what it matched against, because at a prompt the value is the one thing
%% the reader knows and the author may not.
no_match({Pattern, Value}) ->
    io_lib:format("~ts does not match ~ts~n"
                  "  `=` matches, it does not assign. In a file this is a "
                  "compile error, not a crash.",
                  [string:trim(Pattern), bs_run:format_value(Value)]).

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
%% The two keyword atoms, which are NOT names — they are the one place the
%% language spells an atom without the sigil (ticket 10, `LANGUAGE.md` §4). The
%% lookup above them is what made this necessary: a bare word resolves from the
%% environment first, so `true` reached `is_name/1` and was reported unbound.
%%
%% Found by running `ibs -S examples/queue.bs` before writing F7's build note
%% rather than after, which is the fourth surface feature in a row to find
%% something at this prompt.
resolve("true", _Env)  -> {ok, true};
resolve("false", _Env) -> {ok, false};
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

%% A call's name must be PascalCase, because that is what the grammar says a
%% call IS — `expr -> uident '(' expr_list ')'`. Without this check ANY text
%% before a `(` was taken for a function name, which is how David's
%% `x = (1, 2)` became a call to a nameless function and answered
%% *"no /2 -- try :exports"* (2026-08-15). It is also why braces looked like the
%% only way to type a tuple: the correct spelling was being eaten one layer up.
parse_call(Line) ->
    case string:split(Line, "(") of
        [Name0, Rest0] ->
            case pascal(string:trim(Name0)) of
                false -> {error, no_call(Line)};
                true  -> closed_call(string:trim(Name0), Rest0, Line)
            end;
        _ ->
            {error, no_call(Line)}
    end.

closed_call(Name, Rest0, Line) ->
    case lists:reverse(string:trim(Rest0)) of
        [$) | RevInner] ->
            Inner = string:trim(lists:reverse(RevInner)),
            {list_to_atom(Name), bs_run:split_top_level(Inner)};
        _ ->
            {error, io_lib:format("missing closing ) in ~ts", [Line])}
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
