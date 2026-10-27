-module(cost).
-export([main/0]).
time(Fun, N) ->
  Fun(), {T, _} = timer:tc(fun() -> [Fun() || _ <- lists:seq(1, N)] end), T / N.
main() ->
  Src = fun(P) -> "module M\ntype T = int where " ++ P ++ "\npublic int F(T d)\nF(d) -> d\n" end,
  Pos = Src("value >= 5 and value <= 100"),
  PosD = drv:parse(Pos),
  Neg = Src("value >= -5 and value <= 100"),
  Ar  = Src("value >= 2 + 3 and value <= 10 * 10"),
  N = 3000,
  Run = fun(S) -> D = drv:parse(S), fun() -> bs_check:check(D) end end,
  Parse = fun(S) -> fun() -> drv:parse(S) end end,
  io:format("words: e_int=~p e_neg(e_int)=~p~n", [erts_debug:flat_size({e_int, {2,1}, 5}), erts_debug:flat_size({e_neg, {2,1}, {e_int, {2,1}, 5}})]),
  io:format("check/1 us/call  `>=5 and <=100`:        ~.1f~n", [time(Run(Pos), N)]),
  io:format("parse+lower us/call `>=5 and <=100`:     ~.1f~n", [time(Parse(Pos), N)]),
  io:format("parse+lower us/call `>=-5 and <=100`:    ~.1f~n", [time(Parse(Neg), N)]),
  catch io:format("check/1 us/call  `>=-5 and <=100`:        ~.1f~n", [time(Run(Neg), N)]),
  catch io:format("check/1 us/call  `>=2+3 and <=10*10`:     ~.1f~n", [time(Run(Ar), N)]),
  _ = PosD, ok.
