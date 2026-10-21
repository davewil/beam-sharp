#!/usr/bin/env bash
# Ticket 60 (prototype, patches/60a-internal-marker.patch): `internal` as a third visibility marker whose
# scope is the callee module's first name segment. One caller inside the scope, one outside, then the
# emitted export list and a call from plain Erlang, to show what is NOT enforced at run time.
. "$(cd "$(dirname "$0")" && pwd)/env.sh"
S=$root/artifacts/probes/src60; v=${1:-v60a}; O=$(mktemp -d); trap 'rm -rf "$O"' EXIT
export BSC_EBIN=$PROBE_HOME/variants/$v/ebin
for m in Shop/Orders Shop/Billing Other; do
  printf '%-14s ' "$m"
  if out=$($BSC --src-root $S -o $O $S/$m 2>&1) && [ -z "$out" ]; then echo accepted; else echo "refused"; printf '%s\n' "$out" | sed 's/^/      | /'; fi
done
erl -noshell -pa $O -eval '
  io:format("exports of Shop.Orders: ~p~n",[lists:sort(proplists:get_value(exports,'"'"'Shop.Orders'"'"':module_info()))]),
  io:format("plain Erlang calls Shop.Orders:RecomputeTotal(3) -> ~p~n",[catch '"'"'Shop.Orders'"'"':'"'"'RecomputeTotal'"'"'(3)]), halt().' 2>&1
