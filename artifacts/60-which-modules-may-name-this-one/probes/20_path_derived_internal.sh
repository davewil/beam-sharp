#!/bin/bash
# Option A' prototype (/tmp/c60d = HEAD + 20_path_derived.patch): NO new syntax. A module whose dotted
# name contains an `Internal` segment may be named only from under the segments before the last one
# (Go's rule, probe 19). One function pair in bs_check.erl and one diagnostic; lexer, parser and World untouched.
export PATH=/opt/otp28/bin:$PATH
HERE=$(cd "$(dirname "$0")" && pwd)
P=/tmp/c60d/_build/default/bin/bsc
rm -rf /tmp/t60f && mkdir /tmp/t60f && cd /tmp/t60f
mkdir -p Acme/Orders/Internal/Rules Acme/Orders/Tests Acme/Billing
cat > Acme/Orders/Internal/Rules/Rules.bs <<'EOT'
module Acme.Orders.Internal.Rules

public int Recompute(list<int> lines)
Recompute([]) -> 0
Recompute([x, ..rest]) -> x + Recompute(rest)
EOT
cat > Acme/Orders/Orders.bs <<'EOT'
module Acme.Orders

using Acme.Orders.Internal.Rules

public int Total(list<int> lines)
Total(lines) -> Recompute(lines)
EOT
cat > Acme/Orders/Tests/Tests.bs <<'EOT'
module Acme.Orders.Tests

using Acme.Orders.Internal.Rules

public int Check()
Check() -> Recompute([1, 2, 3])
EOT
cat > Acme/Billing/Billing.bs <<'EOT'
module Acme.Billing

using Acme.Orders.Internal.Rules

public int Invoice(list<int> lines)
Invoice(lines) -> Recompute(lines)
EOT
echo "## parent (Acme.Orders):";       $P -o /tmp/o60aa --src-root . Acme/Orders Total "[1,2]"; echo "exit=$?"
echo "## descendant (Acme.Orders.Tests):"; $P -o /tmp/o60ab --src-root . Acme/Orders/Tests Check; echo "exit=$?"
echo "## sibling (Acme.Billing):";       $P -o /tmp/o60ac --src-root . Acme/Billing Invoice "[1]"; echo "exit=$?"
echo "## HEAD compiler on the same tree (Billing):"; /tmp/c60/_build/default/bin/bsc -o /tmp/o60ad --src-root . Acme/Billing Invoice "[1]"; echo "exit=$?"
echo
echo "## the cost of the placement: the module's ATOM (and so its record tags, F3/26) carries the word"
erl -noshell -pa /tmp/o60aa -eval 'io:format("~p~n",[[M || M <- [list_to_atom("Acme.Orders.Internal.Rules")], code:ensure_loaded(M) =/= {error, nofile}]]), halt().'
ls /tmp/o60aa
