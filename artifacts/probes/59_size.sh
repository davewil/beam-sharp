#!/usr/bin/env bash
# 59_size.sh -- byte cost of the tag test and the int test on the emitted .beam, B#-emitted.
# Claims tested (tickets 26a / 18 / 59): tag test +14 B flat in field count; is_integer +3-5 B.
# Method: ONE generated module (K=8 functions of each kind) compiled under four compilers that
# differ ONLY in guard scope (HEAD, EXP, ALL, NOTAG); the Code-chunk delta between two variants
# is exactly the guards that differ, divided by how many functions differ. Module names are the
# same length in every variant (same source), compiled by the same bsc build otherwise.
# REFUTED if the per-test deltas fall outside 14 +- 2 B (tag) / 3-5 B (int).
set -u
cd "$(dirname "$0")"; . ./env.sh; . ./59_lib.sh
T=$(mktemp -d "${TMPDIR:-/tmp}/p59size.XXXXXX"); K=8
mkdir -p "$T/src/Z"
{
 echo "module Z"
 echo "record R3 { A: int, B: int, C: int }"
 echo "record R8 { A: int, B: int, C: int, D: int, E: int, F: int, G: int, H: int }"
 for i in $(seq 1 $K); do
  echo "int PrivR3_$i(R3 r)"; echo "PrivR3_$i(r) -> r.A"
  echo "public int PubR3_$i(R3 r)"; echo "PubR3_$i(r) -> r.A"
  echo "int PrivR8_$i(R8 r)"; echo "PrivR8_$i(r) -> r.A"
  echo "public int PubR8_$i(R8 r)"; echo "PubR8_$i(r) -> r.A"
  echo "int PrivI_$i(int n)"; echo "PrivI_$i(n) -> n"
  echo "public int PubI_$i(int n)"; echo "PubI_$i(n) -> n"
  # keep every private alive: one exported user per private, identical in all variants
  echo "public int UseR3_$i(list<R3> xs)"; echo "UseR3_$i([x, .._]) -> PrivR3_$i(x)"; echo "UseR3_$i([]) -> 0"
  echo "public int UseR8_$i(list<R8> xs)"; echo "UseR8_$i([x, .._]) -> PrivR8_$i(x)"; echo "UseR8_$i([]) -> 0"
  echo "public int UseI_$i(list<int> xs)"; echo "UseI_$i([x, .._]) -> PrivI_$i(x)"; echo "UseI_$i([]) -> 0"
 done
} > "$T/src/Z/z.bs"
for V in HEAD EXP ALL NOTAG; do
  var=BSC_$V; mkdir -p "$T/$V"; (cd "$T/src" && "${!var}" --src-root . -o "$T/$V" Z) || exit 1
done
echo "K=$K functions per kind; sizes (bytes):"
./59_size.escript "$T/HEAD/Z.beam" "$T/EXP/Z.beam" "$T/ALL/Z.beam" "$T/NOTAG/Z.beam"
echo; echo "emitted guards, HEAD (count of functions carrying each test):"
./59_guards.escript "$T/HEAD/Z.beam" | awk '{kind=$1; sub(/_[0-9]+\/1/,"",kind); sub(/\/1/,"",kind); k[kind" "$2" tag="$3" int="$5]++} END{for (x in k) print "  "x" x"k[x]}' | sort
python3 - "$T" $K <<'PY'
import sys,subprocess,re
T,K=sys.argv[1],int(sys.argv[2])
def code(v):
    out=subprocess.run(["./59_size.escript",f"{T}/{v}/Z.beam"],capture_output=True,text=True).stdout
    return int(re.search(r"code=(\d+)",out).group(1)), int(re.search(r"file=(\d+)",out).group(1)), int(re.search(r"instrs=(\d+)",out).group(1))
H,E,A,N=[code(v) for v in ("HEAD","EXP","ALL","NOTAG")]
print("\nDeltas (Code-chunk bytes / file bytes / instructions):")
print(f"  HEAD - EXP   = {H[0]-E[0]} / {H[1]-E[1]} / {H[2]-E[2]}   -> {2*K} private record fns lose the tag test (K R3 + K R8): {(H[0]-E[0])/(2*K):.2f} B per test")
print(f"  ALL  - HEAD  = {A[0]-H[0]} / {A[1]-H[1]} / {A[2]-H[2]}   -> {K} private int fns gain is_integer: {(A[0]-H[0])/K:.2f} B per test")
print(f"  HEAD - NOTAG = {H[0]-N[0]} / {H[1]-N[1]} / {H[2]-N[2]}   -> {4*K} tag tests (K priv+K pub, R3 and R8)")
PY

# Flat in field count? One module per record width, K private fns each, HEAD vs EXP.
for W in 3 8; do
  mkdir -p "$T/w$W/src/Y"
  { echo "module Y"; fields=$(for f in $(seq 1 $W); do printf 'F%s: int, ' $f; done); echo "record R { ${fields%, } }"
    for i in $(seq 1 $K); do echo "int P_$i(R r)"; echo "P_$i(r) -> r.F1"; echo "public int U_$i(list<R> xs)"; echo "U_$i([x, .._]) -> P_$i(x)"; echo "U_$i([]) -> 0"; done
  } > "$T/w$W/src/Y/y.bs"
  for V in HEAD EXP; do var=BSC_$V; mkdir -p "$T/w$W/$V"; (cd "$T/w$W/src" && "${!var}" --src-root . -o "$T/w$W/$V" Y) || exit 1; done
  h=$(./59_size.escript "$T/w$W/HEAD/Y.beam" | sed 's/.*code=\([0-9]*\).*/\1/'); e=$(./59_size.escript "$T/w$W/EXP/Y.beam" | sed 's/.*code=\([0-9]*\).*/\1/')
  echo "  record with $W fields: HEAD code=$h EXP code=$e delta=$((h-e)) over $K private tag tests = $(python3 -c "print(round(($h-$e)/$K,2))") B each"
done
