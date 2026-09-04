#!/usr/bin/env escript
%%% Reads a beam-sharp .abstr file (bs_emit's printed abstract format, one
%%% form per Erlang term ending in '.') and feeds it to compile:forms/2 with
%%% the 'S' option, to get the same .S instruction listing erlc would produce
%%% for hand-written Erlang carrying the identical abstract forms. This lets
%%% us compare beam-sharp's ACTUAL emitted abstract forms against Erlang's,
%%% instruction for instruction, on this OTP version.
main([AbstrPath]) ->
    {ok, Forms} = file:consult(AbstrPath),
    case compile:forms(Forms, ['S', binary, report_errors, report_warnings]) of
        {ok, _Mod, _Bin} ->
            io:format("compiled ok (S listing written alongside as .beam's .S "
                       "by the compiler is not emitted to stdout by forms/2; "
                       "use compile:forms/2 return value instead)~n");
        Other ->
            io:format("~p~n", [Other])
    end.
