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

-export([run/3, format_value/1, parse_arg/1, read_arg/1, read_arg/2,
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
    Exports = [{F, A} || {F, A} <- Mod:module_info(exports), F =/= module_info],
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
%% matters: under one function per file the file name *is* the function name, so
%% `bsc fib.bs 5` needs nothing else. The first and last exist because the
%% examples predating that convention put several functions in one file.
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

%% F12 — WHAT THE BEAM ALREADY KNOWS, and what it costs to ask it.
%%
%% After ticket 40 §3 a private function is simply absent from the export list,
%% so naming one here used to fall through `resolve_without_name/4`, match the
%% file-name rule, take the module's public function instead, and then try to
%% read the FUNCTION NAME as an argument — reporting an unreadable argument for
%% something that was never an argument. Measured before it shipped; it is the
%% fifth instance of the shape that fails by going quiet.
%%
%% `module_info(functions)` lists every function the module defines, exported or
%% not (measured on OTP 28), so the true sentence needs nothing threaded down
%% from the compiler — and the REPL, which shares this path, gets it for free.
%%
%% ONE BOUNDARY, MEASURED RATHER THAN ASSUMED: `erlc` DELETES an unexported
%% function that nothing calls, warning `function 'Half'/1 is unused`. So a
%% private function that is genuinely dead is not in the beam at all, and this
%% falls back to "no such function" — which is the true sentence for it. Every
%% private function in the corpus is called, so the fallback is the rare path
%% and not the common one. Worth knowing rather than fixing: threading the
%% compiler's own private set down here would buy a better message only for code
%% the compiler has just told you to delete.
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
%%% Typed at a shell, so they arrive as strings. Integers and `:atom` cover the
%%% surface the skeleton actually has; anything else is parsed as an Erlang term
%%% so a tuple subject (`"{ok,5}"`) can be passed without waiting on a beam-sharp
%%% literal parser this slice does not have.
%%% ---------------------------------------------------------------------------

%% A quoted atom — `:'Shop.Order'`. Records made this reachable from the command
%% line, because ticket 26 §1's tag mints from a qualified name and a dot is not
%% something the bare sigil can spell.
%% An environment of names the REPL has bound. Threaded through the compound
%% forms so a bound name works at any DEPTH — `Pay({Total = t})` and not only
%% `Squared(t)`. Without it the inner `t` fell through to the Erlang reader and
%% came back as the atom `t`, which then failed arithmetic three frames later:
%% the same silent-wrong-value shape as the binary fallback this replaced.
%%
%% Purely additive — a name the environment does not hold behaves exactly as
%% before, so the CLI, which never has one, is unchanged.
parse_arg(S) -> parse_arg(S, #{}).

parse_arg(S0, Env) ->
    S = string:trim(S0),
    case maps:find(S, Env) of
        {ok, V} -> V;
        error   -> parse_bare(S, Env)
    end.

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
        %% F9, and it is the round-trip rule above rather than a new one. A
        %% beam-sharp string is a BINARY, and `format_value/1` prints a binary as
        %% `"hello"` — so handing that back to the reader has to produce a
        %% binary. Erlang's own reader makes it a char list, which then prints
        %% back as `[104, 101, ...]`: the value changes type on a round trip and
        %% the prompt stops being able to show you what it just showed you.
        {$", $"} when length(S) >= 2 -> parse_string(S);
        _        -> parse_term(S)
    end.

%% Read through Erlang's scanner rather than by stripping quotes, so escapes mean
%% at the prompt what they mean in a `.bs` file, and then re-encode to UTF-8 —
%% `erl_scan` yields codepoints and a beam-sharp string is bytes.
parse_string(S) ->
    case erl_scan:string(S ++ ".") of
        {ok, [{string, _, Chars}, {dot, _}], _} ->
            case unicode:characters_to_binary(Chars, unicode, utf8) of
                B when is_binary(B) -> B;
                _                   -> unreadable(S)
            end;
        _ -> unreadable(S)
    end.

%% In beam-sharp a brace is a RECORD — `{Id = 1, Kind = :'Shop.Order'}`. The
%% discriminator is a top-level `=` in every part, which a record always has.
%%
%% When the parts have no `=` this falls through to the Erlang reader, so
%% `{1, 2}` is accepted as an Erlang tuple — and printed back as `(1, 2)`,
%% because `format_value/1` prints beam-sharp. David caught the asymmetry at the
%% prompt on 2026-08-15: *"we've got a weird syntax on tuples here — entered as
%% `x = {1, 2}`, output as `(1,2)`."*
%%
%% **The cause was one layer up and is fixed**: he reached for braces because
%% `(1, 2)` was being eaten by `parse_call/1`, which took any text before a `(`
%% for a function name.
%%
%% **RULED 2026-08-15 (David): *"I don't want to fight the erlang compiler if
%% tuples are better expressed with {} over (). If () for tuples to match C# is
%% doable that is preferable."*** It is doable, and it is already done — measured
%% rather than assumed: `type Pair = (int, int)`, `Swap((a, b)) -> (b, a)` and
%% `(:ok, n)` all compile and run, and lower to `{tuple, L, …}` abstract-format
%% terms. **There was never a fight to have**, because ticket 13 emits *terms*
%% rather than Erlang source text, so Erlang's own `{}` syntax appears nowhere a
%% person or the compiler writes.
%%
%% So the Erlang fallback goes. It was not a second spelling for a tuple — `{}`
%% is *taken* in beam-sharp, it means a record or a map type, so `{1, 2}` was
%% malformed record syntax being silently reinterpreted as something else. That
%% supersedes `an_erlang_term_is_still_readable_test`'s reasoning ("the fallback
%% that was removed was the SILENT one, not this"): this one was silent too, just
%% about a different thing.
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

field(P, Env) ->
    case string:split(P, "=") of
        [K, V] ->
            case string:trim(K) of
                ""   -> none;
                Name -> {list_to_atom(Name), parse_arg(string:trim(V), Env)}
            end;
        _ -> none
    end.

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

%% This used to be `list_to_binary(S)`, which meant an argument the reader could
%% not understand was silently handed to the function as a binary — so
%% `Pay(Order{Id = 1})` crashed with `{badmap, <<"Order{Id = 1}">>}`, showing the
%% user their own source text inside an error about a map. A reader that cannot
%% read something should say so, which is ticket 23's rule reaching the one
%% place a person actually types at.
%%
%% The two named cases are the two mistakes the surface invites: arguments here
%% are VALUES, so neither construction nor a nested call is available.
unreadable(S) ->
    throw({unreadable, explain(S)}).

explain(S) ->
    case declaration(S) of
        {true, Word} -> declaration_advice(S, Word);
        false        -> explain_value(S)
    end.

%% A DECLARATION typed at the prompt. `record Order { … }` is the shape David
%% reached for on 2026-08-15, and the old answer — *"cannot read … as a value"* —
%% was true and useless: it named what the prompt wanted rather than where the
%% thing he was typing actually goes.
%%
%% The prompt evaluates calls and values against a module that is already
%% compiled; it is not an evaluator and has never claimed to be. So the honest
%% answer names the route that works, which is the file plus `:reload`.
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

%% Quoted where the bare sigil cannot spell it, using the SAME rule the residual
%% printer uses — so a record's minted tag round-trips through the shell rather
%% than printing as something that cannot be typed back in.
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
format_value(M) when is_map(M) ->
    Keys = lists:sort(maps:keys(M)),
    Ordered = case lists:member('Kind', Keys) of
                  true  -> ['Kind' | lists:delete('Kind', Keys)];
                  false -> Keys
              end,
    ["{", lists:join(", ", [[atom_to_list(K), " = ", format_value(maps:get(K, M))]
                            || K <- Ordered]), "}"];
format_value(Other) -> io_lib:format("~p", [Other]).
