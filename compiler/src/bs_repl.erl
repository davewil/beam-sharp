%%% bs_repl — an interactive shell over a compiled .bs file.
%%%
%%%     ibs -S fib.bs
%%%     Fib(5)
%%%     5
%%%
%%% Not an expression evaluator: the parser reads declarations, not
%%% expressions, so the prompt reads a CALL, a value, or a binding of one,
%%% against a module that is already compiled. `:reload` recompiles the file
%%% in place, so edit, reload, call again never leaves the shell.
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

%% Every function the module DEFINES, private ones included (F12).
defined(Mod) ->
    try [{F, A} || {F, A} <- Mod:module_info(functions), F =/= module_info]
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
%%% Bindings at the prompt
%%%
%%% A name bound at the prompt is held across prompts, which is a property of
%%% this shell and not of the language, where a binding belongs to a body
%%% (ticket 34). The environment does not survive `:reload`, since its values
%%% came from code that has just been replaced.
%%% ---------------------------------------------------------------------------

run(Line, Mod, Env) ->
    case binding(Line) of
        %% `var <pattern> = e` — a destructuring bind, so introductions are the
        %% point. A bare `=` takes the clause below and may introduce nothing.
        {match_intro, Pat, Rhs} -> do_match(Pat, Rhs, Mod, Env, true);
        {match, Pat, Rhs}       -> do_match(Pat, Rhs, Mod, Env, false);
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

do_match(Pat, Rhs, Mod, Env, Intro) ->
    case value_of(Rhs, Mod, Env) of
        {ok, V} ->
            case match(Pat, V, Env, Intro) of
                {ok, Env1} ->
                    io:format("~s~n", [bs_run:format_value(V)]),
                    Env1;
                {error, Msg} ->
                    io:format(standard_error, "~ts~n", [Msg]), Env
            end;
        {error, Msg} ->
            io:format(standard_error, "~ts~n", [Msg]), Env
    end.

%% A line that is a call is never a binding, even though a record argument
%% carries `=` inside it: `Squared({Kind = :'M.Order', Id = 1})` must not be
%% split at its first `=`. Any other line is split on the first `=`, since
%% the right-hand side may hold more of them.
binding(Line) ->
    %% `{error, _}` first: a call result is also a two-tuple, so the general
    %% clause would swallow it.
    case parse_call(Line) of
        {error, _}   -> split_binding(Line);
        {_Fn, _Args} -> none
    end.

split_binding(Line) ->
    case split_eq(Line) of
        [Lhs0, Rhs0] ->
            Lhs = string:trim(Lhs0),
            Rhs = string:trim(Rhs0),
            case Lhs of
                "" -> none;
                %% `var` INTRODUCES, at the prompt exactly as in a file (F8).
                "var " ++ Pat0 ->
                    case string:trim(Pat0) of
                        ""  -> none;
                        Pat ->
                            case is_name(Pat) of
                                %% Keyed by the name AS TYPED, because that
                                %% is what the reader has to match when it
                                %% meets the name nested in a literal.
                                true  -> {Pat, Rhs};
                                false -> {match_intro, Pat, Rhs}
                            end
                    end;
                %% A bare `=` MATCHES and may not introduce (F8): after
                %% `x = 1`, `1 = x` passes and `2 = x` is an error, as in
                %% Elixir. A plain name here is the mistake `match/4` names.
                _ -> {match, Lhs, Rhs}
            end;
        _ -> none
    end.

%% Split on the first `=` that is not part of `==`: ticket 45 put `==` in
%% patterns, so `(== n, b) = p` must not be cut after `(`, and the right-hand
%% side may still hold any number of `=`.
split_eq(Line) -> split_eq(Line, []).

split_eq([$=, $= | T], Acc) -> split_eq(T, [$=, $= | Acc]);
split_eq([$= | T], Acc)     -> [lists:reverse(Acc), T];
split_eq([C | T], Acc)      -> split_eq(T, [C | Acc]);
split_eq([], _Acc)          -> [].

%% Every name a prompt pattern would INTRODUCE. A bare `=` may introduce
%% nothing, which is the parser's `to_match/1` rule on the shell's
%% surface (F8.8).
introduced(wild)         -> [];
introduced({bind, N})    -> [N];
introduced({lit, _})     -> [];
introduced({tuple, Ps})  -> lists:append([introduced(P) || P <- Ps]);
introduced({list, Ps})   -> lists:append([introduced(P) || P <- Ps]);
introduced(_)            -> [].

%%% ---------------------------------------------------------------------------
%%% `=` is a MATCH, not an assignment
%%%
%%% In a file `x = 1` then `1 = x` is accepted and `2 = x` is a compile error,
%%% because F5 proves whether a bind can fail. The prompt has no compile step,
%%% so the same check runs against the value the name holds: same rule, same
%%% message shape. A bare name INTRODUCES and `== name` matches the value a
%%% name already holds, on both surfaces (F8.8, tickets 34 and 45), so a bare
%%% rebinding is an error here as it is in a file.
%%% ---------------------------------------------------------------------------

