#!/usr/bin/env escript
%% ticket 52: can the compiler DERIVE the application from a module the source already names?
%% If yes, a declaration `app: req` restates what code:which/1 + the sibling .app file already know,
%% and the only thing a declaration adds is what is ABSENT.
main(_) ->
    code:add_pathz("/usr/lib/elixir/lib/elixir/ebin"),
    Mods = [erlang, maps, gen_server, string, lists, json, file, ets, binary,
            'Elixir.String', 'Elixir.Enum', 'Elixir.Application', 'Elixir.Req', epgsql],
    [begin
         case code:which(M) of
             non_existing -> io:format("~-22w absent from the code path (OTP ~s)~n", [M, erlang:system_info(otp_release)]);
             preloaded    -> io:format("~-22w preloaded (part of erts)~n", [M]);
             Path ->
                 Ebin = filename:dirname(Path),
                 Apps = filelib:wildcard(filename:join(Ebin, "*.app")),
                 App = case Apps of [A|_] -> {ok,[{application,N,Props}]} = file:consult(A),
                                             {N, proplists:get_value(vsn,Props)};
                                    [] -> no_app_file end,
                 io:format("~-22w -> ~p~n", [M, App])
         end
     end || M <- Mods].
