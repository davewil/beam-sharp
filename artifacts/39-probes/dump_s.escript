#!/usr/bin/env escript
%%% Reads a beam-sharp .abstr file (bs_emit's printed abstract format, one
%%% form per Erlang term ending in '.') and feeds it to compile:forms/2 with
%%% the 'S' option, to get the same .S instruction listing erlc would produce
%%% for hand-written Erlang carrying the identical abstract forms. This lets
%%% us compare beam-sharp's ACTUAL emitted abstract forms against Erlang's,
%%% instruction for instruction, on this OTP version.
main([AbstrPath]) ->
    {ok, Forms} = file:consult(AbstrPath),
    %% 'S' with compile:forms/2 returns the {ok, Mod, BeamAssembly} tuple
    %% directly (the .S text form is only written when compiling a .erl file
    %% on disk); BeamAssembly is exactly the same {Mod, Exports, Attrs, Fns,
    %% NumLabels} tuple beam_disasm:file/1 returns for a real .beam, so this
    %% prints the same {function,...} terms either way.
    case compile:forms(Forms, ['S', report_errors, report_warnings]) of
        {ok, _Mod, {_M, _Exports, _Attrs, Fns, _NumLabels}} ->
            [io:format("~p~n~n", [F]) || F <- Fns];
        Other ->
            io:format("~p~n", [Other])
    end.
