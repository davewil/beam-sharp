#!/usr/bin/env escript
%% p1: how do stdlib lookups tell "key absent" from "key present, value = the
%% atom a caller would use as the absence marker"?
%% Run: escript p1_erlang_lookup_shapes.escript > p1_erlang_lookup_shapes.out
%% Exit 1 if any ASSERT fails. Expected values are never hard-coded: each ASSERT
%% compares two OBSERVED results.
main(_) ->
    Absent  = #{},                          %% key k not present
    StoredN = #{k => nothing},              %% key k present, value is atom nothing
    StoredU = #{k => undefined},
    StoredE = #{k => error},
    PAbsent = [], PStored = [{k, undefined}],
    D0 = dict:new(), D1 = dict:store(k, nothing, D0),
    Rows = [
      {"maps:find(k,M)  [absent]",            maps:find(k, Absent)},
      {"maps:find(k,M)  [stored nothing]",    maps:find(k, StoredN)},
      {"maps:find(k,M)  [stored error]",      maps:find(k, StoredE)},
      {"maps:get(k,M,nothing) [absent]",      maps:get(k, Absent, nothing)},
      {"maps:get(k,M,nothing) [stored nothing]", maps:get(k, StoredN, nothing)},
      {"maps:get(k,M,undefined) [absent]",    maps:get(k, Absent, undefined)},
      {"maps:get(k,M,undefined) [stored undefined]", maps:get(k, StoredU, undefined)},
      {"proplists:get_value(k,L) [absent]",   proplists:get_value(k, PAbsent)},
      {"proplists:get_value(k,L) [stored undefined]", proplists:get_value(k, PStored)},
      {"dict:find(k,D)  [absent]",            dict:find(k, D0)},
      {"dict:find(k,D)  [stored nothing]",    dict:find(k, D1)}
    ],
    [io:format("~-48s -> ~p~n", [L, R]) || {L, R} <- Rows],
    R = fun(L) -> element(2, lists:keyfind(L, 1, Rows)) end,
    Asserts = [
      %% untagged forms conflate
      {"untagged maps:get/3: absent == stored-nothing",
         R("maps:get(k,M,nothing) [absent]") =:= R("maps:get(k,M,nothing) [stored nothing]")},
      {"untagged maps:get/3 (undefined): absent == stored-undefined",
         R("maps:get(k,M,undefined) [absent]") =:= R("maps:get(k,M,undefined) [stored undefined]")},
      {"proplists:get_value/2: absent == stored-undefined",
         R("proplists:get_value(k,L) [absent]") =:= R("proplists:get_value(k,L) [stored undefined]")},
      %% tagged forms separate
      {"maps:find/2: absent /= stored-nothing",
         R("maps:find(k,M)  [absent]") =/= R("maps:find(k,M)  [stored nothing]")},
      {"maps:find/2: absent /= stored-error",
         R("maps:find(k,M)  [absent]") =/= R("maps:find(k,M)  [stored error]")},
      {"dict:find/2: absent /= stored-nothing",
         R("dict:find(k,D)  [absent]") =/= R("dict:find(k,D)  [stored nothing]")},
      %% the ambiguity of maps:find's own absence atom: it is `error`, so a map
      %% that stores the atom error is still safe ONLY because the success is wrapped
      {"maps:find/2 absent is bare atom error (the atom a map<string,term> may store)",
         R("maps:find(k,M)  [absent]") =:= error}
    ],
    Bad = [N || {N, false} <- Asserts],
    [io:format("ASSERT ~-72s ~s~n", [N, case V of true -> "holds"; false -> "FAILS" end]) || {N, V} <- Asserts],
    case Bad of [] -> halt(0); _ -> io:format("FAILED: ~p~n", [Bad]), halt(1) end.
