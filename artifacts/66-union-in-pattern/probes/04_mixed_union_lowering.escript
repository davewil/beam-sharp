#!/usr/bin/env escript
%% Probe 04: correctness of the guard-disjunction lowering when the parameter is
%% WIDER than the union (D = A | B | :none, the exemplar-3 shape), against the
%% duplicate-per-member lowering, on hostile inputs: non-map terms, a map with
%% no Kind, a map with a Kind outside the union, members, and :none.
%% Command: escript 04_mixed_union_lowering.escript
%% Fails (halt 1) on any disagreement between lowerings.
main(_) ->
    Dup = "-module(dup).\n-export([h/1]).\n"
          "h(#{'Kind' := 'T.A'} = C) -> {u, maps:get('Id', C)};\n"
          "h(#{'Kind' := 'T.B'} = C) -> {u, maps:get('Id', C)};\n"
          "h(none) -> none.\n",
    %% A: pattern-bound Kind + `;` guard (what the head-position prefix would emit)
    GA = "-module(ga).\n-export([h/1]).\n"
         "h(#{'Kind' := K} = C) when K =:= 'T.A'; K =:= 'T.B' -> {u, maps:get('Id', C)};\n"
         "h(none) -> none.\n",
    %% B: no pattern, guard only (what a non-head slot would have to emit):
    %%    exercises map_get on non-maps inside a guard.
    GB = "-module(gb).\n-export([h/1]).\n"
         "h(C) when is_map(C), (map_get('Kind', C) =:= 'T.A' orelse map_get('Kind', C) =:= 'T.B') -> {u, maps:get('Id', C)};\n"
         "h(none) -> none.\n",
    %% C: NO is_map guard, to show whether a guard failure is silent (expected: yes)
    GC = "-module(gc).\n-export([h/1]).\n"
         "h(C) when map_get('Kind', C) =:= 'T.A'; map_get('Kind', C) =:= 'T.B' -> {u, maps:get('Id', C)};\n"
         "h(none) -> none.\n",
    Mods = [dup, ga, gb, gc],
    [load(M, S) || {M, S} <- lists:zip(Mods, [Dup, GA, GB, GC])],
    Inputs = [#{'Kind' => 'T.A', 'Id' => 1}, #{'Kind' => 'T.B', 'Id' => 2},
              #{'Kind' => 'T.E', 'Id' => 3}, #{'Id' => 4}, none, other, 7, 1.5, "s", {t}, [], <<"b">>],
    Run = fun(M) -> [try M:h(X) catch error:R -> {err, case R of T when is_tuple(T) -> element(1, T); _ -> R end} end || X <- Inputs] end,
    Ref = Run(dup),
    io:format("reference (dup):~n"), [io:format("  ~p -> ~p~n", [I, R]) || {I, R} <- lists:zip(Inputs, Ref)],
    Bad = [M || M <- tl(Mods), Run(M) =/= Ref],
    [io:format("lowering ~p: ~s~n", [M, case lists:member(M, Bad) of true -> "DISAGREES"; false -> "agrees on all " ++ integer_to_list(length(Inputs)) ++ " inputs" end]) || M <- tl(Mods)],
    case Bad of [] -> ok; _ -> halt(1) end.

load(M, Src) ->
    F = "/tmp/p66_04_" ++ atom_to_list(M) ++ ".erl", ok = file:write_file(F, Src),
    {ok, M, Bin} = compile:file(F, [binary, return_errors]),
    {module, M} = code:load_binary(M, F, Bin).
