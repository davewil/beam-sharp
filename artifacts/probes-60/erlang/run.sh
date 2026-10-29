#!/bin/sh
cd "$(dirname "$0")"; rm -rf ebin; mkdir ebin
echo "## erlc (calls to non-exported / outside friend compile silently?)"; erlc +debug_info -o ebin *.erl; echo "erlc rc=$?"
echo "## runtime"; erl -noshell -pa ebin -eval '
io:format("charge(1) -> ~p~n",[shop_billing:charge(1)]),
io:format("bad(1) -> ~p~n",[catch shop_billing:bad(1)]),
io:format("apply non-exported: ~p~n",[catch apply(shop_orders_internal, hidden, [1])]),
halt().'
echo "## xref friend pass"; escript friend.escript ebin
