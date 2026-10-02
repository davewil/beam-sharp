#!/usr/bin/env escript
%% Probe C: does the accepted refinement mean what it says; and what else the fold changes.
main([Ebin, Label]) ->
    true = code:add_patha(Ebin),
    Run = fun(Src) ->
        {ok, T, _} = bs_lexer:string(Src),
        case catch bs_parser:parse(T) of
          {ok, D} ->
            try bs_check:check(bs_lower:valves(D)) of
                {ok, _, _} -> accepted; {ok, _} -> accepted;
                {error, Ds} -> {diag, [case element(4,X) of Tg when is_tuple(Tg) -> element(1,Tg); Tg -> Tg end || X <- Ds]}
            catch error:{Tag, _} -> {refused, Tag} end;
          Other -> {parse, element(1, Other)}
        end end,
    Delta = "module D\ntype Delta = int where value >= -100 and value <= 100\npublic atom Take(Delta d)\nTake(d) -> :ok\n",
    Call = fun(Arg) -> io:format("~-8s Take(~-6s) over Delta   ~p~n", [Label, Arg,
        Run(Delta ++ "public atom Go()\nGo() -> Take(" ++ Arg ++ ")\n")]) end,
    [Call(A) || A <- ["-100", "-101", "100", "101", "0", "-1"]],
    %% the surface can now accept what the compiler prints as a residual
    Res = "module R\ntype Delta = int where value >= -10 and value <= 10\ntype NonZero = int where value <= -1 or value >= 1\n"
          "public atom Sign(Delta d)\nSign(<= -1) -> :neg\nSign(>= 1) -> :pos\n",
    io:format("~-8s residual-as-type NonZero + clauses missing 0  ~p~n", [Label, Run(Res)]),
    Sp = "module S\ntype Sp = int where value >= -10 and value <= -1 or value >= 1 and value <= 10\npublic atom Take(Sp s)\nTake(s) -> :ok\npublic atom Go()\nGo() -> Take(0)\n",
    io:format("~-8s -10..-1|1..10 spelled; Take(0) ~p~n", [Label, Run(Sp)]),
    NZ = "module N\ntype NonZero = int where value <= -1 or value >= 1\npublic int Div(int a, NonZero b)\nDiv(a, b) -> a / b\npublic int Go(int a)\nGo(a) -> Div(a, 0)\n",
    io:format("~-8s NonZero spelled with -1; Div(a, 0) ~p~n", [Label, Run(NZ)]),
    %% what types the literal ARGUMENT -1? (an unrefined-negative domain: value <= 5)
    Up = "module U\ntype Up = int where value <= 5\npublic atom Take(Up u)\nTake(u) -> :ok\npublic atom Go()\nGo() -> Take(-1)\n",
    io:format("~-8s Take(-1) over (value <= 5)   ~p~n", [Label, Run(Up)]),
    Ret = "module Rt\ntype Up = int where value <= 5\npublic Up Neg()\nNeg() -> -1\n",
    io:format("~-8s return -1 as (value <= 5)    ~p~n", [Label, Run(Ret)]),
    %% spill-over of the grammar fold into to_match/to_param (bs_parser.yrl:882,930) and the divisor check
    io:format("~-8s bare match  -1 = a            ~p~n", [Label, Run("module B\npublic int F(int a)\nF(a) ->\n    -1 = a\n    a\n")]),
    io:format("~-8s divisor a / -0                ~p~n", [Label, Run("module Dv\npublic int F(int a)\nF(a) -> a / -0\n")]),
    io:format("~-8s divisor a / 0                 ~p~n", [Label, Run("module Dz\npublic int F(int a)\nF(a) -> a / 0\n")]).
