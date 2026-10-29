#!/usr/bin/env escript
main(_) ->
  [begin
     io:format("== ~s~n",[V]),
     R = yecc:file("var/"++V++".yrl",[{verbose,false},{report,true},{return,true},{parserfile,"var/"++V++"_p.erl"}]),
     case R of {ok,_,W} -> io:format("  warnings: ~p~n",[[Msg || {_,Ws} <- W, {_,_,Msg} <- Ws]]); O -> io:format("  ~p~n",[O]) end
   end || V <- ["base","g1","g1c","g2"]].
