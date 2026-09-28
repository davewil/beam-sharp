#!/bin/sh
# p05_dialyzer -- how Dialyzer (the BEAM's own static checker) treats local vs exported functions.
# LABEL: MEASURED (real dialyzer 5.0.5 on hand-written Erlang; the modules are analogues of the shapes bs_emit emits).
# PREDICTIONS (before the first run):
#   D1. forge_local (a wrongly-tagged literal passed to local p/1 inside d1) is reported: a spec on a private
#       function is checked against its call sites, exactly as for an exported one.
#   D2. d2:go/0 (forged literal into exported d1:e/1) is reported only when d1 and d2 are analysed together.
#   D3. d2:go_untyped/1 (value from binary_to_term) is NOT reported: Dialyzer is blind to untyped channels.
#       Nothing in d1 is reported for the nested (w/1) or escaped (esc/0) paths either.
#   D4. d3: local_plus(foo) is reported ("will never return") because a local function's callers are all known
#       (closed world); exported_plus(foo) is NOT reported (open world: some other module could call it right).
#       escaped_plus(foo): expected NOT reported, because taking the address of a local function reopens the world.
cd "$(dirname "$0")" || exit 1
mkdir -p work/dial && cd work/dial || exit 1
PLT=$PWD/min.plt
echo "== building a minimal PLT (erts, kernel, stdlib) from the apt-installed OTP; no network =="
dialyzer --build_plt --output_plt "$PLT" --apps erts kernel stdlib > plt.log 2>&1; echo "plt exit: $?"
tail -2 plt.log
erlc +debug_info -o . ../../dsrc/d1.erl ../../dsrc/d2.erl ../../dsrc/d3.erl
echo
echo "== D1/D3-nested/esc: d1 alone =="
dialyzer --plt "$PLT" -Wno_unused d1.beam 2>&1 | sed 's/^/  /'
echo
echo "== D2/D3: d1 + d2 together =="
dialyzer --plt "$PLT" d1.beam d2.beam 2>&1 | sed 's/^/  /'
echo
echo "== D4: d3 alone (exported vs local vs escaped local, all called with an atom) =="
dialyzer --plt "$PLT" d3.beam 2>&1 | sed 's/^/  /'
