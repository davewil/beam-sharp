#!/usr/bin/env bash
# 60a — ticket 60 measured: a module has no way to say WHO may name it.
#
# One source tree, three modules:
#
#   Shop/shop.bs           module Shop          the aggregate; calls RecomputeTotal
#   Shop/Orders/Orders.bs  module Shop.Orders   holds RecomputeTotal, a helper for Shop
#   Warehouse/Warehouse.bs module Warehouse     outside Shop's subtree; also calls it
#
# Each case writes the tree to a scratch directory, compiles the named module
# with the repo's own `bsc --src-root`, and prints the exit code and the
# diagnostic. Where a case compiles, the run is shown too, and the export list
# of 'Shop.Orders' is read back from its .beam.
#
# Usage:  ./60a_who_may_name.sh
# Needs:  compiler/_build/default/bin/bsc (rebar3 escriptize) and `erl` on PATH.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BSC="$ROOT/compiler/_build/default/bin/bsc"
WORK="${TMPDIR:-/tmp}/bs60a.$$"
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT

[ -x "$BSC" ] || { echo "FATAL: build bsc first: (cd compiler && rebar3 escriptize)" >&2; exit 2; }

SHOP='module Shop

using Shop.Orders

public int Settle(list<int> lines)

Settle(lines) -> RecomputeTotal(lines)'

WAREHOUSE='module Warehouse

using Shop.Orders

public int Reprice(list<int> lines)

Reprice(lines) -> RecomputeTotal(lines)'

WAREHOUSE_QUALIFIED='module Warehouse

public int Reprice(list<int> lines)

Reprice(lines) -> Shop.Orders.RecomputeTotal(lines)'

orders() {  # visibility marker
    printf 'module Shop.Orders\n\n%s int RecomputeTotal(list<int> lines)\n\nRecomputeTotal(lines) -> List.Sum(lines)\n' "$1"
}

tree() {  # dir, orders-visibility, warehouse-source
    mkdir -p "$1/src/Shop/Orders" "$1/src/Warehouse" "$1/out"
    printf '%s\n' "$SHOP"  > "$1/src/Shop/shop.bs"
    orders "$2"            > "$1/src/Shop/Orders/Orders.bs"
    printf '%s\n' "$3"     > "$1/src/Warehouse/Warehouse.bs"
}

compile() {  # dir, module-path, [function args...]
    local dir="$1" path="$2"; shift 2
    echo "--- bsc --src-root src src/$path $*"
    ( cd "$dir" && "$BSC" --src-root src "src/$path" "$@" ) 2>&1 | sed 's/^/    /'
    echo "    rc=${PIPESTATUS[0]}"
}

echo "=== 1. today: Shop.Orders.RecomputeTotal is public; both callers"
d="$WORK/c1"; tree "$d" public "$WAREHOUSE"
sed 's/^/    /' "$d/src/Shop/Orders/Orders.bs"
compile "$d" Shop Settle "[3, 4]"
compile "$d" Warehouse Reprice "[3, 4]"

echo "=== 2. today: the outside caller, fully qualified, no using line"
d="$WORK/c2"; tree "$d" public "$WAREHOUSE_QUALIFIED"
compile "$d" Warehouse Reprice "[3, 4]"

echo "=== 3. today: the one lever there is, private, refuses the aggregate too"
d="$WORK/c3"; tree "$d" private "$WAREHOUSE"
compile "$d" Shop Settle "[3, 4]"
compile "$d" Warehouse Reprice "[3, 4]"

echo "=== 4. what the BEAM is handed: the export list of 'Shop.Orders'"
d="$WORK/c4"; tree "$d" public "$WAREHOUSE"
( cd "$d" && "$BSC" --src-root src -o out src/Shop/Orders ) >/dev/null 2>&1
erl -noshell -pa "$d/out" -eval '
    {ok, {M, [{exports, Ex}]}} = beam_lib:chunks(code:which('"'"'Shop.Orders'"'"'), [exports]),
    io:format("    ~p exports ~p~n", [M, lists:sort(Ex)]),
    io:format("    an Erlang caller: ~p~n", [('"'"'Shop.Orders'"'"'):'"'"'RecomputeTotal'"'"'([3, 4])]),
    halt().' 2>&1

echo "=== 5. what Warehouse.Reprice compiles to: a plain remote call"
( cd "$d" && "$BSC" --src-root src -o out src/Warehouse ) >/dev/null 2>&1
erl -noshell -eval '
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks("'"$d"'/out/Warehouse.beam", [abstract_code]),
    [io:format("    ~s~n", [erl_pp:form(F)]) || F = {function, _, '"'"'Reprice'"'"', 1, _} <- Forms],
    halt().' 2>&1
