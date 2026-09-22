#!/usr/bin/env escript
%% Disassembles a given .beam file's named functions and writes full detail
%% to stdout, using io:format with ~p and a wide-enough approach that nothing
%% is truncated (each instruction on its own line).
main([BeamPath, FnNameStr]) ->
    FnName = list_to_atom(FnNameStr),
    Mod = beam_disasm:file(BeamPath),
    {beam_file, ModName, _, _, _, Fs} = Mod,
    io:format("module: ~p~n", [ModName]),
    [begin
         {function, Name, Arity, Entry, Code} = F,
         io:format("~n--- ~p/~p (entry ~p) ---~n", [Name, Arity, Entry]),
         [io:format("  ~p~n", [Instr]) || Instr <- Code]
     end
     || F <- Fs, element(1, F) =:= function, element(2, F) =:= FnName].
