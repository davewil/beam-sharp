#!/usr/bin/env escript
%% REAL PROBE OF THE PROPOSED RULE'S EDGE CASES (not of bsc: bsc cannot be built here). The "rule" is hypothetical:
%%   "module Shop.Orders may be named only from within the subtree rooted at R" (R = 'Shop' or 'Shop.Reports').
%% PREDICTION (before running):
%%  - naive atom-string prefix (no dot boundary) WRONGLY admits Shop.ReportsV2 into subtree Shop.Reports.
%%  - segment-aware prefix (R ++ "." , the same technique as bs_check:children/2 at bs_check.erl:573-575) refuses it,
%%    admits R itself and R.Q.X, refuses sibling Shop.Billing and parent 'Shop' (a namespace, F15: no atom exists).
%%  - deriving R from a directory path via F15's dir<->dotted-name (Shop/Reports <-> 'Shop.Reports') agrees with the
%%    atom test on every case; a Windows-style or trailing-slash path would need normalising first.
-mode(compile).
main(_) ->
    Callers = ['Shop.Reports', 'Shop.ReportsV2', 'Shop.Reports.Q.X', 'Shop.Billing', 'Shop', 'Other.Reports', 'shop.reports'],
    Root = 'Shop.Reports',
    io:format("root = ~p~n~-20s ~-8s ~-8s ~-8s~n", [Root, "caller", "naive", "segment", "dirpath"]),
    [io:format("~-20s ~-8s ~-8s ~-8s~n", [atom_to_list(C), a(naive(C, Root)), a(seg(C, Root)), a(dirp(C, Root))]) || C <- Callers],
    %% children/2 copy (bs_check.erl:573-575), to show the existing code already uses the segment-aware form
    Known = ['Shop.Reports', 'Shop.ReportsV2', 'Shop.Reports.Q', 'Shop.Billing'],
    io:format("children('Shop.Reports') as bs_check does it: ~p~n", [children('Shop.Reports', Known)]),
    io:format("children('Shop.Reports') naive (no dot):     ~p~n", [[M || M <- Known, lists:prefix(atom_to_list('Shop.Reports'), atom_to_list(M))]]),
    %% root 'Shop' is a namespace: the world has no atom 'Shop' (F15), so a rule naming it cannot be validated by
    %% is_key(World); prefix semantics are the only reading
    World = #{'Shop.Reports' => x, 'Shop.Billing' => x},
    io:format("root 'Shop' is a world key? ~p ; any module under it? ~p~n",
              [maps:is_key('Shop', World), [M || M <- maps:keys(World), seg(M, 'Shop')] =/= []]),
    io:format("typo root 'Shp' matches any module? ~p  (a subtree rule naming a nonexistent namespace fails CLOSED: nobody admitted, so a rule naming a root with no modules should be its own error)~n",
              [[M || M <- maps:keys(World), seg(M, 'Shp')] =/= []]).

naive(C, R) -> lists:prefix(atom_to_list(R), atom_to_list(C)).
seg(C, R) -> S = atom_to_list(C), P = atom_to_list(R), S =:= P orelse lists:prefix(P ++ ".", S).
%% path form: module -> dir segments ("Shop.Reports" <-> ["Shop","Reports"]), subtree = list prefix of segments
dirp(C, R) -> lists:prefix(string:split(atom_to_list(R), ".", all), string:split(atom_to_list(C), ".", all)).
children(Prefix, Known) -> P = atom_to_list(Prefix) ++ ".", [M || M <- Known, lists:prefix(P, atom_to_list(M))].
a(true) -> "in"; a(false) -> "OUT".
