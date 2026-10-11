%%% bs_run — compile a .bs file and call one of its functions.
%%%
%%%     bsc fib.bs 5          =>  Fib(5) = 5
%%%
%%% Results print in beam-sharp notation, not Erlang's — `:positive`, not
%%% `positive` — because the reader is reading beam-sharp.
-module(bs_run).

-export([run/3, authors_exports/1, format_value/1, parse_arg/1, read_arg/1, read_arg/2,
         split_top_level/1]).

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
    Exports = authors_exports(Mod),
    case resolve(Mod, Exports, Argv) of
        {error, _} = E -> E;
        {Fn, RawArgs} ->
            case read_args(RawArgs) of
                {error, Msg} -> {error, {unreadable_argument, Msg}};
                {ok, Args} ->
                    case lists:member({Fn, length(Args)}, Exports) of
                        false -> {error, {bad_arity, Fn, length(Args), arities(Fn, Exports)}};
                        true  -> call(Mod, Fn, Args)
                    end
            end
    end.

read_args(Raw) ->
    lists:foldr(fun(_, {error, M}) -> {error, M};
                   (A, {ok, Acc}) ->
                        case read_arg(A) of
                            {ok, V}      -> {ok, [V | Acc]};
                            {error, Msg} -> {error, Msg}
                        end
                end, {ok, []}, Raw).

%% Three ways to name the function, in order. The middle one is the rule that
%% matters: under one function per file the file name is the function name, so
%% `bsc fib.bs 5` needs nothing else.
resolve(Mod, Exports, Argv) ->
    Names = [F || {F, _} <- Exports],
    case Argv of
        [Head | Rest] ->
            Named = list_to_atom(Head),
            case lists:member(Named, Names) of
                true  -> {Named, Rest};
                false ->
                    case lists:member(Named, private_names(Mod, Exports)) of
                        true  -> {error, {private, Mod, Named}};
                        false -> resolve_without_name(Mod, Exports, Names, Argv)
                    end
            end;
        [] ->
            resolve_without_name(Mod, Exports, Names, Argv)
    end.

%% A private function is absent from the export list, so naming one must say
%% "private" rather than fall through to the file-name rule and misread the
%% function name as an argument. `module_info(functions)` lists every function
%% the module defines, so nothing is threaded from the compiler. `erlc` deletes
%% an unexported uncalled function, so a dead private one falls to "no such
%% function".
private_names(Mod, Exports) ->
    Defined = [F || {F, _} <- Mod:module_info(functions), F =/= module_info],
    Defined -- [F || {F, _} <- Exports].

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
%%% Typed at a shell, so they arrive as strings. Integers, `:atom`, strings,
%%% tuples, lists and records are read in beam-sharp spelling; anything else
%%% falls through to the Erlang term reader.
%%% ---------------------------------------------------------------------------

