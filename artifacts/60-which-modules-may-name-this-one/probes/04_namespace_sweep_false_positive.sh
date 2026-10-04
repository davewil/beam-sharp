#!/bin/bash
# (c2) A namespace import SWEEPS every module under the prefix. With the v1 prototype
#      (refuse if ANY swept child is not visible) a caller that merely says `using Acme`
#      is refused over a restricted module it never asked for. v1 binary: /tmp/c60a1.
export PATH=/opt/otp28/bin:$PATH
HERE=$(cd "$(dirname "$0")" && pwd)
BSC=${BSC:-/tmp/c60a1/_build/default/bin/bsc}
rm -rf /tmp/t60b && cp -r "$HERE/tree" /tmp/t60b && cd /tmp/t60b
sed -i 's/^module Acme.Orders.Rules$/module Acme.Orders.Rules\nwithin Acme.Orders/' Acme/Orders/Rules/Rules.bs
rm -rf Acme/Billing Acme/Reports   # the legitimate violator from probe 03 would be refused on its own; remove it so only the sweep is measured
mkdir -p Acme/Dash
cat > Acme/Dash/Dash.bs <<'EOT'
module Acme.Dash

// `Acme` holds no .bs file: a namespace. This sweeps in Billing, Orders, Orders.Rules, Reports...
using Acme

public int Go()
Go() -> Orders.Total([1, 2])
EOT
echo "## v1 (refuse any swept child): Dash never names Rules"
$BSC -o /tmp/o60m --src-root . Acme/Dash Go; echo "exit=$?"
