-module(forge).
-export([main/0]).
o(K) -> #{'Kind' => K, 'Id' => 1, 'Total' => 7}.
l(Item, Q) -> #{'Kind' => 'T.Line', 'Item' => Item, 'Qty' => Q}.
t(Name, F) ->
    R = try F() catch C:E:St -> [{M,Fn,_,_}|_] = St, {C,E,raised_in,M,Fn} end,
    io:format("~-30s ~p~n", [Name, R]).
main() ->
    t("ViaLine nested forged tag", fun() -> 'T':'ViaLine'(l(o('T.Invoice'), 2)) end),
    t("ViaList elem forged tag",   fun() -> 'T':'ViaList'([o('T.Invoice')]) end),
    t("ViaOrder top-level forged", fun() -> 'T':'ViaOrder'(o('T.Invoice')) end),
    t("ViaItem returns nested forged", fun() -> 'T':'ViaItem'(l(o('T.Invoice'), 2)) end),
    t("ViaLineQty forged payload", fun() -> 'T':'ViaLineQty'(l(o('T.Order'), 2.5)) end).
