#!/bin/sh
# emit.sh VARIANT SRCROOT MODDIR : compile to abstr+beam, dump function forms, print beam size
S=$(cd "$(dirname "$0")" && pwd); V=$1; O=$S/out_$(basename $V)_$(basename $3); rm -rf $O; mkdir -p $O
$S/$V/bsc.sh --src-root $2 -o $O $3 </dev/null 2>&1 | head -5
escript $S/dump.escript $(find $O -name '*.abstr') 2>&1
echo "BEAM_BYTES $(stat -c %s $(find $O -name '*.beam' | head -1))"
