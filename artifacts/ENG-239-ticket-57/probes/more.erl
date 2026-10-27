%% Observations beyond accept/refuse: (1) the interval a refinement ACTUALLY denotes, read from the residual the
%% checker prints when a clause is deleted; (2) what a body literal -1 is typed as; (3) behaviour that must NOT change.
-module(more).
-export([main/0]).
resid(Pred) ->  %% clauses cover everything except `>= 1`; the residual names the remaining type
  Src = "module M\ntype T = int where " ++ Pred ++ "\npublic atom S(T d)\nS(<= 0) -> :low\n",
  case drv:run(Src) of
    {refused, [{error,_,_,{inexhaustive, Res, _}}]} -> {residual, ints(Res)};
    {refused, [{error,_,_,{inexhaustive, Res, _}} | _]} -> {residual, ints(Res)};
    {refused, Es} -> {refused, [element(1, element(4, E)) || E <- Es]};
    Other -> guards:brief(Other)
  end.
ints(#{tuples := [[#{ints := I}]]}) -> I;
ints(Other) -> {unexpected_shape, Other}.
main() ->
  io:format("-- residual interval of the refinement (clauses cover <= 0; residual should be the rest of T) --~n"),
  [io:format("~-36s ~p~n", [P, resid(P)]) ||
     P <- ["value >= -5 and value <= 5", "value >= 0 and value <= 5", "value >= -2 * 3 and value <= 2 + 3",
           "value != -1", "value >= -3 and value <= -(-5)"]],
  io:format("-- a body literal: NonPos F() -> -1 and Neg G() -> -5 (baseline types `-N` as int?) --~n"),
  L1 = "module M\ntype NonPos = int where value <= 0\npublic NonPos F()\nF() -> -1\n",
  L2 = "module M\ntype Pos = int where value >= 1\npublic Pos F()\nF() -> 1\n",
  L3 = "module M\ntype NonPos = int where value <= 0\npublic NonPos F()\nF() -> 0 - 1\n",
  [io:format("~-36s ~p~n", [N, guards:brief(drv:run(S))]) || {N, S} <- [{"NonPos F() -> -1", L1}, {"Pos F() -> 1 (control)", L2}, {"NonPos F() -> 0 - 1", L3}]],
  io:format("-- a zero divisor spelled -0 (F26 refuses a provably-zero divisor) --~n"),
  Z = "module M\npublic int F(int n)\nF(n) -> n / -0\n",
  io:format("~-36s ~p~n", ["F(n) -> n / -0", guards:brief(drv:run(Z))]),
  io:format("~-36s ~p~n", ["F(n) -> n / 0 (control)", guards:brief(drv:run("module M\npublic int F(int n)\nF(n) -> n / 0\n"))]),
  io:format("-- must not change: a float comparand, a variable comparand, a zero divisor --~n"),
  [io:format("~-36s ~p~n", [P, guards:brief(drv:run("module M\ntype T = int where " ++ P ++ "\npublic int F(T d)\nF(d) -> d\n"))]) ||
     P <- ["value >= -5.0", "value >= value", "value >= 1 / 0", "value >= 1 % 0", "value >= (-5) + value"]],
  ok.
