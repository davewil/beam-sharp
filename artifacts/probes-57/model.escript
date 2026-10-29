#!/usr/bin/env escript
%%! -pa var
%% MODEL, NOT bsc. alternatives/1 + comparison/1 + int_cmp/3 + flip/1 are transcribed from
%% compiler/src/bs_check.erl:5136-5174 (read 2026-10-29); the interval algebra below is a
%% 30-line stand-in for bs_types ranges (sorted disjoint {Lo,Hi}, neg_inf/pos_inf).
%% Reader variants (the "checker" side):
%%   cur : comparison reads only {e_int,_,K}                       (bs_check.erl:5154-5155 today)
%%   c1  : + {e_neg,_,{e_int}}            (one clause)
%%   c2  : + full literal fold of e_neg and e_op + - * / % over literals (recursive)
%%   c3  : bounded: e_neg chains and e_op + - * over two int literals, one level (no / %, no nesting of binary ops)
%% Parser variants (the "grammar" side): base_p | g1_p (narrow literal comparand) | g2_p (negate folds int literal) | g1c_p ('-' integer production)
-mode(compile).
main(_) ->
  Rows = [
   {"value >= -5",                     "ticket row 1"},
   {"value >= -5 and value <= 5",      "ticket row 2 = type Delta"},
   {"value >= 1 or value <= -1",       "ticket row 3"},
   {"value <= 3 or value >= 10",       "ticket row 4"},
   {"value != 0",                      "ticket row 5"},
   {"-5 <= value",                     "flipped"},
   {"value >= - -5",                   "double negation"},
   {"value >= 2 - 7",                  "type Off"},
   {"value >= 0 - 5",                  "0 - 5"},
   {"value >= -5 * 2",                 "neg of product"},
   {"value >= 10 / 3",                 "int division"},
   {"value >= -x",                     "non-constant"},
   {"value >= -( 5 )",                 "parenthesised"}],
  Readers = [cur,c1,c2,c3],
  Parsers = [base_p,g1_p,g2_p,g1c_p],
  io:format("~-28s", ["refinement"]),
  [io:format(" ~-11s", [lists:flatten(io_lib:format("~s/~s",[short(P),R]))]) || P <- Parsers, R <- Readers], io:format("~n"),
  [begin
     io:format("~-28s", [S]),
     [begin
        Toks = tok("module M type T = int where "++S) ++ [{'$end',1}],
        Cell = case P:parse(Toks) of
          {ok,[_,{type_refined,_,_,_,Pred}]} ->
             case refine(R, Pred) of opaque -> "REFUSED"; {ok,Iv} -> fmt(Iv) end;
          {error,_} -> "SYNTAX"
        end,
        io:format(" ~-11s", [Cell])
      end || P <- Parsers, R <- Readers],
     io:format("   % ~s~n", [Note])
   end || {S,Note} <- Rows],
  %% rewrite sizes
  io:format("~n-- AST size in words (erts_debug:flat_size) of `value >= -5 and value <= 5`~n"),
  [begin {ok,[_,{type_refined,_,_,_,A}]} = P:parse(tok("module M type T = int where value >= -5 and value <= 5")++[{'$end',1}]),
         io:format("  ~-8s ~p words~n",[short(P),erts_debug:flat_size(A)]) end || P <- Parsers],
  %% signed-domain residual
  io:format("~n-- signed residual: subtract(-10..10, 0)~n"),
  Res = sub([{-10,10}], [{0,0}]), io:format("  ~s~n  as refinement it needs: value >= -10 and value <= -1 or value >= 1 and value <= 10~n",[fmt(Res)]),
  R2 = refine(c1, hd1("value >= -10 and value <= -1 or value >= 1 and value <= 10")),
  io:format("  that residual spelled as a refinement under cur: ~p ; under c1: ~s~n",[refine(cur, hd1("value >= -10 and value <= -1 or value >= 1 and value <= 10")), fmt2(R2)]),
  io:format("  c1 round-trip equals residual: ~p~n",[R2 =:= {ok,Res}]).

