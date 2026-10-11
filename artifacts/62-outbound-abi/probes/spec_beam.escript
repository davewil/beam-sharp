#!/usr/bin/env escript
%% usage: spec_beam.escript FILE.beam -> one line per -spec and -type, via erl_pp
main([F]) ->
    {ok, {_, [{abstract_code, {_, Forms}}]}} = beam_lib:chunks(F, [abstract_code]),
    Out = [lists:flatten(erl_pp:form(Fm)) || Fm <- Forms,
              element(1, Fm) =:= attribute, element(3, Fm) =:= spec orelse element(3, Fm) =:= type],
    io:format("~ts", [lists:sort(Out)]).
