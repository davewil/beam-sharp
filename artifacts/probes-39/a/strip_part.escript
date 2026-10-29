#!/usr/bin/env escript
-mode(compile).
%% usage: strip_part.escript In.S Out.S NewModuleName tr|vi
%%   tr: strip only {tr,Reg,Type} operands (keep var_info entry types);  vi: strip only var_info (keep {tr,..})
main([In, Out, NewMod, Mode]) ->
    put(mode, list_to_atom(Mode)),
    {ok, Terms} = file:consult(In),
    Old = hd([M || {module, M} <- Terms]),
    T1 = [strip(rn(T, Old, list_to_atom(NewMod))) || T <- Terms],
    {ok, Fd} = file:open(Out, [write]),
    [io:format(Fd, "~p.~n", [T]) || T <- T1],
    file:close(Fd).
rn({atom, Old}, Old, New) -> {atom, New};
rn({module, Old}, Old, New) -> {module, New};
rn(T, Old, New) when is_tuple(T) -> list_to_tuple([rn(E, Old, New) || E <- tuple_to_list(T)]);
rn(L, Old, New) when is_list(L) -> [rn(E, Old, New) || E <- L];
rn(T, _, _) -> T.
strip({tr, Reg, _} = T) -> case get(mode) of tr -> Reg; vi -> T end;
strip(T) when is_tuple(T) -> list_to_tuple([strip(E) || E <- tuple_to_list(T)]);
strip(L) when is_list(L) -> [strip(E) || E <- L, not drop(E)];
strip(T) -> T.
drop({'%', {var_info, _, _}}) -> get(mode) =:= vi;
drop(_) -> false.
