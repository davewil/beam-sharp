#!/usr/bin/env bash
# p05 -- bytes of beam Code per guard, per private function, re-measured (ticket: +14 B tag, +3-5 B int).
# One tiny module per case; a private function reached from an exported one through a list element, so
# the caller proves nothing (this is the case where a guard has any reason to exist).
# Delta = Code-chunk bytes (variant) - (base).  tag: base - a.   int/float/range: b - base.
# REFUTES "+14 B flat in field count" if the tag delta differs between the 1-, 3- and 8-field records.
# REFUTES "+3-5 B per is_integer" if the int delta falls outside 3..5 (range test is reported separately).
. "$(dirname "$0")/lib.sh"; cd "$HERE"
G="$OUT/p05/src"; rm -rf "$OUT/p05"; mkdir -p "$G"
mk() { # name  decl-lines  entry-type  get-sig  get-clauses
  mkdir -p "$G/$1"; printf 'module %s\n%s\npublic int Entry(%s xs)\nEntry([x, ..r]) -> Get(x)\nEntry([]) -> 0\nprivate int Get(%s)\n%s\n' \
    "$1" "$2" "$3" "$4" "$5" > "$G/$1/m.bs"; }
mk Rec1 'record R { A: int }'                                              'list<R>'     'R r'   'Get(r) -> r.A'
mk Rec3 'record R { A: int, B: int, C: int }'                              'list<R>'     'R r'   'Get(r) -> r.A'
mk Rec8 'record R { A: int, B: int, C: int, D: int, E: int, F: int, G: int, H: int }' 'list<R>' 'R r' 'Get(r) -> r.A'
mk IntP ''                                                                 'list<int>'   'int n' 'Get(n) -> n * 2'
mk Fltp ''                                                                 'list<float>' 'float f' 'Get(f) -> 1'
mk Octt 'type Octet = int where value >= 0 and value <= 255'                'list<Octet>' 'Octet o' $'Get(>= 9) -> 2\nGet(<= 8) -> 1'
printf '%-6s %8s %8s %8s %8s | %6s %6s\n' case base_code a_code b_code c_code 'tag(base-a)' 'kind(b-base)' | tee "$OUT/p05/table.txt"
for m in Rec1 Rec3 Rec8 IntP Fltp Octt; do
  for v in base a b c; do
    mkdir -p "$OUT/p05/$v/$m"; "$(bscv $v)" -o "$OUT/p05/$v/$m" "$G/$m" > "$OUT/p05/$v/$m/bsc.log" 2>&1 || { cat "$OUT/p05/$v/$m/bsc.log"; exit 1; }
    eval "$v=\$(./bytes_one.escript $OUT/p05/$v/$m/$m.beam | sed 's/code=\\([0-9]*\\).*/\\1/')"
  done
  printf '%-6s %8s %8s %8s %8s | %6s %6s\n' $m $base $a $b $c $((base-a)) $((b-base)) | tee -a "$OUT/p05/table.txt"
done
echo "## whole .beam file bytes (compressed chunks), base / a / b"
for m in Rec1 Rec3 Rec8 IntP Fltp Octt; do printf '%-6s' $m; for v in base a b; do printf ' %s=%s' $v "$(./bytes_one.escript $OUT/p05/$v/$m/$m.beam | sed 's/.*file=//')"; done; echo; done | tee "$OUT/p05/files.txt"
# assertions: tag delta flat across field counts; int delta in the ticket's 3..5 range
T1=$(awk '$1=="Rec1"{print $7}' "$OUT/p05/table.txt"); T3=$(awk '$1=="Rec3"{print $7}' "$OUT/p05/table.txt"); T8=$(awk '$1=="Rec8"{print $7}' "$OUT/p05/table.txt")
I=$(awk '$1=="IntP"{print $8}' "$OUT/p05/table.txt")
echo "tag deltas 1/3/8 fields: $T1 $T3 $T8   int delta: $I"
[ "$T1" = "$T3" ] && [ "$T3" = "$T8" ] && echo "PASS  tag delta flat in field count" || { echo "FAIL  tag delta not flat"; FAILS=$((FAILS+1)); }
[ "$T1" -ge 10 ] && [ "$T1" -le 16 ] && echo "PASS  tag delta near ticket's +14 ($T1)" || { echo "FAIL  tag delta $T1 far from +14"; FAILS=$((FAILS+1)); }
[ "$I" -ge 3 ] && [ "$I" -le 5 ] && echo "PASS  int delta within ticket's +3..5 ($I)" || { echo "FAIL  int delta $I outside +3..5"; FAILS=$((FAILS+1)); }
echo "## src/Scope: OuterRec->InnerRec (top-level pass, caller tested) and OuterInt->InnerInt (caller proved int); Code bytes"
for v in base a b c; do mkdir -p "$OUT/p05/scope_$v"; "$(bscv $v)" -o "$OUT/p05/scope_$v" src/Scope >/dev/null; echo "$v $(./bytes_one.escript $OUT/p05/scope_$v/Scope.beam)"; done | tee "$OUT/p05/scope.txt"
expect "Scope base=164"                                         "$OUT/p05/scope.txt" "^base code=164 "
expect "Scope a=152 (private tag test removed, -12)"           "$OUT/p05/scope.txt" "^a code=152 "
expect "Scope b=164 (int test elided by erlc; tag kept)"        "$OUT/p05/scope.txt" "^b code=164 "
expect "Scope c=152 (tag elided by the c pass; int by erlc)"    "$OUT/p05/scope.txt" "^c code=152 "
echo "p05 FAILS=$FAILS"; exit $FAILS
