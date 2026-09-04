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

main([InFile, NewModuleAtomStr, OutDir]) ->
    NewMod = list_to_atom(NewModuleAtomStr),
    {ok, Forms} = file:consult(InFile),
    Stripped = [strip(rename(F, NewMod)) || F <- Forms],
    OutS = filename:join(OutDir, NewModuleAtomStr ++ ".S"),
    ok = file:write_file(OutS, [io_lib:format("~p.~n~n", [F]) || F <- Stripped]),
    io:format("wrote ~s~n", [OutS]),
    case compile:file(OutS, [from_asm, {outdir, OutDir}, binary]) of
        {ok, NewMod, _Bin} ->
            io:format("compiled ~s from stripped asm (from_asm)~n", [NewModuleAtomStr]);
        {ok, NewMod, _Bin, _Warnings} ->
            io:format("compiled ~s from stripped asm (from_asm), with warnings~n", [NewModuleAtomStr]);
        Error ->
            io:format("COMPILE FAILED: ~p~n", [Error])
    end,
    halt().

rename({module, _}, New) -> {module, New};
rename({attributes, Attrs}, New) ->
    {attributes, [case A of {source, _} -> {source, atom_to_list(New) ++ ".S"}; _ -> A end || A <- Attrs]};
rename(Other, _New) -> Other.

%% Recursively strip {tr, Reg, _Type} -> Reg anywhere in the term tree.
strip({tr, Reg, _Type}) -> strip(Reg);
strip(T) when is_tuple(T) -> list_to_tuple([strip(E) || E <- tuple_to_list(T)]);
strip(L) when is_list(L) -> [strip(E) || E <- L];
strip(Other) -> Other.
