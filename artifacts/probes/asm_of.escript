#!/usr/bin/env escript
%% usage: asm_of.escript FORMS OUTDIR
%% FORMS is an Abstract Format file, either consult-able text (bsc's .abstr) or a term_to_binary dump (Gleam's).
%% Writes OUTDIR/<module>.S: the 'S' listing, which keeps the {tr,Reg,Type} operand annotations.
main([F, Out]) ->
    {ok, Raw} = file:read_file(F),
    Forms = case file:consult(F) of
                {ok, Fs} -> Fs;
                _ -> binary_to_term(Raw)
            end,
    {ok, M, Asm} = compile:forms(Forms, ['S']),
    ok = file:write_file(filename:join(Out, atom_to_list(M) ++ ".S"), io_lib:format("~p.~n", [Asm])),
    io:format("~s written~n", [M]).
