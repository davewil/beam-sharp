#!/usr/bin/env bash
# Probe E: how Erlang (OTP 25) spells and folds a negative literal. erl_parse.yrl is NOT installed
# here, so nothing is cited from its source; every claim is the output below.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd); w=$(mktemp -d); trap 'rm -rf "$w"' EXIT; cp "$here"/g.erl "$here"/bad.erl "$w"; cd "$w"; fail=0
echo "-- erl_parse: the PARSER does not fold; it emits {op,_,'-',{integer,_,5}} in guard, pattern and type range"
escript "$here"/parse.escript || fail=1
echo "-- erlc +to_core: guards and patterns hold -5 / 5 as constants (folded after parsing)"
erlc -W0 +to_core g.erl || fail=1
echo "guard comparands in core (ge: N >= -5; calc: N >= 2 + 3, -(5), 0 - 5):"; grep -E '^\s+-?[0-9]+\) ->' g.core | tr -s '\t ' ' ' | tr '\n' ';'; echo
grep -q "<-1> when 'true'" g.core || fail=1
echo "-- type ranges: Erlang accepts arithmetic and macros, rejects variables and empty ranges"
erlc -o "$w" g.erl && echo "g.erl (-5..5, (1+1)..(2*3), -(5)..5, (0-5)..5, ?LO..5): compiles" || fail=1
n=$(erlc bad.erl 2>&1 | grep -c "bad range type"); echo "bad.erl 'bad range type' errors: $n"; [ "$n" = 2 ] || fail=1
echo "-- abstract {integer,1,-5} compiles and behaves like {op,1,'-',{integer,1,5}}"
escript "$here"/neglit.escript || fail=1
exit $fail
