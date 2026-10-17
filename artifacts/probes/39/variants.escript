#!/usr/bin/env escript
%% usage: variants.escript BS_ABSTR OUTDIR
%% From the .abstr bsc emitted for aoc/bench/Day01, builds four variants of the
%% beam-sharp module under different module names, each as .beam and .S:
%%   bs0 as emitted | bs1 specs stripped | bs2 boundary `case ... is_integer`
%%   removed | bs3 both.
%% bs2/bs3 emulate the 2026-08-15 emission, before a foreign return was guarded.
main([Abstr, Out]) ->
    {ok, Forms} = file:consult(Abstr),
    lists:foreach(
      fun({Name, Strip}) ->
              F = [rename(X, Name) || X <- strip(Forms, Strip)],
              Path = filename:join(Out, atom_to_list(Name) ++ ".abstr"),
              ok = file:write_file(Path, [io_lib:format("~p.~n", [X]) || X <- F]),
              {ok, Name} = compile:file(Path, [from_abstr, debug_info, {outdir, Out}]),
              {ok, Name} = compile:file(Path, [from_abstr, 'S', {outdir, Out}])
      end,
      [{bs0, []}, {bs1, [spec]}, {bs2, [guard]}, {bs3, [spec, guard]}, {bs4, [inline]}, {bs5, [inline, guard]}]).

rename({attribute, L, module, _}, N) -> {attribute, L, module, N};
rename(X, _) -> X.

strip(Forms, Ops) ->
    F0 = case lists:member(inline, Ops) of
             %% what Gleam's codegen puts in its header: -compile(inline).
             true -> [H | T] = Forms, [H, {attribute, 0, compile, [inline]} | T];
             false -> Forms
         end,
    F1 = case lists:member(spec, Ops) of
             true -> [X || X <- F0, not is_spec(X)];
             false -> F0
         end,
    case lists:member(guard, Ops) of
        true -> [unguard(X) || X <- F1];
        false -> F1
    end.

is_spec({attribute, _, spec, _}) -> true;
is_spec(_) -> false.

%% case E of V when is_integer(V) -> V end   ==>   E
unguard({'case', _, E, [{clause, _, [{var, _, V}], [[{call, _, {remote, _, {atom, _, erlang}, {atom, _, is_integer}}, [{var, _, V}]}]], [{var, _, V}]}]}) ->
    unguard(E);
unguard(T) when is_tuple(T) -> list_to_tuple([unguard(X) || X <- tuple_to_list(T)]);
unguard(L) when is_list(L) -> [unguard(X) || X <- L];
unguard(X) -> X.
