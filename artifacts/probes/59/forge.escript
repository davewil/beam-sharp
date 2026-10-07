#!/usr/bin/env escript
%% usage: forge.escript FILE.abstr emitted|stripped|widened
%% widened = as emitted, PLUS is_integer/1 on every private function parameter whose -spec type is integer()
%% Compiles the abstr (optionally with the private TAG test removed), loads it, and calls the
%% exported functions with forged values.  Prints WHICH function raised (stack top) or the value.
main([F, Mode]) ->
    {ok, Forms0} = file:consult(F),
    Exports = lists:append([L || {attribute,_,export,L} <- Forms0]),
    Forms = case Mode of "emitted" -> Forms0; "stripped" -> [strip(X, Exports) || X <- Forms0];
                 "widened" -> [widen(X, Exports, Forms0) || X <- Forms0] end,
    {ok, M, Bin, _} = compile:forms(Forms, [debug_info, binary, return]),
    {module, M} = code:load_binary(M, "Guard.beam", Bin),
    Good  = #{'Kind' => 'Guard.Order', 'Id' => 1, 'Total' => 7},
    Inv   = #{'Kind' => 'Guard.Invoice', 'Id' => 1, 'Total' => 99},   % forged: a different record claiming Total
    NoK   = #{'Id' => 1, 'Total' => 99},                                 % no tag at all
    Cart  = fun(P, C) -> #{'Kind' => 'Guard.Cart', 'Primary' => P, 'Count' => C} end,
    io:format("mode=~s~n", [Mode]),
    t("Outer(valid Order)",                 fun() -> M:'Outer'(Good) end),
    t("Outer(forged Invoice)       [whole-record path]", fun() -> M:'Outer'(Inv) end),
    t("Outer(no Kind)              [whole-record path]", fun() -> M:'Outer'(NoK) end),
    t("Nested(Cart{Primary=valid})",        fun() -> M:'Nested'(Cart(Good, 1)) end),
    t("Nested(Cart{Primary=forged Invoice}) [one projection deep]", fun() -> M:'Nested'(Cart(Inv, 1)) end),
    t("Nested(Cart{Primary=no Kind})        [one projection deep]", fun() -> M:'Nested'(Cart(NoK, 1)) end),
    t("Nested(Cart{Primary=42})             [not even a map]", fun() -> M:'Nested'(Cart(42, 1)) end),
    t("NestedInt(Cart{Count=3})",           fun() -> M:'NestedInt'(Cart(Good, 3)) end),
    t("NestedInt(Cart{Count=1.5})  [int below the top: NO private int test either way]", fun() -> M:'NestedInt'(Cart(Good, 1.5)) end),
    t("NestedInt(Cart{Count=foo})  [int below the top]", fun() -> M:'NestedInt'(Cart(Good, foo)) end),
    t("OuterInt(1.5)               [whole-int path: exported test fires]", fun() -> M:'OuterInt'(1.5) end),
    t("Totals([valid])",                    fun() -> M:'Totals'([Good]) end),
    t("Totals([valid, forged Invoice])  [list element, via fun Inner/1]", fun() -> M:'Totals'([Good, Inv]) end),
    t("ViaUnion(Cart{Primary=forged Invoice}) [private takes Order|Cart]", fun() -> M:'ViaUnion'(Cart(Inv, 1)) end),
    ok.

t(Label, Fun) ->
    R = try {value, Fun()} catch C:E:St -> {raised, C, E, top(St)} end,
    io:format("  ~-82s -> ~s~n", [Label, lists:flatten(io_lib:format("~0p",[R]))]).
top([{_,F,A,_}|_]) -> {F,A};
top(_) -> unknown.

strip({function,L,N,A,Cs}, Exports) ->
    case lists:member({N,A},Exports) of
        true -> {function,L,N,A,Cs};
        false -> {function,L,N,A,[{clause,CL,Ps,[G1||G<-Gs,G1<-[[T||T<-G,not is_tag(T)]],G1=/=[]],B}||{clause,CL,Ps,Gs,B}<-Cs]}
    end;
strip(X,_) -> X.
is_tag({op,_,'=:=',{call,_,{remote,_,{atom,_,erlang},{atom,_,map_get}},[{atom,_,'Kind'},_]},{atom,_,_}}) -> true;
is_tag(_) -> false.

widen({function,L,N,A,Cs}, Exports, All) ->
    case lists:member({N,A},Exports) of
        true -> {function,L,N,A,Cs};
        false ->
            Spec = [Ts || {attribute,_,spec,{{N1,A1},[{type,_,'fun',[{type,_,product,Ts},_]}]}} <- All, N1 =:= N, A1 =:= A],
            Ints = case Spec of [Ts0] -> [I || {I,{type,_,integer,[]}} <- lists:zip(lists:seq(1,length(Ts0)),Ts0)]; _ -> [] end,
            {function,L,N,A,[{clause,CL,Ps,widen_g(Gs,Ps,Ints),B}||{clause,CL,Ps,Gs,B}<-Cs]}
    end;
widen(X,_,_) -> X.
widen_g(Gs, Ps, Ints) ->
    Tests = [{call,0,{remote,0,{atom,0,erlang},{atom,0,is_integer}},[V]} || I <- Ints, {var,_,_}=V <- [lists:nth(I,Ps)]],
    case Gs of [] when Tests =/= [] -> [Tests]; [] -> []; _ -> [Tests ++ G || G <- Gs] end.
