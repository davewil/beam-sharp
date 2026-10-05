#!/usr/bin/env bash
# MEASUREMENTS: (1) checker/emitter/parser LOC each patch changes (code lines only: blanks and
# `%%` comment lines excluded); (2) compile-time over the repo's own corpus, base vs each patch,
# median of 15 interleaved `bsc --batch` runs; (3) whether every example still compiles and prints the same.
# REFUTED (that the rule is "cheap": < 20 net code lines at the checker) IF the counts below exceed it;
# the threshold is stated before the run and is not adjusted afterwards. Timing claim "no measurable
# delta" is REFUTED IF a patched median differs from base by more than 5% AND the base's own
# min-max spread is smaller than that difference.
. "$(dirname "$0")/lib.sh"
python3 - "$HERE/patches" <<'PY'
import sys,re,os
d=sys.argv[1]
for v in 'ABC':
    cur=None; per={}
    for line in open(f'{d}/{v}.patch'):
        if line.startswith('+++ '): cur=line.split()[1][2:]; per.setdefault(cur,[0,0]); continue
        if line.startswith('--- ') or line.startswith('@@') or cur is None: continue
        if line[0] in '+-':
            t=line[1:].strip()
            if not t or t.startswith('%') or t.startswith('//'): continue
            per[cur][0 if line[0]=='+' else 1]+=1
    tot=[sum(x[0] for x in per.values()), sum(x[1] for x in per.values())]
    print(f'patch {v}: code lines +{tot[0]} -{tot[1]}')
    for f,(a,b) in per.items(): print(f'    {f}: +{a} -{b}')
# the rule-specific block of A (everything else in A is the shared "who may name" machinery + diagnostic)
txt=open(f'{d}/A.patch').read()
m=re.search(r'\+%% A module whose path has.*?\+%% `Self` is', txt, re.S)
rule=[l for l in m.group(0).splitlines() if l.startswith('+') and l[1:].strip() and not l[1:].strip().startswith('%')]
print(f'A: rule-specific code lines (visibility/internal_parent): {len(rule)}')
txt=open(f'{d}/B.patch').read()
m=re.search(r'\+%% The callee.s own `visible_to` list.*?\+%% `Self` is', txt, re.S)
rule=[l for l in m.group(0).splitlines() if l.startswith('+') and l[1:].strip() and not l[1:].strip().startswith('%')]
print(f'B: rule-specific code lines at the check (visibility/visible_to_of/export): {len(rule)}')
print('(net code lines in bs_check.erl alone are the number to compare with the 20-line threshold in this file\'s header)')
PY
echo
CORPUS="$REPO/compiler/examples"
for v in base pA pB pC; do
  case $v in base) p="";; pA) p=A.patch;; pB) p=B.patch;; pC) p=C.patch;; esac
  build_variant $v $p >/dev/null || exit 1
done
# manifest exactly as bin/check-examples.sh builds it
mk_manifest() { # variant -> manifest path
  local v="$1" w="$WORK/p12_$1"; rm -rf "${w:?}"; mkdir -p "$w"; local n=0
  find "$CORPUS" -path "$CORPUS/exemplars" -prune -o -name '*.bs' -print0 | while IFS= read -r -d '' f; do dirname "$f"; done | sort -u > "$w/dirs"
  while IFS= read -r d; do
    n=$((n+1)); mkdir -p "$w/out$n"
    { printf 'entry e%d\n' "$n"; printf 'arg %s\n' --src-root "$CORPUS" -o "$w/out$n" "$d"; printf 'end\n\n'; } >> "$w/manifest"
  done < "$w/dirs"
  echo "$w"
}
echo "corpus modules (directories holding .bs, exemplars pruned): $(find "$CORPUS" -path "$CORPUS/exemplars" -prune -o -name '*.bs' -print0 | while IFS= read -r -d '' f; do dirname "$f"; done | sort -u | wc -l)"
declare -A W
for v in base pA pB pC; do W[$v]=$(mk_manifest $v); done
declare -A TS
# Interleaved: round r runs base, pA, pB, pC in turn, so machine drift hits every variant alike.
for r in $(seq 1 15); do
  for v in base pA pB pC; do
    w=${W[$v]}; B=$(bsc_of $v); rm -rf "$w/results"
    s=$(date +%s%N); "$B" --batch "$w/manifest" "$w/results" >"$w/batch.log" 2>&1; e=$(date +%s%N)
    TS[$v]+="$(( (e-s)/1000000 )) "
  done
done
declare -A MED
for v in base pA pB pC; do
  w=${W[$v]}
  ok=$(cat "$w"/results/*.status | sort | uniq -c | tr '\n' ' ')
  sorted=($(printf '%s\n' ${TS[$v]} | sort -n)); MED[$v]=${sorted[7]}
  echo "$v: 15 interleaved batch runs (ms): ${TS[$v]}"
  echo "    median=${sorted[7]} min=${sorted[0]} max=${sorted[14]}   exit statuses of the 27 modules: $ok"
  echo "    beams emitted: $(find "$w" -name '*.beam' | wc -l)"
done
echo
python3 - "${MED[base]}" "${MED[pA]}" "${MED[pB]}" "${MED[pC]}" "${TS[base]}" <<'PY'
import sys
b,a,bb,c=map(float,sys.argv[1:5]); base_runs=[float(x) for x in sys.argv[5].split()]
spread=max(base_runs)-min(base_runs); refuted=False
for n,v in (('A',a),('B',bb),('C',c)):
    d=v-b; print(f'median delta {n} vs base: {100*d/b:+.1f}%  ({v:.0f} ms vs {b:.0f} ms)')
    if abs(d)/b>0.05 and abs(d)>spread: refuted=True
print(f'base min-max spread: {spread:.0f} ms')
print('VERDICT[no-measurable-compile-time-delta]: ' + ('REFUTED' if refuted else 'CONFIRMED (every median delta is inside the base spread or under 5%)'))
PY
