#!/usr/bin/env escript
%% For every B# module (a directory of .bs) in the repo: its foreign `using :M {` blocks, the application each
%% module lives in (code:which -> dir name) or "(absent)", and how many blocks share an application.
main([Root]) ->
    Files = filelib:wildcard(Root ++ "/**/*.bs"),
    Files1 = [F || F <- Files, string:str(F, "/artifacts/") =:= 0],
    ByDir = lists:foldl(fun(F, A) -> D = filename:dirname(F),
                maps:update_with(D, fun(L) -> [F|L] end, [F], A) end, #{}, Files1),
    Rows = [row(D, Fs) || {D, Fs} <- lists:sort(maps:to_list(ByDir))],
    Rows1 = [R || R = {_, Bs} <- Rows, Bs =/= []],
    io:format("B# files scanned: ~p in ~p directories; ~p directories have >=1 foreign using block~n",
              [length(Files1), maps:size(ByDir), length(Rows1)]),
    [begin
         Apps = lists:usort([A || {_, A} <- Bs]),
         io:format("~-72s blocks=~p modules=~p apps=~p ~p~n", [rel(Root, D), length(Bs), length(lists:usort([M || {M,_} <- Bs])), length(Apps), Apps])
     end || {D, Bs} <- Rows1],
    All = lists:append([Bs || {_, Bs} <- Rows1]),
    Third = [{M,A} || {M,A} <- All, not lists:member(A, ["erts","kernel","stdlib"])],
    io:format("~ntotal blocks=~p; blocks in a directory where >1 block shares an app: ~p~n",
              [length(All), length(lists:append([Bs || {_, Bs} <- Rows1, length(Bs) > length(lists:usort([A||{_,A}<-Bs]))]))]),
    io:format("blocks naming a module outside erts/kernel/stdlib (a real dependency): ~p ~p~n", [length(Third), lists:usort(Third)]).
rel(Root, D) -> string:prefix(D, Root ++ "/") =:= nomatch andalso D orelse string:prefix(D, Root ++ "/").
row(D, Fs) ->
    Bs = lists:append([blocks(F) || F <- Fs]),
    {D, Bs}.
blocks(F) ->
    {ok, Bin} = file:read_file(F),
    {match, Ms} = case re:run(Bin, "^using :('([^']+)'|([a-z_A-Z0-9]+))\\s*\\{", [multiline, global, {capture, all_but_first, binary}]) of
                      nomatch -> {match, []}; R -> R end,
    [begin
         Mod = case Cap of [_, Q] -> binary_to_atom(Q); [_, <<>>, P] -> binary_to_atom(P); [_, _, P] -> binary_to_atom(P) end,
         {Mod, app_of(Mod)}
     end || Cap <- Ms].
app_of(M) ->
    case code:which(M) of
        non_existing -> "(absent)";
        preloaded -> "erts";
        P -> A = filename:basename(filename:dirname(filename:dirname(P))),
             hd(string:split(A, "-"))
    end.
