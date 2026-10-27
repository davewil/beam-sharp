#!/usr/bin/env bash
# Needs p5 to have run (uses its scratch bs_check_a). Hypothesis: the added check alone costs well under 1 us per
# import and does not depend on World size (falsifiable: ns/check at N=100 vs N=10000 same order).
# Run 1 used an interpreted (erl -eval) loop and reported ~5.8 us: that was the harness, kept in p6_run1_*.out.
S=/tmp/claude-0/-home-user-beam-sharp/e165fddb-d743-5cdb-816c-e9e70eb257c6/scratchpad/chk
cd "$S" || exit 2
cat > loop.erl <<'X'
-module(loop).
-export([main/0]).
spin(0, _W) -> ok;
spin(R, W) -> bs_check_a:visible_to('Shop.Orders', 'Shop.Orders.Total.Deep', 1, W), spin(R - 1, W).
spin0(0) -> ok;
spin0(R) -> spin0(R - 1).
main() ->
  lists:foreach(fun(N) ->
    W0 = lists:foldl(fun(I,W)->W#{list_to_atom("Pad.M"++integer_to_list(I))=>#{exports=>#{},types=>#{}}} end,#{},lists:seq(1,N)),
    W = W0#{'Shop.Orders' => #{exports=>#{},types=>#{},visible_to=>['Shop.Orders','Shop.Billing']}},
    R = 2000000,
    {U0,_} = timer:tc(fun() -> spin0(R) end),
    {US,_} = timer:tc(fun() -> spin(R, W) end),
    io:format("OTP 25  N=~w  ~.1f ns per visible_to check (empty loop ~.1f ns; 2 prefixes, insider)~n",[N,US*1000/R,U0*1000/R])
  end,[100,10000]).
X
erlc loop.erl && erl -noshell -pa . -eval 'loop:main(),halt().'
