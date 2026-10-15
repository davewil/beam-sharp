#!/usr/bin/env bash
# CLAIMS: (a) ticket 18 s5: "elision is exported-vs-local; a BEAM function has ONE entry label" -- so the guard
#   F24 emits at public functions also runs on in-module calls, and a private function has none.
#   (b) the BEAM cannot enforce "who may call": a public function of Shop.Orders.Internal is callable from an
#   outsider written in Erlang with no compiler in the loop, so any who-may-name rule is compile-time only.
#   (c) the compile-time prototype adds no bytes to the .beam (rule is check-only).
# REFUTED IF: (a) Priv/1 carries an is_integer test, or Pub/1's local callers reach a label other than its guarded
#   entry (two entry labels / a second 'Pub' function_info); (b) the erlang call below raises undef/badarg;
#   (c) the cmp of HEAD-built vs patched-built beams differs.
# CONTROL: calling the PRIVATE 'Priv'/1 from Erlang MUST fail with undef (the "what" half IS enforced by the BEAM).
. "$(dirname "$0")/env.sh"; D="$(cd "$(dirname "$0")" && pwd)"
S=$(mktemp -d /tmp/probe60beam.XXXXXX); mkdir -p $S/src/Guard $S/g $S/head $S/patched
cat > $S/src/Guard/G.bs <<'B'
module Guard

public int Pub(int n)
Pub(n) -> Priv(n) + 1

private int Priv(int n)
Priv(n) -> n * 2

public int Twice(int n)
Twice(n) -> Pub(n)
B
$BSC --src-root $S/src -o $S/g $S/src/Guard || exit 1
echo "=== (a) exports and per-function entry code"
escript "$D/60_beam_inspect.escript" disasm $S/g/Guard.beam
echo "=== (b) outsider in Erlang, no B# compiler involved"
PB=$("$D/60_build_patched.sh" | tail -1); [ -x "$PB" ] || { echo "patched build failed"; exit 1; }
mkdir -p $S/ok; cp -r "$D/60_shop/ok/." $S/ok/
( cd $S/ok && $BSC --src-root . -o $S/head Audit >/dev/null; for m in Shop/Internal Shop/Orders/Internal Shop/Orders Shop/Billing; do $BSC --src-root . -o $S/head $m >/dev/null; done
  $PB --src-root . -o $S/patched Audit >/dev/null; for m in Shop/Internal Shop/Orders/Internal Shop/Orders Shop/Billing; do $PB --src-root . -o $S/patched $m >/dev/null; done )
ls $S/head
escript "$D/60_beam_inspect.escript" call $S/head $S/g
echo "=== (c) patched vs HEAD beams"
# whole-file cmp is NOT usable: HEAD bsc is not byte-reproducible (see probe log); compare behaviour chunks instead.
mkdir -p $S/head2; ( cd $S/ok && for m in Audit Shop/Internal Shop/Orders/Internal Shop/Orders Shop/Billing; do $BSC --src-root . -o $S/head2 $m >/dev/null; done )
for f in $S/head/*.beam; do b=$(basename $f); cmp -s $f $S/head2/$b && echo "whole-file HEAD-vs-HEAD identical $b" || echo "whole-file HEAD-vs-HEAD differs $b"; done
for f in $S/head/*.beam; do b=$(basename $f); escript "$D/60_beam_inspect.escript" cmp $f $S/patched/$b; done
echo "CONTROL (must say DIFFERENT): HEAD Shop.Internal vs HEAD Shop.Orders"
escript "$D/60_beam_inspect.escript" cmp $S/head/Shop.Internal.beam $S/head/Shop.Orders.beam
