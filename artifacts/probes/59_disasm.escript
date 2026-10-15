#!/usr/bin/env escript
%% 59_disasm.escript BEAM FUN/ARITY... -- print the BEAM assembly of the named functions
%% (beam_disasm), so "one entry label" and "where does the guard sit" are read, not argued.
main([Beam | Fs]) ->
    {beam_file, _Mod, _Exp, _, _, Funs} = beam_disasm:file(Beam),
    [begin
         [N, A] = string:split(F, "/"), Name = list_to_atom(N), Ar = list_to_integer(A),
         [begin io:format("~s:~n", [F]), [io:format("    ~p~n", [I]) || I <- Is] end
          || {function, Nm, Ar2, _, Is} <- Funs, Nm =:= Name, Ar2 =:= Ar]
     end || F <- Fs].
