%%% 59e — CLAIM (ticket 59, 18 §1 cost section): "interior [non-exported] functions already pay
%%% nothing — which is the shape C wanted anyway". Is that how the platform's own code treats
%%% private functions? Census of OTP stdlib+kernel (Erlang) and the Elixir stdlib: for EXPORTED
%%% and for LOCAL-ONLY functions, the share of parameter positions that are "defended" (every
%%% clause matches a non-variable pattern there, or mentions the variable in a guard), the
%%% criterion of wayfinder/prototypes/18b_otp_guard_census.erl, run on both populations.
%%% CONTROL: the exported row for stdlib+kernel must reproduce 18b's recorded 83.3% bare
%%% (it prints PASS/FAIL against the recorded 7606 positions).
%%%   erlc -o $WORK 59e_platform_census.erl && erl -noshell -pa $WORK -eval '...' (see 59e_platform_census.sh)
-module('59e_platform_census').
-export([main/0]).

main() ->
  Lib = code:lib_dir(),
  EL = filename:dirname(code:which(elixir)),
  Sets = [{"OTP stdlib+kernel", [filename:join([code:lib_dir(A),"ebin","*.beam"]) || A <- [stdlib,kernel]]},
          {"Elixir stdlib (elixir app)", [filename:join(EL,"*.beam")]}],
  _ = Lib,
  [report(Name, lists:append([filelib:wildcard(W) || W <- Ws])) || {Name, Ws} <- Sets],
  ok.

report(Name, Files) ->
  Rows = lists:filtermap(fun scan/1, Files),
  {E, L} = lists:foldl(fun({A,B},{X,Y}) -> {add(X,A), add(Y,B)} end, {{0,0,0,0},{0,0,0,0}}, Rows),
  io:format("~n~s  (~p modules with debug info)~n",[Name,length(Rows)]),
  show("exported", E), show("local-only", L),
  case Name of
    "OTP stdlib+kernel" ->
      {_,_,P,_} = E,
      io:format("  CONTROL vs 18b recorded (7606 exported positions): ~s (got ~p)~n",
                [case P of 7606 -> "PASS"; _ -> "FAIL" end, P]);
    _ -> ok
  end.
add({A,B,C,D},{A1,B1,C1,D1}) -> {A+A1,B+B1,C+C1,D+D1}.
show(Lbl,{F,FD,P,DP}) ->
  io:format("  ~-10s functions ~5p  all-params-defended ~4p (~5.1f%)  positions ~5p  defended ~5p (~5.1f%)  bare ~5.1f%~n",
            [Lbl,F,FD,pct(FD,F),P,DP,pct(DP,P),100-pct(DP,P)]).
pct(_,0) -> 0.0; pct(A,B) -> 100.0*A/B.

scan(File) ->
  case beam_lib:chunks(File,[debug_info,exports]) of
    {ok,{M,[{debug_info,{debug_info_v1,Backend,Data}},{exports,Ex}]}} ->
      case catch Backend:debug_info(erlang_v1,M,Data,[]) of
        {ok,Forms} ->
          Fs = [{N,A,Cl} || {function,_,N,A,Cl} <- Forms, user_fun(N)],
          {Exp,Loc} = lists:partition(fun({N,A,_}) -> lists:member({N,A},Ex) end, Fs),
          {true,{tally(Exp),tally(Loc)}};
        _ -> false
      end;
    _ -> false
  end.
user_fun(N) -> S = atom_to_list(N), hd(S) =/= $- andalso not lists:prefix("MACRO-",S) andalso S =/= "module_info" andalso S =/= "__info__".
tally(Funs) ->
  lists:foldl(fun({_N,A,Cl},{F,FD,P,DP}) ->
    D = [pos_defended(I,Cl) || I <- lists:seq(1,A)], ND = length([x || true <- D]),
    {F+1, FD+case A>0 andalso ND=:=A of true->1; false->0 end, P+A, DP+ND} end, {0,0,0,0}, Funs).
pos_defended(I,Cl) -> lists:all(fun({clause,_,Ps,Gs,_}) -> Pat = lists:nth(I,Ps), pat(Pat) orelse gm(Pat,Gs) end, Cl).
pat({var,_,_}) -> false; pat(_) -> true.
gm({var,_,'_'},_) -> false;
gm({var,_,N},Gs) -> lists:any(fun(G) -> m(N,G) end, Gs);
gm(_,_) -> false.
m(N,T) when is_tuple(T) -> case T of {var,_,N} -> true; _ -> lists:any(fun(E)->m(N,E) end, tuple_to_list(T)) end;
m(N,L) when is_list(L) -> lists:any(fun(E)->m(N,E) end, L);
m(_,_) -> false.