hd1(S) -> {ok,[_,{type_refined,_,_,_,P}]} = base_p:parse(tok("module M type T = int where "++S)++[{'$end',1}]), P.
fmt2({ok,I}) -> fmt(I); fmt2(O) -> io_lib:format("~p",[O]).
short(base_p)->"base"; short(g1_p)->"g1"; short(g2_p)->"g2"; short(g1c_p)->"g1c".

%% --- transcribed from bs_check.erl:5136-5174 (alternatives/comparison/int_cmp/flip) ---
refine(R, Pred) ->
  case alts(R, Pred) of
    unknown -> opaque;
    Alts ->
      Rs = [conj(A) || A <- Alts],
      case lists:member(none_marker, Rs) of true -> opaque; false -> {ok, union(Rs)} end
  end.
alts(R, {e_op,_,'or',L,Rt}) -> case {alts(R,L),alts(R,Rt)} of {unknown,_}->unknown; {_,unknown}->unknown; {A,B}->A++B end;
alts(R, {e_op,_,'and',L,Rt}) -> case {alts(R,L),alts(R,Rt)} of {unknown,_}->unknown; {_,unknown}->unknown; {As,Bs}->[A++B||A<-As,B<-Bs] end;
alts(R, Cmp) -> case comparison(R, Cmp) of unknown -> unknown; C -> [[C]] end.
comparison(R, {e_op,_,Op,{e_var,_,V},K}) -> case konst(R,K) of {ok,N} -> int_cmp(Op,V,N); no -> unknown end;
comparison(R, {e_op,_,Op,K,{e_var,_,V}}) -> case konst(R,K) of {ok,N} -> int_cmp(flip(Op),V,N); no -> unknown end;
comparison(_, _) -> unknown.
int_cmp('>', V,K) -> {V,{include,[{K+1,pos_inf}]}};
int_cmp('>=',V,K) -> {V,{include,[{K,pos_inf}]}};
int_cmp('<', V,K) -> {V,{include,[{neg_inf,K-1}]}};
int_cmp('<=',V,K) -> {V,{include,[{neg_inf,K}]}};
int_cmp('==',V,K) -> {V,{include,[{K,K}]}};
int_cmp('!=',V,K) -> {V,{exclude,[{K,K}]}};
int_cmp(_,_,_) -> unknown.
flip('>')->'<'; flip('<')->'>'; flip('>=')->'<='; flip('<=')->'>='; flip(O)->O.
conj(Cs) -> lists:foldl(fun(_,none_marker)->none_marker;
   ({value,{include,I}},Acc)->inter(Acc,I); ({value,{exclude,I}},Acc)->sub(Acc,I); (_,_)->none_marker end,
   [{neg_inf,pos_inf}], Cs).
%% --- the comparand readers: this is the ONLY thing the fixes differ in (checker side) ---
konst(_, {e_int,_,K}) -> {ok,K};
konst(cur, _) -> no;
konst(c1, {e_neg,_,{e_int,_,K}}) -> {ok,-K};
konst(c1, _) -> no;
konst(c2, E) -> fold(E);
konst(c3, {e_neg,_,E}) -> case konst(c3,E) of {ok,N}->{ok,-N}; no->no end;
konst(c3, {e_op,_,Op,{e_int,_,A},{e_int,_,B}}) when Op=='+';Op=='-';Op=='*' -> {ok,ar(Op,A,B)};
konst(c3, {e_op,_,Op,A0,B0}) when Op=='+';Op=='-';Op=='*' ->
   case {lit1(A0),lit1(B0)} of {{ok,A},{ok,B}} -> {ok,ar(Op,A,B)}; _ -> no end;   % one level of e_neg operands only
