#!/bin/sh
D=$(cd "$(dirname "$0")" && pwd); BSC=${BSC:?set BSC}
echo '== the WHO half: an unrelated module names Shop.Internal.Pricing.Total (a public function)'
"$BSC" --src-root "$D/bs" "$D/bs/Other" Go 4 2>&1 | head -4
echo '== control for the WHAT half: an unrelated module names the private Helper'
"$BSC" --src-root "$D/bs" "$D/bs/OtherPrivate" GoPrivate 4 2>&1 | head -4
echo '== a compile-time rule cannot bind foreign callers: Elixir calls the "internal" module directly'
W=${PROBE_TMP:-$(mktemp -d)}
"$BSC" --src-root "$D/bs" -o "$W" "$D/bs/Shop/Internal/Pricing" >/dev/null 2>&1
elixir -pa "$W" -e 'IO.inspect(:"Shop.Internal.Pricing"."Total"(4), label: ":\"Shop.Internal.Pricing\".\"Total\"(4)")' 2>&1 | head -2
