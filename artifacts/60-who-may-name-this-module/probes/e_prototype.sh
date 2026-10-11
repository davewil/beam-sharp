#!/usr/bin/env bash
# Probe (e): the checker delta, prototyped in SCRATCH COPIES of compiler/src (never the real tree).
# Variants are built by ./e_build_variants.sh into $PROTO (default: scratchpad/60/proto).
# One command: ./e_prototype.sh
source ${BS_ENV:-/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh}
HERE=$(cd "$(dirname "$0")" && pwd)
PROTO=${PROTO:-/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/60/proto}
run() { local v=$1; shift; (cd "$1" && shift && BSC_EBIN=$PROTO/ebin_$v "$HERE/bsc2" -o $(mktemp -d) --src-root . "$@" 2>&1 | grep -v 'Warning: function'); }
echo "################ VARIANT A: callee lists friends (module-level 'friend Shop.Reports')"
P=$HERE/proj_e; cat $P/Shop/Orders/Friends.bs | tail -1
for t in "Shop/Reports:listed friend (expect clean)" "Other:using Shop.Orders from an unlisted module" "Ns:namespace 'using Shop' then Orders.RecomputeTotal" "Ty:type position, Shop.Orders reachable transitively" "TyNs:type position through a namespace import"; do
  echo "--- ${t%%:*}  [${t#*:}]"; run A $P ${t%%:*}; done
echo "--- CONTROL: the same programs under the UNMODIFIED compiler, friend file removed (all must compile clean)"
rm -rf $HERE/.ctlA; cp -r $P $HERE/.ctlA; rm $HERE/.ctlA/Shop/Orders/Friends.bs
for t in Other Ns Ty TyNs; do echo "--- base $t"; run base $HERE/.ctlA $t; done; rm -rf $HERE/.ctlA
echo
echo "################ VARIANT B: path convention, an 'Internal' segment (no new syntax)"
P=$HERE/proj_b
for t in "Shop/Orders:parent (expect clean)" "Shop/Orders/Total:descendant of the parent (expect clean)" "Shop/Reports:sibling subtree (expect error)" "NsB:namespace using Shop.Orders.Internal from outside"; do
  echo "--- ${t%%:*}  [${t#*:}]"; run B $P ${t%%:*}; done
echo "--- CONTROL: same Shop/Reports under the UNMODIFIED compiler"
run base $P Shop/Reports
echo
echo "################ VARIANT C: callbacks are unnameable by other modules (no new syntax, uses the behaviour table)"
P=$HERE/proj_f
echo "--- CartTest2 names callback HandleCall"; run C $P CartTest2
echo "--- CartTest names private Recompute (unchanged F12 diagnostic)"; run C $P CartTest
echo "--- Cart itself still compiles and runs its client API"; run C $P Cart; (cd $P && BSC_EBIN=$PROTO/ebin_C "$HERE/bsc2" -o $(mktemp -d) --src-root . Cart Total 6 2>&1)
echo "--- CONTROL: CartTest2 under the UNMODIFIED compiler"; run base $P CartTest2 TestsCallback 7
