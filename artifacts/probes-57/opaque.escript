#!/usr/bin/env escript
%%! -pa var
%% intervals_tests.erl:46-53 expects `type Email = int where WellFormed(value)` to reach the checker as {opaque_refinement,_}.
main(_) ->
  Toks = [{'module',1},{uident,1,'M'},{'type',1},{uident,1,'Email'},{'=',1},{lident,1,int},{'where',1},{uident,1,'WellFormed'},{'(',1},{lident,1,value},{')',1},{'$end',1}],
  [io:format("~-6s ~p~n",[P, P:parse(Toks)]) || P <- [base_p,g1_p,g2_p,g1c_p]].
