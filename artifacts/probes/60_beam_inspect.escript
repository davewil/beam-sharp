#!/usr/bin/env escript
%% usage: 60_beam_inspect.escript disasm GuardBeam | call HeadDir GuardDir
main(["disasm", F]) ->
    {beam_file,_,Ex,_,_,Code} = beam_disasm:file(F),
    io:format("exports/1: ~p~n", [[N || {N,1,_} <- Ex]]),
    [begin
         Labels = [L || {label,L} <- Body],
         Tests  = [T || {test,T,_,_} <- Body],
         FI = length([x || {func_info,_,_,_} <- Body]),
         io:format("~s/~p: labels=~p func_info=~p type_tests=~p~n", [N,A,Labels,FI,Tests])
     end || {function,N,A,_,Body} <- Code, lists:member(N, ['Pub','Priv','Twice'])];
main(["cmp", A, B]) ->
    %% compares the chunks that carry behaviour; ignores CInf/Dbgi/Line (paths, options)
    Get = fun(F) -> {ok,{_,Cs}} = beam_lib:chunks(F, ["Code","AtU8","ExpT","LocT","ImpT","StrT","LitT","FunT"], [allow_missing_chunks]), Cs end,
    io:format("~s: behaviour chunks ~s (sizes ~p vs ~p)~n",
              [filename:basename(A), case Get(A) =:= Get(B) of true -> "IDENTICAL"; false -> "DIFFERENT" end,
               filelib:file_size(A), filelib:file_size(B)]);
main(["call", Head, G]) ->
    code:add_patha(Head), code:add_patha(G),
    io:format("outsider: 'Shop.Orders.Internal':'RecomputeTotal'([5,6],0) = ~p~n",
              [apply('Shop.Orders.Internal','RecomputeTotal',[[5,6],0])]),
    io:format("outsider: 'Shop.Orders.Internal' exports RecomputeTotal/2: ~p~n",
              [lists:member({'RecomputeTotal',2}, 'Shop.Orders.Internal':module_info(exports))]),
    io:format("CONTROL private: 'Guard':'Priv'(2) -> ~p~n", [element(1, catch apply('Guard','Priv',[2]))]),
    io:format("CONTROL guard on public: 'Guard':'Pub'(foo) -> ~p~n", [element(1, catch apply('Guard','Pub',[foo]))]).
