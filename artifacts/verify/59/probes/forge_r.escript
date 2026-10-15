#!/usr/bin/env escript
main([Dir]) ->
    true = code:add_patha(Dir),
    I = #{'Kind' => 'R.Invoice', 'Id' => 1, 'Total' => 5},
    O = #{'Kind' => 'R.Order', 'Id' => 1, 'Total' => 5},
    W = fun(In) -> #{'Kind' => 'R.Wrapper', 'Id' => 1, 'Inner' => In} end,
    Cs = [{'ViaPat', W(O)}, {'ViaPat', W(I)}, {'ViaPat2', W(I)}, {'ViaSwitch', W(O)}, {'ViaSwitch', W(I)},
          {'ViaLet', W(I)}, {'ViaChain', W(I)}],
    [begin R = try {ok, apply('R', F, [A])} catch C:E -> {C, E} end,
           io:format("~-10s inner=~-8s -> ~p~n", [F, case maps:get('Inner', A) of #{'Kind' := 'R.Invoice'} -> invoice; _ -> order end, R]) end || {F, A} <- Cs].
