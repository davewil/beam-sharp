#!/usr/bin/env escript
main(_) ->
    code:add_patha("ebin"),
    t("total([1, 2.5])          private int fn UNguarded", fun() -> leaf:total([1, 2.5]) end),
    t("total_guarded([1, 2.5])  private int fn is_integer-guarded", fun() -> leaf:total_guarded([1, 2.5]) end).
t(N, F) -> R = try F() catch C:E -> {C,E} end, io:format("~-66s => ~p~n", [N, R]).
