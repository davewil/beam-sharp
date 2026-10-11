#!/usr/bin/env escript
%% usage: 10_otp_pascalcase_exports.escript OTP_LIB_DIR -> every export in every OTP beam whose name starts with an uppercase letter
%% (neighbour survey: does the Erlang/Elixir ecosystem already contain PascalCase function exports?)
main([Lib]) ->
    Beams = filelib:wildcard(filename:join([Lib, "*", "ebin", "*.beam"])),
    io:format("scanned ~w beams under ~s~n", [length(Beams), Lib]),
    Hits = lists:append([begin
        case beam_lib:chunks(B, [exports]) of
            {ok, {M, [{exports, Ex}]}} ->
                [{M, F, A} || {F, A} <- Ex, hd(atom_to_list(F)) >= $A, hd(atom_to_list(F)) =< $Z];
            _ -> []
        end end || B <- Beams]),
    io:format("exports starting with an uppercase letter: ~w~n", [length(Hits)]),
    [io:format("  ~p~n", [H]) || H <- lists:sublist(Hits, 12)],
    %% control: the same scan must find lowercase exports in the thousands
    All = lists:sum([case beam_lib:chunks(B, [exports]) of {ok, {_, [{exports, E}]}} -> length(E); _ -> 0 end || B <- Beams]),
    io:format("control: total exports scanned ~w~n", [All]).
