#!/bin/sh
D=$(cd "$(dirname "$0")" && pwd); W=${PROBE_TMP:-$(mktemp -d)}
erlc -o "$W" "$D/repr_cost.erl" && erl -noshell -pa "$W" -eval 'repr_cost:sizes(), repr_cost:ambiguity(), repr_cost:time(50000000), halt().'
