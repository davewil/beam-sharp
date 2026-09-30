#!/usr/bin/env escript
%% p03: how many foreign `using :atom { }` blocks does the corpus hold, which application does
%% each module belong to, and how many would repeat an application if it were written per block?
%% Scans every .bs under the repo except artifacts/.  Lines: `using :name {` or `using :'Name' {`.
main(_) ->
    Root = "/home/user/beam-sharp",
    Files = [F || F <- filelib:wildcard(Root ++ "/**/*.bs"),
                  string:find(F, "/artifacts/") =:= nomatch],
    Rows = lists:append([scan(F) || F <- Files]),
    io:format("files scanned: ~p~nforeign using blocks: ~p~n", [length(Files), length(Rows)]),
    Classified = [{F, M, app_of(M)} || {F, M} <- Rows],
    Tally = lists:foldl(fun({_, _, A}, Acc) -> maps:update_with(A, fun(N) -> N + 1 end, 1, Acc) end,
                        #{}, Classified),
    io:format("~nblocks by resolved application on THIS machine (OTP ~s):~n", [erlang:system_info(otp_release)]),
    [io:format("  ~-28s ~p~n", [io_lib:format("~p", [A]), N]) || {A, N} <- lists:sort(maps:to_list(Tally))],
    %% distinct modules
    Mods = lists:usort([M || {_, M} <- Rows]),
    io:format("~ndistinct foreign modules: ~p~n", [length(Mods)]),
    [io:format("  ~-28s -> ~p~n", [io_lib:format("~p", [M]), app_of(M)]) || M <- Mods],
    %% per B# module (= directory), how many blocks, how many distinct apps (repeat cost if per block)
    ByDir = lists:foldl(fun({F, M, A}, Acc) ->
                                maps:update_with(filename:dirname(F), fun(L) -> [{M, A} | L] end, [{M, A}], Acc)
                        end, #{}, Classified),
    io:format("~nper B# module directory: blocks / distinct apps / blocks repeating an app~n", []),
    Tot = lists:foldl(fun({D, L}, {B0, R0}) ->
                              Apps = lists:usort([A || {_, A} <- L]),
                              Rep = length(L) - length(Apps),
                              io:format("  ~-70s ~p / ~p / ~p~n", [strip(D), length(L), length(Apps), Rep]),
                              {B0 + length(L), R0 + Rep}
                      end, {0, 0}, lists:sort(maps:to_list(ByDir))),
    io:format("TOTAL blocks ~p, blocks that would repeat an already-named app within their directory ~p~n",
              [element(1, Tot), element(2, Tot)]).
strip(D) -> string:prefix(D, "/home/user/beam-sharp/").
scan(F) ->
    {ok, Bin} = file:read_file(F),
    Lines = string:split(binary_to_list(Bin), "\n", all),
    lists:append([case re:run(L, "^\\s*using :('([^']*)'|([a-zA-Z_0-9]+))\\s*\\{", [{capture, all, list}]) of
                      {match, [_, _, Q]} when Q =/= [] -> [{F, list_to_atom(Q)}];
                      {match, [_, _, _, U]} -> [{F, list_to_atom(U)}];
                      _ -> []
                  end || L <- Lines]).
app_of(M) ->
    case code:which(M) of
        preloaded -> erts;
        non_existing -> unresolved;
        P -> %% .../lib/<app>-<vsn>/ebin/<m>.beam
            App = filename:basename(filename:dirname(filename:dirname(P))),
            list_to_atom(hd(string:split(App, "-")))
    end.
