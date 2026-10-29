#!/usr/bin/env escript
main([Out]) ->
  {ok,{_,Z}} = zip:create("mem", [{"emb.beam", element(2,file:read_file("es/emb.beam"))},{"main.beam", element(2,file:read_file("es/main.beam"))}], [memory]),
  ok = escript:create(Out, [shebang, {emu_args,"-escript main main"}, {archive, Z}]).
