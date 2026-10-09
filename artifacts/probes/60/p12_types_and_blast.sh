#!/bin/bash
# P12: (a) Option B marks FUNCTIONS: a record declared in the same module stays nameable by anyone. (b) Option A refuses the whole module, types included.
. "$(dirname "$0")/lib60.sh"
R=$(mktemp -d)
mk $R Acme/Orders 'module Acme.Orders

record Order { Id: int }

internal int Recompute(int n)
Recompute(n) -> n * 2'
mk $R Acme/Billing 'module Acme.Billing
using Acme.Orders

public int IdOf(Order o)
IdOf(o) -> o.Id'
echo "--- B: Billing names the record Order from a module whose only function is internal"
BSC_EBIN=/tmp/bsb_60_b/ebin cc $R Acme/Billing | grep -v Warning | head -3; echo "(empty above = accepted)"
rm -rf $R; R=$(mktemp -d)
mk $R Acme/Orders/Internal/Types 'module Acme.Orders.Internal.Types

record Secret { Id: int }'
mk $R Acme/Billing 'module Acme.Billing
using Acme.Orders.Internal.Types

public int IdOf(Secret s)
IdOf(s) -> s.Id'
echo "--- A: Billing names the record Secret from an Internal module"
BSC_EBIN=/tmp/bsb_60_a/ebin cc $R Acme/Billing | grep -v Warning | head -3
echo "--- control, unpatched:"; cc $R Acme/Billing | grep -v Warning | head -3; echo "(empty above = accepted)"
rm -rf $R
