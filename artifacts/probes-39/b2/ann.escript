#!/usr/bin/env escript
-mode(compile).
%% usage: ann.escript File.S [Op]   -> for each function, the type shown on the first operand of each gc_bif Op (default '+')
main([File | Rest]) ->
    Op = case Rest of [] -> '+'; [O] -> list_to_atom(O) end,
    {ok, Terms} = file:consult(File),
    Groups = group(Terms, undefined, []),
    [io:format("~-16s ~p~n", [atom_to_list(N) ++ "/" ++ integer_to_list(A),
                              [first_arg(Args) || {gc_bif, O, _, _, Args, _} <- Is, O =:= Op]])
     || {{N, A}, Is} <- Groups, N =/= module_info].
group([], Cur, Acc) -> lists:reverse(done(Cur, Acc));
group([{function, N, A, _} | T], Cur, Acc) -> group(T, {{N, A}, []}, done(Cur, Acc));
group([I | T], {K, Is}, Acc) -> group(T, {K, [I | Is]}, Acc);
group([_ | T], undefined, Acc) -> group(T, undefined, Acc).
done(undefined, Acc) -> Acc;
done({K, Is}, Acc) -> [{K, lists:reverse(Is)} | Acc].
first_arg([{tr, _, T} | _]) -> T;
first_arg([R | _]) -> {untyped, R}.
