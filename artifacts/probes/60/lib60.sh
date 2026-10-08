# Multi-module helper. mk ROOT REL SRC : write ROOT/REL/a.bs (module decl inside SRC).
# cc ROOT MODDIR [BSC_EBIN] : compile ROOT/MODDIR with --src-root ROOT; prints diagnostics (empty = accepted).
BSC_EBIN=${BSC_EBIN:-/tmp/bsbuild/ebin}
mk() { mkdir -p "$1/$2"; printf '%s\n' "$3" > "$1/$2/${4:-a.bs}"; }
cc() { local root=$1 mod=$2; shift 2; (cd "$root" && erl -noshell -pa "$BSC_EBIN" -eval 'bsc:main(init:get_plain_arguments()), halt(0).' -extra --src-root . "$mod" "$@" 2>&1); }
# tree_a ROOT : the Option-A fixture (Acme.Orders.Internal.Pricing is the module to protect)
tree_a() { local R=$1
mk $R Acme/Orders/Internal/Pricing 'module Acme.Orders.Internal.Pricing

public int Compute(int n)
Compute(n) -> n * 2'
mk $R Acme/Orders 'module Acme.Orders
using Acme.Orders.Internal.Pricing

public int Total(int n)
Total(n) -> Compute(n) + 1'
mk $R Acme/Orders/Sub 'module Acme.Orders.Sub
using Acme.Orders.Internal.Pricing

public int Sub(int n)
Sub(n) -> Compute(n) + 2'
mk $R Acme/Billing_ok 'module Acme.Billing_ok
using Acme.Orders

public int Due(int n)
Due(n) -> Total(n)'
mk $R Acme/Billing_bad 'module Acme.Billing_bad
using Acme.Orders.Internal.Pricing

public int Due(int n)
Due(n) -> Compute(n)'
mk $R Ext/Billing_ns 'module Ext.Billing_ns
using Acme

public int Due(int n)
Due(n) -> Orders.Total(n)'
mk $R Ext/Billing_ns_bad 'module Ext.Billing_ns_bad
using Acme

public int Due(int n)
Due(n) -> Orders.Internal.Pricing.Compute(n)'
}
# tree_b ROOT : the Option-B fixture (Acme.Orders.Recompute is `internal`)
tree_b() { local R=$1
mk $R Acme/Orders 'module Acme.Orders

internal int Recompute(int n)
Recompute(n) -> n * 2

public int Total(int n)
Total(n) -> Recompute(n) + 1

public fn(int) -> int Handout()
Handout() -> Recompute'
mk $R Acme/Orders/Tests 'module Acme.Orders.Tests
using Acme.Orders

public int Check(int n)
Check(n) -> Recompute(n)'
mk $R Acme/Billing_unq 'module Acme.Billing_unq
using Acme.Orders

public int Due(int n)
Due(n) -> Recompute(n)'
mk $R Acme/Billing_qual 'module Acme.Billing_qual
using Acme.Orders

public int Due(int n)
Due(n) -> Acme.Orders.Recompute(n)'
mk $R Acme/Billing_pub 'module Acme.Billing_pub
using Acme.Orders

public int Due(int n)
Due(n) -> Total(n)'
mk $R Acme/Billing_fun 'module Acme.Billing_fun
using Acme.Orders

public int Apply(fn(int) -> int f, int n)
Apply(f, n) -> f(n)

public int Due(int n)
Due(n) -> Apply(Handout(), n)'
}
# tree_c ROOT : the Option-C fixture (Acme.Pricing lists its friends)
tree_c() { local R=$1
mk $R Acme/Pricing 'module Acme.Pricing
friend Acme.Orders

public int Compute(int n)
Compute(n) -> n * 2'
mk $R Acme/Orders 'module Acme.Orders
using Acme.Pricing

public int Total(int n)
Total(n) -> Compute(n) + 1'
mk $R Acme/Orders/Sub 'module Acme.Orders.Sub
using Acme.Pricing

public int Sub(int n)
Sub(n) -> Compute(n) + 2'
mk $R Acme/Billing 'module Acme.Billing
using Acme.Pricing

public int Due(int n)
Due(n) -> Compute(n)'
mk $R Acme/Reports 'module Acme.Reports
using Acme.Pricing

public int Rep(int n)
Rep(n) -> Compute(n)'
}
