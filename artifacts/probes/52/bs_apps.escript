#!/usr/bin/env escript
%%! -noshell
%% bs_apps.escript EBIN_DIR   -- the whole of a tool that turns provenance into an `applications` list.
%% Prints what it finds two ways: DECLARED (bs_requires attribute) and INFERRED (imports chunk + code:which).
main([Dir]) ->
    Beams = filelib:wildcard(filename:join(Dir, "*.beam")),
    Declared = lists:usort([A || B <- Beams, {ok,{_,[{attributes,At}]}} <- [beam_lib:chunks(B,[attributes])],
                                 {bs_requires, L} <- At, {A,_} <- L]),
    Imported = lists:usort([M || B <- Beams, {ok,{_,[{imports,I}]}} <- [beam_lib:chunks(B,[imports])], {M,_,_} <- I]),
    Inferred = lists:usort([A || M <- Imported, A <- [app_of(M)], A =/= none]),
    Unknown  = [M || M <- Imported, app_of(M) =:= none, code:which(M) =:= non_existing],
    io:format("declared (bs_requires)      : ~p~n", [Declared]),
    io:format("imported modules            : ~p~n", [Imported]),
    io:format("inferred app via code:which : ~p~n", [Inferred]),
    io:format("imported, no app inferable  : ~p~n", [Unknown]).

app_of(M) ->
    case code:which(M) of
        P when is_list(P) ->
            %% .../<App>[-Vsn]/ebin/<Mod>.beam ; OTP's own apps live under the root lib dir
            case lists:reverse(filename:split(P)) of
                [_, "ebin", Dir | _] -> list_to_atom(hd(string:split(Dir, "-")));
                _ -> none
            end;
        _ -> none
    end.
