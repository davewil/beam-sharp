#!/usr/bin/env bash
# Byte cost of the guards: .beam size of the SAME program compiled by
#   base   = the repo's bsc
#   narrow = prototype, tag test only on exported fns (59-04/narrow.patch)
#   widen  = prototype, int/float kind test also on private fns (59-04/widen.patch)
# Fixture (a): N private fns taking a 2-field record, N taking a 12-field record, N private int fns, N private float fns, all called with a value erlc can prove.
# Fixture (b): N private int + N private float fns called with record-field projections (unprovable).
set -u; HERE="$(cd "$(dirname "$0")" && pwd)"; . "$HERE/../59-common.sh"
W=$(mktemp -d); N=20
"$HERE/make_variant.sh" $W/narrow narrow >/dev/null 2>&1; "$HERE/make_variant.sh" $W/widen widen >/dev/null 2>&1
mkdir -p $W/src/M; F=$W/src/M/m.bs
{ echo "module M"; echo "record Small { A: int, B: int }"
  echo -n "record Big { "; for i in $(seq 1 11); do echo -n "F$i: int, "; done; echo "F12: int }"
  for i in $(seq 1 $N); do echo "int S$i(Small s)"; echo "S$i(s) -> s.A"; echo "int G$i(Big s)"; echo "G$i(s) -> s.F1"
     echo "int I$i(int n)"; echo "I$i(n) -> n + $i"; echo "float L$i(float x)"; echo "L$i(x) -> x"; done
  # every private fn is reachable from an exported one, else erlc drops it as unused
  # P*/Q*: private int/float fns fed from a record FIELD projection, which erlc cannot type-prove
  echo "record Pair { A: int, X: float }"
  for i in $(seq 1 $N); do echo "int P$i(int n)"; echo "P$i(n) -> n + $i"; echo "float Q$i(float x)"; echo "Q$i(x) -> x"; done
  echo "public int KeepP(Pair p)"; echo -n "KeepP(p) -> 0"; for i in $(seq 1 $N); do echo -n " + P$i(p.A)"; done; echo
  echo "public float KeepQ(Pair p)"; echo -n "KeepQ(p) -> 0.0"; for i in $(seq 1 $N); do echo -n " + Q$i(p.X)"; done; echo
  echo "public int KeepS(Small s)"; echo -n "KeepS(s) -> 0"; for i in $(seq 1 $N); do echo -n " + S$i(s)"; done; echo
  echo "public int KeepG(Big s)";   echo -n "KeepG(s) -> 0"; for i in $(seq 1 $N); do echo -n " + G$i(s)"; done; echo
  echo "public int KeepI(int n)";   echo -n "KeepI(n) -> 0"; for i in $(seq 1 $N); do echo -n " + I$i(n)"; done; echo
  echo "public float KeepL(float x)"; echo -n "KeepL(x) -> 0.0"; for i in $(seq 1 $N); do echo -n " + L$i(x)"; done; echo
} > $F
erlc -o $W "$HERE/sizes.erl"
for v in base narrow widen; do
  case $v in base) b="$BSC";; *) b="$W/$v/_build/default/bin/bsc";; esac
  "$b" -o $W/out-$v --src-root $W/src $W/src/M >/dev/null 2>&1 || { echo "$v: compile failed"; "$b" -o $W/out-$v --src-root $W/src $W/src/M 2>&1|head -5; }
  erl -noshell -pa $W -eval 'sizes:main(["'$v'","'$W/out-$v/M.beam'"]).'
  erl -noshell -pa $W -eval 'io:format("   ops: ~p~n",[sizes:ops("'$W/out-$v/M.beam'")]),halt().'
done
echo "(N=$N private fns of each kind; Keep* are the exported callers)"
echo "=== compile time, 7 runs each, ms (escript boot dominates) ==="
for v in base narrow widen; do
  case $v in base) b="$BSC";; *) b="$W/$v/_build/default/bin/bsc";; esac
  ts=(); for r in 1 2 3 4 5 6 7; do s=$(date +%s%N); "$b" -o $W/o --src-root $W/src $W/src/M >/dev/null 2>&1; e=$(date +%s%N); ts+=($(( (e-s)/1000000 ))); done
  sorted=($(printf '%s\n' "${ts[@]}" | sort -n)); echo "$v min=${sorted[0]} median=${sorted[3]} max=${sorted[6]}"
done
