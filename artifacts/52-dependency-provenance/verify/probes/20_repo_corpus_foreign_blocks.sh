#!/bin/sh
# What would "every non-OTP-core foreign module needs `from`" cost the code that exists today?
# Every `.bs` in the repo is parsed with the REAL parser; each foreign block's module is classified
# by the application that owns it on OTP 28 (path shape), and blocks per module are counted.
. "$(dirname "$0")/env.sh"
cat > $W/p20.escript <<'E'
#!/usr/bin/env escript
main([Root]) ->
    true = code:add_patha("/home/user/beam-sharp/compiler/_build/default/lib/bsc/ebin"),
    Files = [F || F <- filelib:wildcard(Root ++ "/**/*.bs"), string:find(F, "/artifacts/") =:= nomatch],
    Rows = lists:append([blocks(F) || F <- Files]),
    io:format("  .bs files parsed: ~p; files with >=1 foreign block: ~p; foreign blocks: ~p~n",
              [length(Files), length(lists:usort([F || {F, _} <- Rows])), length(Rows)]),
    Owned = [{M, owner(M)} || {_, M} <- Rows],
    ByApp = lists:foldl(fun({_, A}, Acc) -> maps:update_with(A, fun(N) -> N + 1 end, 1, Acc) end, #{}, Owned),
    io:format("  blocks by owning application: ~p~n", [lists:reverse(lists:keysort(2, maps:to_list(ByApp)))]),
    Core = [erts, kernel, stdlib],
    NonCore = [{M, A} || {M, A} <- Owned, not lists:member(A, Core)],
    io:format("  blocks outside {erts,kernel,stdlib}: ~p  (these would need `from`)~n", [length(NonCore)]),
    io:format("    ~p~n", [lists:usort(NonCore)]),
    PerFile = lists:foldl(fun({F, _}, Acc) -> maps:update_with(F, fun(N) -> N + 1 end, 1, Acc) end, #{}, Rows),
    io:format("  max foreign blocks in one file: ~p~n", [lists:max([0 | maps:values(PerFile)])]).
blocks(F) ->
    {ok, Bin} = file:read_file(F),
    case bs_lexer:string(binary_to_list(Bin)) of
        {ok, Toks, _} -> case bs_parser:parse(Toks) of
                             {ok, Ds} -> [{F, M} || {foreign, _, M, _} <- Ds];
                             _ -> [] end;
        _ -> [] end.
owner(M) ->
    case code:which(M) of
        preloaded -> erts;
        non_existing -> not_found;
        P -> case lists:reverse(filename:split(P)) of
                 [_, "ebin", D | _] -> list_to_atom(hd(string:split(D, "-", trailing)));
                 _ -> no_app end
    end.
E
escript $W/p20.escript /home/user/beam-sharp
