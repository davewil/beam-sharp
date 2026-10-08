#!/bin/bash
# P11: ticket 41 §5 drew `Orders/Internal/` as a "SUB-MODULE, source-only (ticket 13)". F15.11 says a nested directory holding .bs files is its own module.
# Execute: a module Acme.Orders with a nested Acme/Orders/Internal/Pricing -- how many .beam files, and does Acme.Orders's file set include Pricing's source?
. "$(dirname "$0")/lib60.sh"
R=$(mktemp -d); tree_a $R
cc $R Acme/Orders >/dev/null 2>&1
echo "beams emitted by compiling Acme/Orders (which uses the nested Internal.Pricing):"; (cd $R && ls *.beam)
echo "--- exports of each beam's module:"
cat > $R/rt.erl <<'ERL'
-module(rt).
-export([main/0]).
main() -> [begin A = list_to_atom(M), io:format("~s: ~p~n", [M, [E || E = {N,_} <- A:module_info(exports), N =/= module_info]]) end || M <- ["Acme.Orders", "Acme.Orders.Internal.Pricing"]].
ERL
(cd $R && erlc rt.erl && erl -noshell -pa . -eval 'rt:main(), halt().')
rm -rf $R
