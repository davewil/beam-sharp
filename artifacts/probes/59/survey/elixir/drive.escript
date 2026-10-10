#!/usr/bin/env escript
main(_) ->
    code:add_patha("ebin"),
    M = 'Elixir.Probe',
    F = fun(L,Th)-> R=try {returned,Th()} catch C:E:_ -> {raised,C,E} end, io:format("~-50s ~p~n",[L,R]) end,
    F("pub_cents(#{total=>7})   (no guard, no struct)", fun()->M:pub_cents(#{total=>7}) end),
    F("via_priv(#{total=>7})    (private, no guard)", fun()->M:via_priv(#{total=>7}) end),
    F("pub_inc(1.5)             (hand-written guard)", fun()->M:pub_inc(1.5) end),
    F("run_inc(1.5)             (hand-written guard on defp)", fun()->M:run_inc(1.5) end),
    F("struct_pub(#{total=>7})  (hand-written %Order{})", fun()->M:struct_pub(#{total=>7}) end),
    F("struct_via(#{total=>7})  (hand-written %Order{} on defp)", fun()->M:struct_via(#{total=>7}) end).