%% `Intro` says whether this match may introduce names: `var` says yes, a
%% bare `=` says no. Same rule as `to_match/1` in the parser, and it is here
%% rather than in the caller so the check sits next to the pattern it is about.
match(Text, Value, Env, Intro) ->
    case pattern(string:trim(Text), Env) of
        {error, Msg} -> {error, Msg};
        {ok, Pat} when not Intro ->
            case lists:usort(introduced(Pat)) of
                [] -> unify(Pat, Value, Env, {Text, Value});
                [N | _] ->
                    {error, io_lib:format(
                       "~ts is introduced here, and a bare `=` matches rather "
                       "than introduces -- write `var ~ts = ...`",
                       [N, string:trim(Text)])}
            end;
        %% The whole value travels with the recursion so a nested failure
        %% reports what the author typed against what they typed it at —
        %% reporting the failing COMPONENT said "(9, _) does not match 1",
        %% which names a number nobody wrote.
        {ok, Pat}    -> unify(Pat, Value, Env, {Text, Value})
    end.

%% A pattern is read from the same surface the value reader takes, with one
%% difference: an unbound lowercase name is a BINDER rather than an error.
pattern("_", _Env) -> {ok, wild};
%% `== name` MATCHES the value a name already holds (F8, ticket 45). This
%% replaced pin-by-default at the prompt: the compiler and the prompt
%% disagreed, and the marked rule won.
pattern([$=, $= | Rest], Env) ->
    Name = string:trim(Rest),
    case is_name(Name) of
        true ->
            case maps:find(Name, Env) of
                {ok, V} -> {ok, {lit, V}};
                error   -> {error, io_lib:format(
                              "~ts is not bound, so `== ~ts` has nothing to match "
                              "against -- :env lists what is", [Name, Name])}
            end;
        false -> {error, "`==` in a pattern must be followed by a name"}
    end;
pattern(S, Env) ->
    case is_name(S) of
        true ->
            case maps:find(S, Env) of
                %% Already bound, and a bare name INTRODUCES, so this is a
                %% rebinding, which is an error (ticket 34). Caught against
                %% the value the name holds, since the prompt has no compile
                %% step.
                {ok, _V} -> {error, io_lib:format(
                               "~ts is already bound -- a name means one thing. "
                               "Write `== ~ts` to match the value it holds",
                               [S, S])};
                error    -> {ok, {bind, S}}
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

%% A bare name resolves from the environment before anything tries to read
%% it; otherwise `Squared(t)` would pass the ATOM `t`, the Erlang reader's
%% fallback. beam-sharp spells an atom `:t`, so nothing is lost. `true` and
%% `false` are the only atoms spelled without the sigil (LANGUAGE.md §4), so
%% they are matched before the name lookup could report them unbound.
resolve("true", _Env)  -> {ok, true};
resolve("false", _Env) -> {ok, false};
resolve(S, Env) ->
    case maps:find(S, Env) of
        {ok, V} -> {ok, V};
        error ->
            case is_name(S) of
                true  -> {error, io_lib:format("~ts is not bound -- :env lists "
                                               "what is", [S])};
                %% Anything compound goes to the reader WITH the environment,
                %% so a bound name nested in a literal resolves too.
                false -> bs_run:read_arg(S, Env)
            end
    end.

%%% ---------------------------------------------------------------------------
%%% One form: Name(arg, arg, ...)
%%% ---------------------------------------------------------------------------

%% `apply/3` below is constrained to a {name, arity} pair checked against the
%% export list of a module the user compiled from their own source, in a local
%% shell: there is no wider evaluation and no untrusted input path.
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
            %% "No such function" and "you may not call it" are different
            %% sentences, and `module_info/1` carries the definition list
            %% beside the export list, so the prompt tells them apart with
            %% nothing passed in from the compiler (F12).
            case lists:member({Fn, length(Args)}, defined(Mod)) of
                true ->
                    {error, io_lib:format("~s/~p is private in ~s -- defined, "
                                          "not exported", [Fn, length(Args), Mod])};
                false ->
                    {error, io_lib:format("no ~s/~p -- try :exports",
                                          [Fn, length(Args)])}
            end;
        true ->
            try {ok, apply(Mod, Fn, Args)}
            catch C:R -> {error, io_lib:format("crashed: ~p:~p", [C, R])} end
    end.

%% A call's name must be PascalCase, because that is what the grammar says a
%% call IS — `expr -> uident '(' expr_list ')'`. Without this check any text
%% before a `(` was taken for a function name, and `x = (1, 2)` became a call
%% to a nameless function instead of a tuple.
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

%% The prompt reads a call or a value, so anything else says what it got
%% rather than only what it wanted, and states no language rule: a message
%% that states one is a claim, and it goes stale exactly as a reference does.
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
