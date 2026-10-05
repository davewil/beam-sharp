#!/usr/bin/env bash
# TICKET CLAIM (60, from 24 section 2): a helper like RecomputeTotal/1 "is neither [callback nor client API]
# and lands `unclassified`; an agent writing tests will target it".
# This probe asks what the compiler publishes TODAY (after F12, which shipped after 24 was written).
# The ticket claim is REFUTED (as stated) IF a `private` RecomputeTotal does not appear in `bsc --api`
# and cannot be named from a test module. It is REINSTATED in narrower form IF a helper that sibling
# modules need (so must be `public`) appears in `bsc --api` with no distinction from the client API.
. "$(dirname "$0")/lib.sh"
build_variant base >/dev/null || exit 1
B=$(bsc_of base); T="$WORK/p14"; rm -rf "${T:?}"; mkdir -p "$T/Orders" "$T/OrdersTest" "$T/OrdersPub"
mk() { # dir module visibility-of-helper
cat > "$T/$1/o.bs" <<EOT
module $2

behaviour GenServer

type Request = :get | (:add, int)
type Reply   = (:reply, int, int)

public (:ok, int) Init(int seed)
Init(seed) -> (:ok, seed)

public Reply HandleCall(Request request, term from, int state)
HandleCall(:get, from, state)      -> (:reply, state, state)
HandleCall((:add, n), from, state) -> (:reply, Recompute(state + n), Recompute(state + n))

type Cast = (:add, int) | :reset
type NoReply = (:noreply, int)
public NoReply HandleCast(Cast msg, int state)
HandleCast((:add, n), state) -> (:noreply, state + n)
HandleCast(:reset, state)    -> (:noreply, 0)

public int Apply(int total, int n)
Apply(total, n) -> Recompute(total + n)

$3 int Recompute(int total)
Recompute(total) -> total
EOT
}
mk Orders Orders private
mk OrdersPub OrdersPub public
echo '--- bsc --api, helper is private (F12 default): is Recompute listed?'
(cd "$T" && "$B" --api Orders)
echo '--- bsc --api, helper made public so a sibling module can call it: any distinction from the client API?'
(cd "$T" && "$B" --api OrdersPub)
cat > "$T/OrdersTest/t.bs" <<'EOT'
module OrdersTest

using Orders

public int Probe(int n)
Probe(n) -> Recompute(n)
EOT
echo '--- a test module (ordinary B#, ticket 24 section 7) naming the private helper:'
(cd "$T" && "$B" -o "$T/o" OrdersTest 2>&1)
echo '--- does the compiler have an unclassified boundary category anywhere in the api path?'
grep -n -i 'unclassified\|callbacks:\|boundary:' "$REPO/compiler/src/bs_api.erl" ; echo "(grep exit $?: 1 = no such category in bs_api.erl; the only unclassified in src is the diagnostic tag in bs_diag.erl)"
(cd "$T" && "$B" --api Orders | grep -q Recompute); priv_listed=$?
[ $priv_listed -ne 0 ]; verdict "private-helper-is-NOT-published-by-api (ticket claim stale for private helpers)" $?
(cd "$T" && "$B" --api OrdersPub | grep -q Recompute); verdict "public-helper-IS-listed-undistinguished (narrower claim survives)" $?
