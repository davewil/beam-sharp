%%% Probe for ticket 39 sub-investigation #2 (causal test).
%%%
%%% Reads a BEAM assembly (.S, from `erlc +to_asm`) file, strips every
%%% `{tr, Reg, Type}` JIT type-annotation wrapper down to bare `Reg`
%%% (recursively, everywhere it appears as an operand), renames the module
%%% to a new name so it can coexist with the original, and reassembles via
%%% compile:file(..., [from_asm]) -- i.e. skips beam_ssa_opt entirely and
%%% goes straight from (stripped) assembly to .beam, so the ONLY thing that
%%% changed relative to the original compiled module is the presence/
%%% absence of {tr,...} operand annotations. This directly tests whether the
%%% annotation itself is causally responsible for a measured slowdown,
%%% independent of source language or OTP version.
-module(strip_tr).
-export([main/1]).

to_list(A) when is_atom(A) -> atom_to_list(A);
to_list(L) when is_list(L) -> L.

main([InFileA, NewModuleAtomA, OutDirA]) ->
    InFile = to_list(InFileA),
    NewModuleAtomStr = to_list(NewModuleAtomA),
    OutDir = to_list(OutDirA),
    NewMod = list_to_atom(NewModuleAtomStr),
    {ok, Forms0} = file:consult(InFile),
    [{module, OldMod} | _] = Forms0,
    Forms = [substmod(F, OldMod, NewMod) || F <- Forms0],
    Stripped = [strip(F) || F <- Forms],
    OutS = filename:join(OutDir, NewModuleAtomStr ++ ".S"),
    ok = file:write_file(OutS, [io_lib:format("~p.~n~n", [F]) || F <- Stripped]),
    io:format("wrote ~s~n", [OutS]),
    case compile:file(OutS, [from_asm, {outdir, OutDir}, binary]) of
        {ok, NewMod, Bin} ->
            BeamPath = filename:join(OutDir, NewModuleAtomStr ++ ".beam"),
            ok = file:write_file(BeamPath, Bin),
            io:format("compiled ~s from stripped asm (from_asm) -> ~s~n", [NewModuleAtomStr, BeamPath]);
        {ok, NewMod, Bin, _Warnings} ->
            BeamPath = filename:join(OutDir, NewModuleAtomStr ++ ".beam"),
            ok = file:write_file(BeamPath, Bin),
            io:format("compiled ~s from stripped asm (from_asm), with warnings -> ~s~n", [NewModuleAtomStr, BeamPath]);
        Error ->
            io:format("COMPILE FAILED: ~p~n", [Error])
    end,
    halt().

%% Every occurrence of the old module atom -> new module atom, everywhere
%% in the term tree (module decl, func_info, call targets, source attr).
substmod(OldMod, OldMod, NewMod) -> NewMod;
substmod(T, OldMod, NewMod) when is_tuple(T) ->
    list_to_tuple([substmod(E, OldMod, NewMod) || E <- tuple_to_list(T)]);
substmod(L, OldMod, NewMod) when is_list(L) ->
    [substmod(E, OldMod, NewMod) || E <- L];
substmod(Other, _OldMod, _NewMod) -> Other.

%% Recursively strip {tr, Reg, _Type} -> Reg anywhere in the term tree.
strip({tr, Reg, _Type}) -> strip(Reg);
strip(T) when is_tuple(T) -> list_to_tuple([strip(E) || E <- tuple_to_list(T)]);
strip(L) when is_list(L) -> [strip(E) || E <- L];
strip(Other) -> Other.
