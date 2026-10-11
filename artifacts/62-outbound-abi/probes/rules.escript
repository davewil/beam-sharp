#!/usr/bin/env escript
%% usage: rules.escript PATCHED_EBIN  -> candidate PascalCase->snake_case rules side by side
main([Ebin]) ->
    code:add_patha(Ebin),
    Names = ["New", "NewHTTP", "ParseURL", "HTTPServer", "XMLHttpRequest", "ToJson", "OKResult",
             "V2Parse", "Parse2D", "Parse2d", "GetURLFor", "NewUrl", "NewURL", "IOList", "Id", "A", "AB"],
    io:format("~-16s ~-18s ~-18s ~-18s~n", ["B# name", "simple rule(A)", "Macro.underscore(B)", "per-capital(C)"]),
    [io:format("~-16s ~-18s ~-18s ~-18s~n", [N, atom_to_list(bs_emit:snake(list_to_atom(N))), macro_underscore(N), percap(N)]) || N <- Names].

%% (B) Elixir's rule, re-implemented from the decompiled Macro.do_underscore/2 shown in macro_underscore_src.out
%% (checked against the real Macro.underscore/1 in probe 07's elixir half).
macro_underscore([H | T]) -> lists:reverse(mu(T, [low(H)], H)).
mu([], Acc, _) -> Acc;
mu([H, T | Rest], Acc, _) when H >= $A, H =< $Z, not (T >= $A andalso T =< $Z), not (T >= $0 andalso T =< $9), T =/= $., T =/= $_ ->
    mu(Rest, [T, low(H), $_ | Acc], T);
mu([H | T], Acc, Prev) when H >= $A, H =< $Z, not (Prev >= $A andalso Prev =< $Z), Prev =/= $_ ->
    mu(T, [low(H), $_ | Acc], H);
mu([H | T], Acc, _) -> mu(T, [low(H) | Acc], H).
low(C) when C >= $A, C =< $Z -> C + 32;
low(C) -> C.

%% (C) Gleam's variant rule as observed in probe 02: every capital starts a new word
percap([H | T]) -> [low(H) | lists:append([case C >= $A andalso C =< $Z of true -> [$_, low(C)]; false -> [C] end || C <- T])].
