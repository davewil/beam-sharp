#!/usr/bin/env bash
# mix xref callers / graph over the 3-module project: the edges a caller-whitelist would read
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"; D=$(mktemp -d); cd "$D"
mix new shop --sup >/dev/null 2>&1 || mix new shop >/dev/null
cd shop && rm -f lib/shop.ex test/shop_test.exs && cp -r "$HERE/proj3/." lib/
mix compile 2>&1 | tail -2
echo "--- mix xref callers Shop.Orders.Internal"; mix xref callers Shop.Orders.Internal
echo "--- mix xref graph --sink (file path is the 1.14 argument form; the module name was a usage error, first run)"; ls lib lib/orders; mix xref graph --sink lib/orders/internal.ex --label compile-connected --format plain; mix xref graph --sink lib/orders/internal.ex --format plain