%% `Env` holds the names the REPL has bound, threaded through every compound
%% form so a bound name resolves at any depth — `Pay({Total = t})`, not only
%% `Squared(t)`. Text the environment does not hold is parsed as a literal
%% by `parse_bare/2`; the CLI passes an empty environment.
parse_arg(S) -> parse_arg(S, #{}).

parse_arg(S0, Env) ->
    S = string:trim(S0),
    case maps:find(S, Env) of
        {ok, V} -> V;
        error   -> parse_bare(S, Env)
    end.

%% A quoted atom, `:'Shop.Order'`: a record tag mints from a qualified name,
%% and the bare sigil cannot spell a dot.
parse_bare([$:, $' | Rest], _Env) when Rest =/= [] ->
    case lists:last(Rest) of
        $' -> list_to_atom(lists:sublist(Rest, length(Rest) - 1));
        _  -> list_to_atom([$' | Rest])
    end;
parse_bare([$: | Name], _Env) -> list_to_atom(Name);
parse_bare(S, Env) ->
    case string:to_integer(S) of
        {Int, ""} -> Int;
        _         -> parse_compound(S, Env)
    end.

%% beam-sharp spells a tuple `(a, b)` and a list `[a, b]`, and `format_value/1`
%% prints them that way — so the REPL must accept back what it just printed.
%% Erlang term syntax stays available underneath for anything not yet spelled.
parse_compound(S, Env) ->
    case {hd_or(S), last_or(S)} of
        {$(, $)} -> list_to_tuple(parse_inner(S, Env));
        {$[, $]} -> parse_inner(S, Env);
        {${, $}} -> parse_braced(S, Env);
%% A beam-sharp string is a binary and prints as `"hello"`, so reading it back
%% must yield a binary, not Erlang's char list, or the value changes type on a
%% round trip.
%% Rationale: compiler/features/F9-strings-and-binaries.md.
        {$", $"} when length(S) >= 2 -> parse_string(S);
        _        -> parse_term(S)
    end.

%% Read through Erlang's scanner rather than by stripping quotes, so escapes
%% mean at the prompt what they mean in a `.bs` file, then re-encoded to
%% UTF-8: `erl_scan` yields codepoints and a beam-sharp string is bytes.
parse_string(S) ->
    case erl_scan:string(S ++ ".") of
        {ok, [{string, _, Chars}, {dot, _}], _} ->
            case unicode:characters_to_binary(Chars, unicode, utf8) of
                B when is_binary(B) -> B;
                _                   -> unreadable(S)
            end;
        _ -> unreadable(S)
    end.

%% A brace is a record — `{Id = 1, Kind = :'Shop.Order'}` — and a tuple is
%% parenthesised, as in C#. Every part of a record has a top-level `=`; parts
%% without one are refused rather than handed to the Erlang reader, because
%% `{}` is taken in beam-sharp and `{1, 2}` is malformed record syntax, not a
%% second spelling for a tuple.
parse_braced(S, Env) ->
    Parts = case string:trim(lists:sublist(S, 2, length(S) - 2)) of
                ""    -> [];
                Inner -> split_top_level(Inner)
            end,
    Fields = [field(P, Env) || P <- Parts],
    case Parts =/= [] andalso not lists:member(none, Fields) of
        true  -> maps:from_list(Fields);
        false -> throw({unreadable, brace_advice(S)})
    end.

%% Names both spellings, because the mistake is a spelling and the fix is one
%% character at each end.
brace_advice(S) ->
    io_lib:format("cannot read ~ts~n"
                  "  a brace is a record: `{ Id = 1, Total = 500 }`~n"
                  "  a tuple is parenthesised: `(1, 2)`", [S]).

%% A key is a name, an atom, or a string literal, a binary, as F58 writes it.
field(P, Env) ->
    case key_split(string:trim(P, leading)) of
        {"", _}       -> none;
        {[$" | _] = K, V} -> {parse_string(K), parse_arg(string:trim(V), Env)};
        {K, V}        -> {list_to_atom(K), parse_arg(string:trim(V), Env)};
        none          -> none
    end.

%% Split at the first `=` outside a string literal, so a key may hold one.
key_split([$" | _] = P) ->
    case string_end(tl(P), [$"]) of
        {Lit, Rest} ->
            case string:trim(Rest, leading) of
                [$= | V] -> {Lit, V};
                _        -> none
            end;
        none -> none
    end;
key_split(P) ->
    case string:split(P, "=") of
        [K, V] -> {string:trim(K), V};
        _      -> none
    end.

string_end([$\\, C | T], Acc) -> string_end(T, [C, $\\ | Acc]);
string_end([$" | T], Acc)      -> {lists:reverse([$" | Acc]), T};
string_end([C | T], Acc)       -> string_end(T, [C | Acc]);
string_end([], _Acc)           -> none.

parse_inner(S, Env) ->
    Inner = string:trim(lists:sublist(S, 2, length(S) - 2)),
    case Inner of
        "" -> [];
        _  -> [parse_arg(P, Env) || P <- split_top_level(Inner)]
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

%% Returns {ok, Term} | {error, Message}. The inner parser throws rather than
%% returning a result type, so the recursive cases stay readable.
read_arg(S) -> read_arg(S, #{}).

read_arg(S, Env) ->
    try {ok, parse_arg(S, Env)}
    catch throw:{unreadable, Msg} -> {error, Msg} end.

parse_term(S) ->
    case erl_scan:string(S ++ ".") of
        {ok, Toks, _} ->
            case erl_parse:parse_term(Toks) of
                {ok, Term} -> Term;
                {error, _} -> unreadable(S)
            end;
        {error, _, _} -> unreadable(S)
    end.

%% An argument the reader cannot read is refused with a sentence, never handed
%% to the function as a binary. The two named cases are the two mistakes the
%% surface invites: arguments are values, so neither construction nor a nested
%% call is available.
unreadable(S) ->
    throw({unreadable, explain(S)}).

explain(S) ->
    case declaration(S) of
        {true, Word} -> declaration_advice(S, Word);
        false        -> explain_value(S)
    end.

%% A declaration typed at the prompt, `record Order { … }`, is answered with
%% where it goes — the file, then `:reload` — rather than "cannot read as a
%% value": the prompt evaluates calls and values against a compiled module.
declaration(S) ->
    Word = string:trim(hd(string:split(string:trim(S), " "))),
    case lists:member(Word, ["module", "type", "record", "using", "behaviour"]) of
        true  -> {true, Word};
        false -> false
    end.

declaration_advice(S, Word) ->
    io_lib:format("cannot read ~ts: `~s` declares something, and the prompt "
                  "evaluates calls and values against a module that is already "
                  "compiled.~n"
                  "  put the declaration in the .bs file and `:reload`",
                  [S, Word]).

explain_value(S) ->
    case {construction(S), lists:member($(, S)} of
        {true, _} ->
            io_lib:format("cannot read ~ts: record construction is not available "
                          "in an argument. Pass the value instead, as "
                          "{Kind = :'Module.Name', Field = ...}", [S]);
        {_, true} ->
            io_lib:format("cannot read ~ts: arguments are values, not calls -- "
                          "there is nothing here to evaluate one with", [S]);
        _ ->
            io_lib:format("cannot read ~ts as a value", [S])
    end.

%% `Order{...}` — a PascalCase name against a brace.
construction([C | Rest]) when C >= $A, C =< $Z ->
    case lists:dropwhile(fun(X) -> X =/= ${ end, Rest) of
        [${ | _] -> true;
        _        -> false
    end;
construction(_) -> false.

%%% ---------------------------------------------------------------------------
%%% Rendering a result in beam-sharp notation
%%% ---------------------------------------------------------------------------

%% An atom is quoted where the bare sigil cannot spell it, by the same rule the
%% residual printer uses, so a record's minted tag round-trips through the
%% shell rather than printing as something that cannot be typed back in.
format_value(A) when is_atom(A) -> bs_types:atom_str(A);
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
%% `Kind` first: it is the discriminator, so it is what a reader looks for to
%% know which record they are holding. The rest sort, so output is stable.
%% A key is an atom or a UTF-8 string, as F58 writes one; a map with any other
%% key has no beam-sharp spelling and prints in Erlang's, keys in order.
format_value(M) when is_map(M) ->
    Keys = lists:sort(maps:keys(M)),
    case lists:all(fun spelled_key/1, Keys) of
        true ->
            Ordered = case lists:member('Kind', Keys) of
                          true  -> ['Kind' | lists:delete('Kind', Keys)];
                          false -> Keys
                      end,
            ["{", lists:join(", ", [[key_text(K), " = ",
                                     format_value(maps:get(K, M))]
                                    || K <- Ordered]), "}"];
        false ->
            io_lib:format("~kp", [M])
    end;
format_value(Other) -> io_lib:format("~p", [Other]).

spelled_key(K) when is_atom(K)   -> true;
spelled_key(K) when is_binary(K) -> is_list(unicode:characters_to_list(K));
spelled_key(_)                   -> false.

key_text(K) when is_atom(K) -> atom_to_list(K);
key_text(K)                 -> bs_types:key_str(K).

%% The export list minus what the author did not write: `module_info` is the
%% VM's, and `bs@…` is the compiler's (`'bs@type_atoms'/0` on every module).
%% The one definition; the REPL banner and visibility tests read this rather
%% than restating it.
%% Rationale: compiler/features/F55-type-atoms-in-the-chunk.md.
authors_exports(Mod) ->
    [{F, A} || {F, A} <- Mod:module_info(exports),
               F =/= module_info, not lists:prefix("bs@", atom_to_list(F))].
