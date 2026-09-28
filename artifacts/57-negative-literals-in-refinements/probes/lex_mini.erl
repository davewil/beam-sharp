%% Minimal tokenizer for the probes ONLY. It produces the token shapes that
%% compiler/src/bs_lexer.xrl documents ({integer,Loc,N}, {lident,Loc,A},
%% {uident,Loc,A}, {Kw,Loc}), with Loc = {Line,Col}. It exists because the real
%% lexer needs OTP 28's leex TokenLoc and cannot be built here. It is NOT bsc's lexer.
-module(lex_mini).
-export([tokens/1]).
-define(KW, ["type","where","and","or","module","when","switch","true","false"]).
tokens(S) -> go(S, 1, 1, []).
go([], _L, _C, Acc) -> lists:reverse(Acc);
go([$\n|T], L, _C, Acc) -> go(T, L+1, 1, Acc);
go([$\s|T], L, C, Acc) -> go(T, L, C+1, Acc);
go([$:,X|_]=S, L, C, Acc) when X >= $a, X =< $z ->
    {W, R} = lists:splitwith(fun(Y) -> (Y>=$a andalso Y=<$z) orelse (Y>=$A andalso Y=<$Z)
                                       orelse (Y>=$0 andalso Y=<$9) orelse Y=:=$_ end, tl(S)),
    go(R, L, C+1+length(W), [{atom_lit,{L,C},list_to_atom(W)}|Acc]);
go([D|_]=S, L, C, Acc) when D >= $0, D =< $9 ->
    case re:run(S, "^[0-9]+\\.[0-9]+", [{capture,first,list}]) of
        {match,[F]} -> go(lists:nthtail(length(F),S), L, C+length(F), [{float,{L,C},list_to_float(F)}|Acc]);
        nomatch -> int(S, L, C, Acc) end;
go([X|_]=S, L, C, Acc) when X >= $a, X =< $z; X >= $A, X =< $Z; X =:= $_ ->
    {W, R} = lists:splitwith(fun(Y) -> (Y>=$a andalso Y=<$z) orelse (Y>=$A andalso Y=<$Z)
                                       orelse (Y>=$0 andalso Y=<$9) orelse Y=:=$_ end, S),
    Tok = case {lists:member(W, ?KW), W} of
        {true,_} -> {list_to_atom(W),{L,C}};
        {_,"_"} -> {'_',{L,C}};
        {_,[F|_]} when F >= $A, F =< $Z -> {uident,{L,C},list_to_atom(W)};
        _ -> {lident,{L,C},list_to_atom(W)}
    end,
    go(R, L, C+length(W), [Tok|Acc]);
go(S, L, C, Acc) ->
    Ops = ["->","=>",">=","<=","==","!=",">","<","+","-","*","/","%","(",")","{","}",",","=",":","|",";","."],
    [Op|_] = [O || O <- Ops, lists:prefix(O, S)],
    go(lists:nthtail(length(Op), S), L, C+length(Op), [{list_to_atom(Op),{L,C}}|Acc]).
int(S, L, C, Acc) ->
    {Ds, R} = lists:splitwith(fun(X) -> X >= $0 andalso X =< $9 end, S),
    go(R, L, C+length(Ds), [{integer,{L,C},list_to_integer(Ds)}|Acc]).
