#!/bin/bash
# Erlang/OTP 28: no module visibility exists. Evidence: (1) -moduledoc false is documentation-only;
# (2) the tool OTP ships for "who calls whom" is xref, a QUERY over compiled beams, outside the compiler.
# (3) the same query run over B#'s own beams answers ticket 60's question with ZERO compiler change.
export PATH=/opt/otp28/bin:$PATH
HERE=$(cd "$(dirname "$0")" && pwd)
L=/opt/otp28/lib/erlang/lib
echo "## (0) words in OTP 28 stdlib/kernel/tools source: friend / internal-module visibility attributes"
grep -rli -E "^-(friend|internal|visible_to|restrict)\b" $L/*/src/*.erl | head -3; echo "(none above = no such attribute)"
echo "## (1) modules in stdlib-7.0 marked -moduledoc false: $(grep -l '^-moduledoc false' $L/stdlib-7.0/src/*.erl | wc -l) of $(ls $L/stdlib-7.0/src/*.erl | wc -l)"
erl -noshell -eval '
  R = code:get_doc(dets_utils),
  io:format("code:get_doc(dets_utils) -> ~P~n",[R, 6]),
  io:format("a caller outside stdlib names it anyway: dets_utils:module_info(module) = ~p, exports ~p functions~n",[dets_utils:module_info(module), length(dets_utils:module_info(exports))]),
  halt().'
echo
echo "## (3) xref over the B# tree compiled by HEAD bsc (Acme.Billing -> Acme.Orders.Rules is the unwanted edge)"
rm -rf /tmp/xr60 && mkdir /tmp/xr60 && cd "$HERE/tree" && for d in Acme/Orders/Rules Acme/Orders Acme/Billing; do /tmp/c60/_build/default/bin/bsc -o /tmp/xr60 --src-root . $d >/dev/null 2>&1; done
ls /tmp/xr60
erl -noshell -eval '
  {ok,_} = xref:start(s),
  xref:set_default(s, [{verbose,false},{warnings,false}]),
  {ok,_} = xref:add_directory(s, "/tmp/xr60"),
  {ok, All} = xref:q(s, "ME"),
  io:format("every module-level call edge in the tree: ~p~n",[lists:sort(All)]),
  Bad = [E || {From,To} = E <- All, To =:= (list_to_atom("Acme.Orders.Rules")), not lists:prefix("Acme.Orders", atom_to_list(From))],
  io:format("edges INTO Acme.Orders.Rules from outside Acme.Orders: ~p~n",[Bad]),
  halt().' 2>&1 | head -20
