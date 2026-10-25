#!/usr/bin/env escript
%% usage: asm_fn.escript LISTING.S FUNCTION ARITY [--notypes]
%% Prints one function's instructions with line info and label numbers normalised, so two modules'
%% listings can be compared with diff(1). --notypes also drops var_info and {tr,Reg,Type} -> Reg.
main([F, Fn, Ar | Rest]) ->
    NoTypes = lists:member("--notypes", Rest),
    {ok, Terms} = file:consult(F),
    Fs = case Terms of
             [{_, _, _, Funs, _}] -> Funs;                       % written by asm_of.escript
             _ -> flat(Terms)                                    % erlc -S writes a flat listing
         end,
    A = list_to_integer(Ar),
    [Code] = [C || {function, N, Ar0, _, C} <- Fs, atom_to_list(N) =:= string:lowercase(Fn) orelse atom_to_list(N) =:= Fn, Ar0 =:= A,
                   true],
    Norm = norm(Code, NoTypes),
    [io:format("~p~n", [I]) || I <- Norm].

norm(Code, NoTypes) ->
    Labels = lists:usort([L || {label, L} <- Code]),
    Map = maps:from_list(lists:zip(Labels, lists:seq(1, length(Labels)))),
    [I || I0 <- Code, I <- [fix(I0, Map, NoTypes)], I =/= drop].

fix({line, _}, _, _) -> drop;
fix({'%', _}, _, _) -> drop;
fix({label, L}, M, _) -> {label, maps:get(L, M)};
fix({func_info, _, _, _}, _, _) -> drop;
fix({f, L}, M, _) -> {f, maps:get(L, M, L)};
fix(T, M, NT) when is_tuple(T) -> list_to_tuple([fix(E, M, NT) || E <- tuple_to_list(T)]);
fix(L, M, NT) when is_list(L) -> [fix(E, M, NT) || E <- L];
fix(X, _, _) -> X.

%% {function,N,A,E} followed by that function's instructions, up to the next {function,...}.
flat([]) -> [];
flat([{function, N, A, E} | T]) ->
    {Body, Rest} = lists:splitwith(fun(X) -> not (is_tuple(X) andalso tuple_size(X) =:= 4 andalso element(1, X) =:= function) end, T),
    [{function, N, A, E, Body} | flat(Rest)];
flat([_ | T]) -> flat(T).
