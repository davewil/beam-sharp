#!/usr/bin/env bash
# ticket 82: run everything. Needs OTP 28 on PATH and a bsc built from compiler/ (BSC=... to override).
set -u; cd "$(dirname "$0")"; export PATH=/opt/otp28/bin:$PATH
BSC=${BSC:-/tmp/dl/compiler-build/_build/default/bin/bsc}
echo "=== exemplar, three inputs (clean / undeclared field / wrong type)"
$BSC -o /tmp/dl/out82 Orders OrderBody "{ Kind = :'Orders.Order', Id = 1, Total = 5 }" 2>&1 | head -3
$BSC -o /tmp/dl/out82 Orders OrderBody "{ Kind = :'Orders.Order', Id = 1, Total = 5, Secret = 7 }" 2>&1 | head -3
$BSC -o /tmp/dl/out82 Orders OrderBody "{ Kind = :'Orders.Order', Id = \"x\", Total = 5 }" 2>&1 | head -3
$BSC -o /tmp/dl/outM Many Body "[{ Kind = :'Many.Order', Id = 1, Total = 5 }]" >/dev/null 2>&1
echo "=== crash shapes";  ./crash_shapes.escript /tmp/dl/out82
echo "=== shallow leak";  ./shallow_leak.escript
echo "=== guard cost";    ./guard_cost.escript /tmp/dl/outM
