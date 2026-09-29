#!/usr/bin/env escript
main([B]) -> {beam_file,_,_,_,_,Fns} = beam_disasm:file(B), [io:format("~~p~~n",[C]) || {function,get_item5,1,_,C} <- Fns].
