#!/usr/bin/env escript
%% 62 / probe 4 — byte cost of "emit a snake_case alias beside every exported function" (candidate 2),
%% measured on the REAL emitted forms (.abstr) of every example module bsc compiles.
%% Method: for each exported {Name,Arity}, add `snake(A1..An) -> 'Name'(A1..An).`, export it, copy the -spec.
%% Both versions go through the same compile:forms call, so only the aliases differ. Snake rule = Gleam's
%% to_snake_case (strings.rs:70). Names whose derivation already exists as an export are skipped and counted.
main([Dir]) ->
    Files = filelib:wildcard(filename:join(Dir, "*.abstr")),
    R = [one(F) || F <- Files],
    S = fun(K) -> lists:sum([maps:get(K, X) || X <- R]) end,
    io:format("modules=~p exports=~p aliases-added=~p skipped(name-clash)=~p~n", [length(R), S(exports), S(added), S(skipped)]),
    io:format("beam bytes: before=~p after=~p delta=~p (~.1f B per alias, ~.1f% growth)~n",
              [S(before), S(aft), S(aft) - S(before), (S(aft) - S(before)) / max(1, S(added)), 100 * (S(aft) - S(before)) / S(before)]).

one(F) ->
    {ok, Forms} = file:consult(F),
    Exports = lists:append([Ns || {attribute,_,export,Ns} <- Forms]),
    Real = [{N,A} || {N,A} <- Exports, N =/= 'bs@type_atoms'],
    Taken = sets:from_list([N || {N,_} <- Exports]),
    {Aliases, Skipped} = lists:foldl(fun({N,A}, {Acc, Sk}) ->
        S = list_to_atom(snake(atom_to_list(N))),
        case sets:is_element(S, Taken) orelse lists:member({S,A}, [{X,Y} || {X,Y,_} <- Acc]) of
            true -> io:format("  skipped ~s: ~p/~p -> ~p already exported\n", [filename:basename(F), N, A, S]), {Acc, Sk + 1};
            false -> {[{S, A, N} | Acc], Sk}
        end end, {[], 0}, Real),
    Specs = [{{Name,Ar}, Ty} || {attribute,_,spec,{{Name,Ar},Ty}} <- Forms],
    Extra = lists:append([[{attribute,0,export,[{S,A}]},
                           {function,0,S,A,[{clause,0,[{var,0,list_to_atom("V"++integer_to_list(I))} || I <- lists:seq(1,A)],[],
                                              [{call,0,{atom,0,N},[{var,0,list_to_atom("V"++integer_to_list(I))} || I <- lists:seq(1,A)]}]}]}]
                          ++ [{attribute,0,spec,{{S,A},Ty}} || {{SN,SA}, Ty} <- Specs, SN =:= N, SA =:= A]
                          || {S,A,N} <- Aliases]),
    Before = size_of(Forms), After = size_of(insert(Forms, Extra)),
    #{exports => length(Real), added => length(Aliases), skipped => Skipped, before => Before, aft => After}.

%% attributes must precede functions: put the extra export/spec attributes before the first function, functions at the end
insert(Forms, Extra) ->
    {Attrs, Fns} = lists:partition(fun(X) -> element(1, X) =:= attribute end, Extra),
    {Pre, Rest} = lists:splitwith(fun(X) -> element(1, X) =/= function end, Forms),
    Pre ++ Attrs ++ Rest ++ Fns.
size_of(Forms) ->
    case compile:forms(Forms, [binary, return_errors, debug_info]) of
        {ok, _, B} -> byte_size(B); {ok, _, B, _} -> byte_size(B);
        Err -> io:format("compile error ~P~n", [Err, 12]), 0 end.

snake(S) -> lists:reverse(snake(S, true, [])).
snake([], _, Acc) -> Acc;
snake([$_|T], _, Acc) -> snake(T, true, Acc);
snake([C|T], WB, Acc) ->
    Up = C >= $A andalso C =< $Z,
    WB1 = WB orelse Up,
    Acc1 = case WB1 andalso Acc =/= [] of true -> [$_|Acc]; false -> Acc end,
    snake(T, false, [if Up -> C + 32; true -> C end | Acc1]).
