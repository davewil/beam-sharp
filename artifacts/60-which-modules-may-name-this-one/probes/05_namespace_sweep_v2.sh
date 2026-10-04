#!/bin/bash
# (c3) v2 of the prototype (/tmp/c60a): a namespace import drops the restricted children the caller
#      may not name instead of refusing. Then: what does the caller see when it tries to use one?
export PATH=/opt/otp28/bin:$PATH
HERE=$(cd "$(dirname "$0")" && pwd)
BSC=/tmp/c60a/_build/default/bin/bsc
rm -rf /tmp/t60c && cp -r "$HERE/tree" /tmp/t60c && cd /tmp/t60c
sed -i 's/^module Acme.Orders.Rules$/module Acme.Orders.Rules\nwithin Acme.Orders/' Acme/Orders/Rules/Rules.bs
rm -rf Acme/Billing Acme/Reports
# consumers live OUTSIDE Acme: a consumer inside the namespace it sweeps sees the other consumer and the
# compiler reports an import cycle (pre-existing behaviour of `using <ancestor>`; the first attempt, with consumers inside Acme, printed an import_cycle error and is described in the brief)
mkdir -p Out/Dash Out/Dash2
cat > Out/Dash/Dash.bs <<'EOT'
module Out.Dash
using Acme
public int Go()
Go() -> Orders.Total([1, 2])
EOT
cat > Out/Dash2/Dash2.bs <<'EOT'
module Out.Dash2
using Acme
public int Go()
Go() -> Orders.Rules.Recompute([1, 2])
EOT
echo "## v2: Dash sweeps in 'Acme' and calls only Orders.Total"
$BSC -o /tmp/o60n --src-root . Out/Dash Go; echo "exit=$?"
echo; echo "## v2: Dash2 sweeps in 'Acme' and then reaches for Orders.Rules.Recompute through the namespace"
$BSC -o /tmp/o60o --src-root . Out/Dash2 Go; echo "exit=$?"
echo; echo "## v2: ...and if Dash2 follows that advice and writes the full path it is told the real reason"
sed -i 's/^using Acme$/using Acme\nusing Acme.Orders.Rules/' Out/Dash2/Dash2.bs
$BSC -o /tmp/o60p --src-root . Out/Dash2 Go; echo "exit=$?"
