%%% bs_run — compile a .bs file and call one of its functions.
%%%
%%%     bsc fib.bs 5          =>  Fib(5) = 5
%%%
%%% Development is driven by runnable code (David, 2026-08-14), so the compiler
%%% owes a way to *see a program run* without a second `erl -pa` invocation and a
%%% hand-written eval string. Ticket 23's scope clarification puts this in: a
%%% capability the language owes its author is in scope where the ecosystem track
%%% is not.
%%%
%%% Results print in **beam-sharp** notation, not Erlang's — `:positive`, not
%%% `positive` — because the person reading the output is reading beam-sharp.
-module(bs_run).

-export([run/3, format_value/1, parse_arg/1, split_top_level/1]).

%%% ---------------------------------------------------------------------------
%%% Running
%%% ---------------------------------------------------------------------------

%% Dir holds the built .beam; Mod is the module atom the compiler emitted;
%% Argv is everything the user typed after the file name.
run(Dir, Mod, Argv) ->
    true = code:add_patha(Dir),
    case code:ensure_loaded(Mod) of
        {module, Mod} -> resolve_and_call(Mod, Argv);
        {error, R}    -> {error, {cannot_load, Mod, R}}
    end.

resolve_and_call(Mod, Argv) ->
    Exports = [{F, A} || {F, A} <- Mod:module_info(exports), F =/= module_info],
    case resolve(Mod, Exports, Argv) of
        {error, _} = E -> E;
        {Fn, RawArgs} ->
            Args = [parse_arg(A) || A <- RawArgs],
            case lists:member({Fn, length(Args)}, Exports) of
                false -> {error, {bad_arity, Fn, length(Args), arities(Fn, Exports)}};
                true  -> call(Mod, Fn, Args)
            end
    end.

%% Three ways to name the function, in order. The middle one is the rule that
%% matters: under one function per file the file name *is* the function name, so
%% `bsc fib.bs 5` needs nothing else. The first and last exist because the
%% examples predating that convention put several functions in one file.
resolve(Mod, Exports, Argv) ->
    Names = [F || {F, _} <- Exports],
    case Argv of
        [Head | Rest] ->
            case lists:member(list_to_atom(Head), Names) of
                true  -> {list_to_atom(Head), Rest};
                false -> resolve_without_name(Mod, Exports, Names, Argv)
            end;
        [] ->
            resolve_without_name(Mod, Exports, Names, Argv)
    end.

resolve_without_name(Mod, Exports, Names, Argv) ->
    FromFile = pascal(atom_to_list(Mod)),
    case lists:member(FromFile, Names) of
        true -> {FromFile, Argv};
        false ->
            case Exports of
                [{Only, _}] -> {Only, Argv};
                _           -> {error, {ambiguous, lists:usort(Names)}}
            end
    end.

call(Mod, Fn, Args) ->
    try apply(Mod, Fn, Args) of
        Value -> {ok, Value}
    catch
        Class:Reason:Stack -> {crashed, Class, Reason, Stack}
    end.

arities(Fn, Exports) -> lists:sort([A || {F, A} <- Exports, F =:= Fn]).

pascal([C | Rest]) when C >= $a, C =< $z -> list_to_atom([C - 32 | Rest]);
pascal(S) -> list_to_atom(S).

%%% ---------------------------------------------------------------------------
%%% Arguments
%%%
%%% Typed at a shell, so they arrive as strings. Integers and `:atom` cover the
%%% surface the skeleton actually has; anything else is parsed as an Erlang term
%%% so a tuple subject (`"{ok,5}"`) can be passed without waiting on a beam-sharp
%%% literal parser this slice does not have.
%%% ---------------------------------------------------------------------------

parse_arg([$: | Name]) -> list_to_atom(Name);
parse_arg(S0) ->
    S = string:trim(S0),
    case string:to_integer(S) of
        {Int, ""} -> Int;
        _         -> parse_compound(S)
    end.

%% beam-sharp spells a tuple `(a, b)` and a list `[a, b]`, and `format_value/1`
%% prints them that way — so the REPL must accept back what it just printed.
%% Erlang term syntax stays available underneath for anything not yet spelled.
parse_compound(S) ->
    case {hd_or(S), last_or(S)} of
        {$(, $)} -> list_to_tuple(parse_inner(S));
        {$[, $]} -> parse_inner(S);
        _        -> parse_term(S)
    end.

parse_inner(S) ->
    Inner = string:trim(lists:sublist(S, 2, length(S) - 2)),
    case Inner of
        "" -> [];
        _  -> [parse_arg(P) || P <- split_top_level(Inner)]
    end.

hd_or([C | _]) -> C;
hd_or(_) -> none.

last_or([]) -> none;
last_or(L) -> lists:last(L).

%% Split on top-level commas only, so `(:ok, (1, 2))` and `{ok,5}` survive.
split_top_level("") -> [];
split_top_level(S) -> split_top_level(S, 0, [], []).

split_top_level([], _, Cur, Acc) ->
    lists:reverse([string:trim(lists:reverse(Cur)) | Acc]);
split_top_level([$, | T], 0, Cur, Acc) ->
    split_top_level(T, 0, [], [string:trim(lists:reverse(Cur)) | Acc]);
split_top_level([C | T], D, Cur, Acc) when C =:= $(; C =:= ${; C =:= $[ ->
    split_top_level(T, D + 1, [C | Cur], Acc);
split_top_level([C | T], D, Cur, Acc) when C =:= $); C =:= $}; C =:= $] ->
    split_top_level(T, D - 1, [C | Cur], Acc);
split_top_level([C | T], D, Cur, Acc) ->
    split_top_level(T, D, [C | Cur], Acc).

parse_term(S) ->
    case erl_scan:string(S ++ ".") of
        {ok, Toks, _} ->
            case erl_parse:parse_term(Toks) of
                {ok, Term} -> Term;
                {error, _} -> list_to_binary(S)
            end;
        {error, _, _} -> list_to_binary(S)
    end.

%%% ---------------------------------------------------------------------------
%%% Rendering a result in beam-sharp notation
%%% ---------------------------------------------------------------------------

format_value(A) when is_atom(A) -> [$:, atom_to_list(A)];
format_value(I) when is_integer(I) -> integer_to_list(I);
format_value(F) when is_float(F) -> io_lib:format("~p", [F]);
format_value(B) when is_binary(B) ->
    case unicode:characters_to_list(B) of
        L when is_list(L) -> [$", L, $"];
        _ -> io_lib:format("~p", [B])
    end;
format_value(T) when is_tuple(T) ->
    ["(", lists:join(", ", [format_value(E) || E <- tuple_to_list(T)]), ")"];
format_value(L) when is_list(L) ->
    ["[", lists:join(", ", [format_value(E) || E <- L]), "]"];
format_value(M) when is_map(M) ->
    ["{", lists:join(", ", [[atom_to_list(K), " = ", format_value(V)]
                            || {K, V} <- maps:to_list(M)]), "}"];
format_value(Other) -> io_lib:format("~p", [Other]).
