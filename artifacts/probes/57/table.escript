#!/usr/bin/env escript
%% Probe B: the real bs_parser + bs_check (OTP-25 shim) over refinements and guards.
%% usage: table.escript EBIN LABEL
main([Ebin, Label]) ->
    true = code:add_patha(Ebin),
    Run = fun(Src) ->
        {ok, T, _} = bs_lexer:string(Src),
        {ok, D} = bs_parser:parse(T),
        try bs_check:check(bs_lower:valves(D)) of
            {ok, _, _}      -> accepted;
            {ok, _}         -> accepted;
            {error, Diags}  -> {diag, [case element(4,X) of Tg when is_tuple(Tg) -> element(1,Tg); Tg -> Tg end || X <- Diags]}
        catch error:{Tag, _} -> {refused, Tag}
        end
    end,
    R = fun(Where, Pred) ->
        Src = "module M\ntype T = int where " ++ Pred ++ "\npublic atom Take(T t)\nTake(t) -> :ok\n",
        io:format("~-8s refinement ~-34s ~p~n", [Label, Pred, Run(Src)]), Where end,
    [R(x,P) || P <- ["value >= -5", "value >= -5 and value <= 5", "value >= 1 or value <= -1",
                     "value <= 3 or value >= 10", "value != 0", "value != -1", "-5 <= value",
                     "value >= -(5)", "value >= - -5", "value >= 2 + 3", "value >= 0 - 5",
                     "value >= -5 * 2", "value >= 5 - 10", "value >= -(2 + 3)", "value >= 3 * 4"]],
    %% a guard goes through the same alternatives/1
    G = fun(Guard) ->
        Src = "module G\npublic atom Sign(int n)\nSign(n) when " ++ Guard ++ " -> :neg\nSign(n) -> :other\n",
        io:format("~-8s guard      ~-34s ~p~n", [Label, Guard, Run(Src)]) end,
    [G(P) || P <- ["n < 0", "n <= -1"]],
    %% coverage credit: does a guard over -1 let the compiler prove the next clause is the residual?
    Cov = fun(Lo, Hi) ->
        Src = "module C\npublic atom Sign(int n)\n"
              "Sign(n) when " ++ Lo ++ " -> :neg\nSign(n) when " ++ Hi ++ " -> :pos\n",
        io:format("~-8s exhaustive guards ~-22s ~p~n", [Label, Lo ++ " / " ++ Hi, Run(Src)]) end,
    Cov("n < 0", "n >= 0"),
    Cov("n <= -1", "n >= 0"),
    Cov("n < 0", "n > -1"),
    %% the residual doctrine: delete a clause over -10..10, a pattern spells the residual
    io:format("~-8s patterns   ~p~n", [Label, Run("module P\npublic atom S(int n)\nS(<= -1) -> :neg\nS(0) -> :zero\nS(>= 1) -> :pos\n")]).
