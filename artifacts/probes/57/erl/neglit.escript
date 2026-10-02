#!/usr/bin/env escript
%% Is an abstract-format {integer,L,-5} (what bs_emit would produce after a grammar fold,
%% bs_emit.erl:1049 handles e_neg as {op,L,'-',..}) accepted by compile:forms and does it run?
main(_) ->
    F = fun(Neg) ->
        Forms = [{attribute,1,module,m},{attribute,1,export,[{ge,1},{lit,0}]},
                 {function,1,ge,1,[{clause,1,[{var,1,'N'}],[[{op,1,'>=',{var,1,'N'},Neg}]],[{atom,1,true}]},
                                   {clause,1,[{var,1,'_'}],[],[{atom,1,false}]}]},
                 {function,2,lit,0,[{clause,2,[],[],[Neg]}]}],
        {ok, m, Bin} = compile:forms(Forms, [return_errors]),
        {module, m} = code:load_binary(m, "m.beam", Bin),
        {m:ge(-5), m:ge(-6), m:lit(), byte_size(Bin)}
    end,
    A = F({integer,1,-5}),
    B = F({op,1,'-',{integer,1,5}}),
    io:format("{integer,1,-5}      -> ~p~n{op,1,'-',{integer,1,5}} -> ~p~n", [A, B]),
    {true,false,-5,_} = A, {true,false,-5,_} = B,
    {_,_,_,S1} = A, {_,_,_,S2} = B,
    io:format("beam bytes equal: ~p~n", [S1 =:= S2]).
