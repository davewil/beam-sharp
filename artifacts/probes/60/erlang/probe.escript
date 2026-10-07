#!/usr/bin/env escript
main(_) ->
    [io:format("compile ~p: ~p~n", [M, element(1, compile:file(atom_to_list(M), [return_errors, debug_info, {outdir, "."}]))]) || M <- [shop_orders_cache, shop_orders, other_thing]],
    {ok, _} = xref:start(s), xref:set_default(s, [{warnings, false}]),
    {ok, _} = xref:add_directory(s, "."),
    %% Erlang gives no way to *declare* who may call; but xref can be ASKED, after the fact:
    %% every call into shop_orders_cache whose caller is not in the shop_orders subtree.
    {ok, Users} = xref:analyze(s, {module_use, shop_orders_cache}), All = [{{U,x,0},x} || U <- Users],
    io:format("modules using of shop_orders_cache: ~p~n", [Users]),
    Bad = [E || {{CM,_,_}, _} = E <- All, not lists:prefix("shop_orders", atom_to_list(CM))],
    io:format("outside shop_orders*: ~p~n", [Bad]),
    {ok, Docs} = code:get_doc(shop_orders_cache), io:format("docs: ~p~n", [element(5, Docs)]),
    io:format("other_thing:go(4) -> ~p~n", [(fun() -> code:load_file(shop_orders_cache), code:load_file(other_thing), other_thing:go(4) end)()]).
