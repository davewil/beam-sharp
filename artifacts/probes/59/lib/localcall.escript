#!/usr/bin/env escript
%% usage: localcall.escript File.beam Caller Callee
%% Prints: entry label of Callee, whether Callee's entry block carries is_integer, and the local-call target labels used by Caller.
main([F, Caller, Callee]) ->
    {ok,{_,[{abstract_code,{_,Forms}}]}} = beam_lib:chunks(F,[abstract_code]),
    {ok,_,{_,_,_,Fns,_}} = compile:noenv_forms(Forms,[to_asm,binary,no_inline]),
    Get = fun(N) -> hd([{E,Is} || {function,Nm,_,E,Is} <- Fns, atom_to_list(Nm) =:= N]) end,
    {CalleeEntry, CalleeIs} = Get(Callee),
    {_, CallerIs} = Get(Caller),
    Body = lists:dropwhile(fun(I) -> I =/= {label,CalleeEntry} end, CalleeIs),
    HasInt = lists:any(fun({test,is_integer,_,_}) -> true; (_) -> false end, Body),
    Targets = [L || {call,_,{f,L}} <- CallerIs],
    io:format("callee_entry_label=~w callee_has_is_integer=~w caller_local_call_targets=~w calls_callee_entry=~w~n",
              [CalleeEntry, HasInt, Targets, lists:member(CalleeEntry, Targets)]).