konst(c3,_) -> no.
lit1({e_int,_,K})->{ok,K}; lit1({e_neg,_,{e_int,_,K}})->{ok,-K}; lit1(_)->no.
fold({e_int,_,K}) -> {ok,K};
fold({e_neg,_,E}) -> case fold(E) of {ok,N}->{ok,-N}; no->no end;
fold({e_op,_,Op,A,B}) when Op=='+';Op=='-';Op=='*';Op=='/';Op=='%' ->
   case {fold(A),fold(B)} of {{ok,X},{ok,Y}} -> case {Op,Y} of {'/',0}->no; {'%',0}->no; _ -> {ok,ar(Op,X,Y)} end; _ -> no end;
fold(_) -> no.
ar('+',A,B)->A+B; ar('-',A,B)->A-B; ar('*',A,B)->A*B; ar('/',A,B)->A div B; ar('%',A,B)->A rem B.
%% --- interval stand-in ---
union(L) -> lists:foldl(fun uni/2, [], L).
uni(A,B) -> norm(A++B).
norm(L) -> M = merge(lists:sort(fun le/2, [X||X={_,_}<-L, nonempty(X)])), M.
nonempty({A,B}) -> cmp(A,B) =< 0.
le({A,_},{B,_}) -> cmp(A,B) =< 0.
cmp(X,X)->0; cmp(neg_inf,_)->-1; cmp(_,neg_inf)->1; cmp(pos_inf,_)->1; cmp(_,pos_inf)->-1; cmp(A,B) when A<B->-1; cmp(_,_)->1.
merge([A,B|T]) -> {L1,H1}=A,{L2,H2}=B,
   case adj(H1,L2) of true -> merge([{L1,mx(H1,H2)}|T]); false -> [A|merge([B|T])] end;
merge(L) -> L.
adj(pos_inf,_)->true; adj(_,neg_inf)->true; adj(_,pos_inf)->false; adj(neg_inf,_)->false; adj(H,L)-> L=<H+1.
mx(A,B)-> case cmp(A,B)>=0 of true->A;false->B end.
mn(A,B)-> case cmp(A,B)=<0 of true->A;false->B end.
inter(A,B) -> norm([{mx(L1,L2),mn(H1,H2)}||{L1,H1}<-A,{L2,H2}<-B]).
sub(A,B) -> inter(A, compl(B)).
compl(B) -> compl(B, neg_inf, []).
compl([],Lo,Acc) -> lists:reverse(case Lo of pos_inf->Acc; _->[{Lo,pos_inf}|Acc] end);
compl([{L,H}|T],Lo,Acc) ->
   Acc1 = case L of neg_inf -> Acc; _ -> [{Lo,L-1}|Acc] end,
   case H of pos_inf -> lists:reverse(Acc1); _ -> compl(T,H+1,Acc1) end.
fmt(I) -> string:join([f({L,H})||{L,H}<-I]," | ").
f({neg_inf,pos_inf})->"int"; f({neg_inf,H})->io_lib:format("<=~p",[H]); f({L,pos_inf})->io_lib:format(">=~p",[L]); f({L,L})->io_lib:format("~p",[L]); f({L,H})->io_lib:format("~p..~p",[L,H]).
%% --- hand tokenizer (NOT bs_lexer) ---
tok(S) -> [t(W) || W <- string:tokens(re:replace(re:replace(S,"([-*/()])"," & ",[global,{return,list}]),"x"," x ",[global,{return,list}])," ")].
t("-")->{'-',1}; t(">=")->{'>=',1}; t("<=")->{'<=',1}; t("and")->{'and',1}; t("or")->{'or',1};
t("+")->{'+',1}; t("*")->{'*',1}; t("/")->{'/',1}; t("(")->{'(',1}; t(")")->{')',1}; t("=")->{'=',1};
t("!=")->{'!=',1}; t("<")->{'<',1}; t(">")->{'>',1};
t("type")->{'type',1}; t("where")->{'where',1}; t("module")->{'module',1};
t(W=[C|_]) when C>=$0,C=<$9 -> {integer,1,list_to_integer(W)};
t(W=[C|_]) when C>=$A,C=<$Z -> {uident,1,list_to_atom(W)};
t(W) -> {lident,1,list_to_atom(W)}.
