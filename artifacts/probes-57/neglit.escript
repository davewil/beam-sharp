#!/usr/bin/env escript
%% Does erlc accept a negative integer literal node {integer,L,-5} (what G2/g1c would hand bs_emit:expr/2, line 917)
%% vs {op,L,'-',{integer,L,5}} (what e_neg emits, bs_emit.erl:1067)? Both through compile:forms.
main(_) ->
  [begin
     Forms = [{attribute,1,module,m},{attribute,1,export,[{f,1}]},
       {function,1,f,1,[{clause,1,[{var,1,'X'}],[[{op,1,'>=',{var,1,'X'},Lit}]],[{atom,1,ok}]},
                        {clause,1,[{var,1,'_'}],[],[{atom,1,no}]}]}],
     R = compile:forms(Forms,[binary,return_errors,return_warnings,'S']),
     {ok,m,Asm,Ws} = R, 
     io:format("~-34s warnings=~p  is_ge=~p~n",[Name,Ws,[I||I<-flat(Asm), element(1,I)==test, element(2,I)==is_ge]])
   end || {Name,Lit} <- [{"{integer,1,-5} (G2/g1c)",{integer,1,-5}},{"{op,1,'-',{integer,1,5}} (e_neg)",{op,1,'-',{integer,1,5}}},{"{op,'-',2,7} (arith)",{op,1,'-',{integer,1,2},{integer,1,7}}}]].

flat(T) when is_tuple(T) -> case T of {test,is_ge,_,_} -> [T]; _ -> lists:append([flat(E)||E<-tuple_to_list(T)]) end;
flat(L) when is_list(L) -> lists:append([flat(E)||E<-L]);
flat(_) -> [].
