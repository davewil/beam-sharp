#!/bin/sh
# p03: what does the compile-time presence check cost?
#  (a) primitive cost of each code-path query, hit and miss, path padded to 42/142/542 entries
#  (b) cost inside bsc itself (PROTOTYPE, 30 compiles per mode in one VM) for 1/20/60 foreign blocks
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8
HERE=$(cd "$(dirname "$0")" && pwd)
echo "################ (a) primitives"
for PAD in 0 100 500; do
  echo "#### path padded by $PAD dirs (ERL_LIBS=elixir libs)"
  ERL_LIBS=/tmp/otp/lib/elixir/lib escript "$HERE/cost.escript" $PAD
done
echo "################ (b) inside the prototype bsc (noise is ~+-1 ms; compare medians AND mins)"
"$HERE/../proto/build.sh" /tmp/bs52_proto >/dev/null 2>&1 || exit 1
for N in 1 20 60; do
  for ANN in 0 1; do
    W=$(mktemp -d); ERL_LIBS=/tmp/otp/lib/elixir/lib escript "$HERE/gen.escript" $N $ANN $W
    echo "#### $N foreign blocks, annotated=$ANN  ($(grep -c '^using' $W/Big/big.bs) blocks, $(wc -l < $W/Big/big.bs) lines)"
    ERL_LIBS=/tmp/otp/lib/elixir/lib escript "$HERE/time.escript" $W 2>&1 | grep -v Warning
  done
done
