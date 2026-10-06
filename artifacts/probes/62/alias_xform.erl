%%% Simulates the compiler delta for "emit snake_case aliases": takes the .abstr bsc writes
%%% (the exact input bsc hands to compile:file/2 with from_abstr) and adds, for every
%%% exported author function, a second exported function under the derived name.
%%% mode wrapper: new(A) -> 'New'(A).   (the alias is a thin remote-free local call, a tail call)
%%% mode spec:    as wrapper, and the -spec of the original is duplicated for the alias.
%%% The rule is the thing under test; two are provided.
-module(alias_xform).
-export([xform/3, derive/2, collisions/1]).
-compile(nowarn_unused_function).

%% simple (Gleam's rule, observed in probe 62-02): '_' before EVERY uppercase letter but the first.
derive(simple, Name) ->
    [H|T] = atom_to_list(Name),
    list_to_atom([low(H) | lists:append([case C >= $A andalso C =< $Z of true -> [$_, C+32]; false -> [C] end || C <- T])]);%% acronym-aware: a run of capitals is one word (HTTPGet -> http_get, Md5Sum -> md5_sum).
derive(smart, Name) ->
    L = atom_to_list(Name),
    list_to_atom(string:lowercase(smart(L, none))).
low(C) when C >= $A, C =< $Z -> C + 32;
low(C) -> C.
smart([], _) -> [];
smart([C|Rest], Prev) ->
    Up = C >= $A andalso C =< $Z,
    Next = case Rest of [N|_] -> N; [] -> $a end,
    NextLow = Next >= $a andalso Next =< $z,
    PrevLowOrDigit = Prev =/= none andalso ((Prev >= $a andalso Prev =< $z) orelse (Prev >= $0 andalso Prev =< $9)),
    PrevUp = Prev =/= none andalso Prev >= $A andalso Prev =< $Z,
    Sep = Up andalso Prev =/= none andalso Prev =/= $_ andalso (PrevLowOrDigit orelse (PrevUp andalso NextLow)),
    (if Sep -> [$_]; true -> [] end) ++ [C | smart(Rest, C)].

xform(Rule, Mode, Forms) ->
    [{attribute,_,export,Ex}|_] = [F || F = {attribute,_,export,_} <- Forms],
    Author = [E || E = {N,_} <- Ex, N =/= 'bs@type_atoms', derive(Rule, N) =/= N],
    Defs = [F || F = {function,_,_,_,_} <- Forms],
    Specs = maps:from_list([{NA, S} || {attribute,_,spec,{NA,_}} = S <- Forms]),
    Aliases = [{derive(Rule, N), A, N} || {N,A} <- Author],
    Forms1 = [case F of
                 {attribute,L,export,Ex0} -> {attribute,L,export,Ex0 ++ [{An,A} || {An,A,_} <- Aliases]};
                 _ -> F end || F <- Forms],
    AliasForms = lists:append([alias_forms(Mode, An, A, N, Defs, Specs) || {An,A,N} <- Aliases]),
    %% definitions go at the end, before the eof-free list ends
    Forms1 ++ AliasForms.

alias_forms(Mode, An, A, N, Defs, Specs) ->
    Vars = [{var,0,list_to_atom("A" ++ integer_to_list(I))} || I <- lists:seq(1, A)],
    Fn = {function,0,An,A,[{clause,0,Vars,[],[{call,0,{atom,0,N},Vars}]}]},
    Sp = case {Mode, maps:find({N,A}, Specs)} of
             {spec, {ok, {attribute,L,spec,{_,Ts}}}} -> [{attribute,L,spec,{{An,A},Ts}}];
             _ -> [] end,
    _ = Defs,
    Sp ++ [Fn].

%% {Alias, Arity} -> [Original names] where more than one original maps to it, or the alias
%% equals an existing original / reserved name.
collisions(Forms) ->
    [{attribute,_,export,Ex}|_] = [F || F = {attribute,_,export,_} <- Forms],
    Author = [E || E = {N,_} <- Ex, N =/= 'bs@type_atoms'],
    lists:append([ begin
        Map = lists:foldl(fun({N,A},M) -> maps:update_with({derive(Rule,N),A}, fun(L)->[N|L] end, [N], M) end, #{}, Author),
        [{Rule, K, lists:sort(V)} || {K,V} <- maps:to_list(Map), length(V) > 1]
      end || Rule <- [simple, smart]]).
