#!/usr/bin/env bash
# residual.sh BSC — does the residual the compiler prints for a signed bounded domain paste back?
# Needs a compiler that can spell the domain (any opt*, not base). Step 1 prints the residual;
# step 2 pastes exactly that text in as a clause and requires acceptance.
set -uo pipefail
BSC=$(readlink -f "${1:?}"); w=$(mktemp -d); trap 'rm -rf "$w"' EXIT; cd "$w"
mkdir -p $w/R1 $w/R2
cat > $w/R1/a.bs <<'S'
module R1
type D = int where value >= -10 and value <= 10
public atom K(D d)
K(>= 1) -> :pos
K(0) -> :zero
S
echo "-- step 1: delete the negative clause; the compiler's residual:"
"$BSC" $w/R1/a.bs 2>&1 | sed 's/^/   /'
res=$("$BSC" $w/R1/a.bs 2>&1 | sed -n '/no clause matches/,$p' | sed -n '2p' | sed 's/^ *K(//;s/) -> \.\.\.$//')
echo "-- extracted residual text: [$res]"
cat > $w/R2/a.bs <<S
module R2
type D = int where value >= -10 and value <= 10
public atom K(D d)
K(>= 1) -> :pos
K(0) -> :zero
K($res) -> :neg
S
echo "-- step 2: paste it back as a clause:"
out=$("$BSC" $w/R2/a.bs 2>&1); [ -z "$out" ] && echo "   accepted (round-trips)" || echo "$out" | sed 's/^/   /'
