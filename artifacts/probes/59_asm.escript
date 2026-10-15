#!/usr/bin/env escript
%% 59_asm.escript BEAM FUN/ARITY... -- compile the beam's own abstract code to assembly (`S`) and print
%% the named functions with LABELS, plus the export table (function, arity, entry label).
main([Beam | Fs]) ->
    {ok, {_, [{abstract_code, {_, Forms}}]}} = beam_lib:chunks(Beam, [abstract_code]),
    {ok, _, {_Mod, Exps, _Attrs, Funs, _N}} = compile:forms(Forms, ['S', return_errors, no_inline_list_funcs]) ,
    io:format("exports with entry label:~n"),
    [io:format("    ~p~n", [E]) || E <- Exps],
    %% asm exports carry no labels; the entry label is the one after func_info:
    [begin
         [N, A] = string:split(F, "/"), Name = list_to_atom(N), Ar = list_to_integer(A),
         [begin io:format("~s:~n", [F]), [io:format("    ~p~n", [I]) || I <- Is] end
          || {function, Nm, Ar2, _Entry, Is} <- Funs, Nm =:= Name, Ar2 =:= Ar]
     end || F <- Fs].
