#!/usr/bin/env escript
%% usage: strip_types.escript In.S Out.S NewModuleName
%% Removes (1) every {tr,Reg,Type} operand -> Reg, (2) every {'%',{var_info,...}} pseudo-instruction.
%% Nothing else is touched. Also renames module (so variants can be loaded side by side).
main([In, Out, NewMod]) ->
    {ok, Terms} = file:consult(In),
    Old = hd([M || {module, M} <- Terms]),
    T1 = [strip(rename(T, Old, list_to_atom(NewMod))) || T <- Terms],
    {ok, Fd} = file:open(Out, [write]),
    [io:format(Fd, "~p.~n", [T]) || T <- T1],
    file:close(Fd).

rename({module, Old}, Old, New) -> {module, New};
rename({attributes, As}, Old, New) -> {attributes, As};
rename(T, Old, New) -> rn(T, Old, New).
rn({atom, Old}, Old, New) -> {atom, New};
rn(T, Old, New) when is_tuple(T) -> list_to_tuple([rn(E, Old, New) || E <- tuple_to_list(T)]);
rn(L, Old, New) when is_list(L) -> [rn(E, Old, New) || E <- L];
rn(T, _, _) -> T.

strip(T) when is_tuple(T) ->
    case T of
        {tr, Reg, _Type} -> Reg;
        _ -> list_to_tuple([strip(E) || E <- tuple_to_list(T)])
    end;
strip(L) when is_list(L) ->
    [strip(E) || E <- L, not is_var_info(E)];
strip(T) -> T.
is_var_info({'%', {var_info, _, _}}) -> true;
is_var_info(_) -> false.
