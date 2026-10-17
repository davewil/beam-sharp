%% Probe 4b - the per-import cost of P1's rule in isolation (function body copied verbatim from p1-internal-segment.patch).
%% erlc p4b_visible_to_micro.erl && erl -noshell -pa . -eval 'p4b_visible_to_micro:main(), halt().'
-module(p4b_visible_to_micro).
-export([main/0]).
visible_to(M, Self) ->
    Segs = string:split(atom_to_list(M), ".", all),
    case lists:splitwith(fun(S) -> S =/= "Internal" end, Segs) of
        {_, []}      -> true;
        {Parent, _}  ->
            SelfSegs = string:split(atom_to_list(Self), ".", all),
            lists:prefix(Parent, SelfSegs)
    end.
main() ->
    N = 200000,
    {T, _} = timer:tc(fun() -> [visible_to('Shop.Billing.Internal.Ledger', 'Shop.Billing.Charge') || _ <- lists:seq(1, N)] end),
    io:format("visible_to: ~p ns/import; a 720-import tree pays ~p us in total~n", [T * 1000 div N, T * 720 div N]).
