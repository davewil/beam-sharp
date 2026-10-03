-module(corp).
-export([main/1]).
%% For every .abstr in Dir: compile as emitted vs with -compile(inline) added; report size and time.
main([Dir]) ->
    Fs = lists:sort(filelib:wildcard(Dir ++ "/*/*.abstr")),
    io:format("~-26s ~7s ~7s ~6s ~9s ~9s~n", ["module","B plain","B inl","d%","ms plain","ms inl"]),
    {ok,W}=file:consult(hd(Fs)), [compile:noenv_forms(W,[binary]) || _ <- lists:seq(1,30)], %% warm the compiler
    Rs = [one(F) || F <- Fs, filename:basename(F) =/= "bs@type_atoms.abstr"],
    {P, I, TP, TI} = lists:foldl(fun({_,A,B,C,D},{a,b,c,d}) -> {A,B,C,D}; ({_,A,B,C,D},{P0,I0,TP0,TI0}) -> {P0+A,I0+B,TP0+C,TI0+D} end, {0,0,0,0}, [{x,0,0,0,0}|Rs]),
    io:format("~-26s ~7w ~7w ~5.1f% ~9.1f ~9.1f   (~p modules)~n", [total, P, I, (I-P)*100/P, TP/1000, TI/1000, length(Rs)]),
    halt().
one(F) ->
    {ok, Forms} = file:consult(F),
    M = filename:basename(F, ".abstr"),
    {A, [Mod|B]} = lists:splitwith(fun(X) -> not (element(1,X)=:=attribute andalso element(3,X)=:=module) end, Forms),
    Inl = A ++ [Mod, {attribute,0,compile,inline}|B],
    {TP, {ok,_,BP}} = timer:tc(fun() -> t(Forms, 5) end),
    {TI, {ok,_,BI}} = timer:tc(fun() -> t(Inl, 5) end),
    io:format("~-26s ~7w ~7w ~5.1f% ~9.2f ~9.2f~n", [M, byte_size(BP), byte_size(BI), (byte_size(BI)-byte_size(BP))*100/byte_size(BP), TP/5000, TI/5000]),
    {M, byte_size(BP), byte_size(BI), TP, TI}.
t(F, 1) -> compile:noenv_forms(F, [binary]);
t(F, N) -> compile:noenv_forms(F, [binary]), t(F, N-1).
