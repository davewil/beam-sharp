#!/usr/bin/env escript
main(_)->
 lists:foreach(fun(V)->
  {ok,m,B}=compile:file("out/d_5_"++V++"/m.erl",[binary,no_line_info]),
  {ok,{m,Cs}}=beam_lib:chunks(B,["AtU8","Code","StrT","ImpT","ExpT","LocT","Attr","CInf","LitT","FunT"],[allow_missing_chunks]),
  io:format("~-12s ~p~n",[V,[{K,case D of missing_chunk->0;_->byte_size(D) end}||{K,D}<-Cs]]) end,["none","tag_guard","tag_pattern"]).
