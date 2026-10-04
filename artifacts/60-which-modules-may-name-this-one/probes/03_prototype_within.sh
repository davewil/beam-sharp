#!/bin/bash
# (c) PROTOTYPE of the cheapest candidate on a COPY of the compiler (/tmp/c60a, built from HEAD sources):
#     a module-level `within <Prefix>` declaration, enforced at add_import (strict mode) for the
#     module tier AND the namespace tier. The patch is saved as 03_prototype_within.patch.
export PATH=/opt/otp28/bin:$PATH
HERE=$(cd "$(dirname "$0")" && pwd)
BSC=/tmp/c60a/_build/default/bin/bsc
rm -rf /tmp/t60 && cp -r "$HERE/tree" /tmp/t60 && cd /tmp/t60
echo "## 0. the tree as in probe 01 (no restriction yet): Billing compiles"
$BSC -o /tmp/o60e --src-root . Acme/Billing Invoice "[1,2,3]"; echo "exit=$?"

echo; echo "## 1. add ONE line to Acme/Orders/Rules/Rules.bs:  within Acme.Orders"
sed -i 's/^module Acme.Orders.Rules$/module Acme.Orders.Rules\nwithin Acme.Orders/' Acme/Orders/Rules/Rules.bs
head -3 Acme/Orders/Rules/Rules.bs
echo; echo "## 1a. Acme.Orders (the parent, inside the subtree) still compiles and RUNS"
$BSC -o /tmp/o60f --src-root . Acme/Orders Total "[1,2]"; echo "exit=$?"
echo; echo "## 1b. Acme.Billing (a SIBLING, outside the subtree) is refused at its using line"
$BSC -o /tmp/o60g --src-root . Acme/Billing Invoice "[1,2,3]"; echo "exit=$?"
echo; echo "## 1c. same refusal, machine-readable (--diagnostics json)"
$BSC --diagnostics json -o /tmp/o60g --src-root . Acme/Billing Invoice "[1,2,3]"; echo "exit=$?"
echo; echo "## 1d. Acme.Reports: no using at all, qualified call -- still the pre-existing module_not_imported (the check lives at using, and using is mandatory)"
$BSC -o /tmp/o60h --src-root . Acme/Reports Digest "[4,5]"; echo "exit=$?"

echo; echo "## 2. a module INSIDE the subtree (Acme.Orders.Tests) may name it -- the escape hatch is placement"
mkdir -p Acme/Orders/Tests
cat > Acme/Orders/Tests/Tests.bs <<'EOT'
module Acme.Orders.Tests

using Acme.Orders.Rules

public int Check()
Check() -> Recompute([1, 2, 3])
EOT
$BSC -o /tmp/o60i --src-root . Acme/Orders/Tests Check; echo "exit=$?"

echo; echo "## 3. segment boundary: Acme.OrdersExtra is NOT under Acme.Orders (string prefix is not segment prefix)"
mkdir -p Acme/OrdersExtra
cat > Acme/OrdersExtra/OrdersExtra.bs <<'EOT'
module Acme.OrdersExtra

using Acme.Orders.Rules

public int Sneak()
Sneak() -> Recompute([1])
EOT
$BSC -o /tmp/o60j --src-root . Acme/OrdersExtra Sneak; echo "exit=$?"

echo; echo "## 4. namespace tier: 'using Acme.Orders' resolves to the MODULE, but a namespace import of a directory with only restricted children must be checked too"
mkdir -p Zed/Inner/Hidden Zed/Outer
cat > Zed/Inner/Hidden/Hidden.bs <<'EOT'
module Zed.Inner.Hidden
within Zed.Inner

public int Secret()
Secret() -> 42
EOT
cat > Zed/Outer/Outer.bs <<'EOT'
module Zed.Outer

using Zed.Inner

public int Peek()
Peek() -> Hidden.Secret()
EOT
echo "(Zed.Inner holds no .bs file, so it is a namespace; Zed.Outer imports it)"
$BSC -o /tmp/o60k --src-root . Zed/Outer Peek; echo "exit=$?"

echo; echo "## 5. a within that does not contain the module itself"
mkdir -p Acme/Odd
cat > Acme/Odd/Odd.bs <<'EOT'
module Acme.Odd
within Acme.Orders

public int One()
One() -> 1
EOT
$BSC -o /tmp/o60l --src-root . Acme/Odd One; echo "exit=$?"
