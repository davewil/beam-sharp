#!/usr/bin/env bash
# Probe 59e: .beam / Code-chunk byte cost of the tag test and kind test, exported vs private, by field count.
# Same source, different emitter: base (tests as shipped) vs C (no tag test anywhere) / D (no kind test anywhere) /
# A (tag exported-only) / B (kind also on private).
here=$(cd "$(dirname "$0")" && pwd); . "$here/../lib.sh"
work=$here/size_work; rm -rf "$work"; mkdir -p "$work"
EB=(base:/tmp/bsbuild/ebin A:/tmp/bsb_59_a/ebin B:/tmp/bsb_59_b/ebin C:/tmp/bsb_59_c/ebin D:/tmp/bsb_59_d/ebin)
gen_rec() { # N fields, vis -> module
  local n=$1 vis=$2 fields="" i; for ((i=1;i<=n;i++)); do fields+="F$i: int, "; done; fields=${fields%, }
  printf 'module R%s%s\n\nrecord Rec { %s }\n\n' "$vis" "$n" "$fields"
  if [ "$vis" = pub ]; then printf 'public int Get(Rec r)\nGet(r) -> r.F1\n'
  else printf 'private int Get(Rec r)\nGet(r) -> r.F1\n\npublic list<int> All(list<Rec> xs)\nAll(xs) -> List.Map(xs, Get/1)\n'; fi
}
gen_int() { # vis
  if [ "$1" = pub ]; then printf 'module Ipub\n\npublic int Get(int n)\nGet(n) -> n * 2\n'
  else printf 'module Ipriv\n\nprivate int Get(int n)\nGet(n) -> n * 2\n\npublic list<int> All(list<int> xs)\nAll(xs) -> List.Map(xs, Get/1)\n'; fi
}
gen_pass() { printf 'module Ipass\n\npublic int Outer(int n)\nOuter(n) -> Get(n) + 1\n\nprivate int Get(int n)\nGet(n) -> n * 2\n'; }
build() { # name srcfile emitter-label
  local name=$1 src=$2 lab=$3 e=""; for x in "${EB[@]}"; do [ "${x%%:*}" = "$lab" ] && e=${x#*:}; done
  mkdir -p "$work/$name/$lab/src/$name" "$work/$name/$lab/out"
  cp "$src" "$work/$name/$lab/src/$name/$(echo $name | tr A-Z a-z).bs"
  (cd "$work/$name/$lab/src" && BSC_EBIN=$e bsc -o ../out "$name/$(echo $name | tr A-Z a-z).bs" 2>&1 | grep -v -i warning)
}
code_bytes() { erl -noshell -eval '{ok,{_,[{"Code",C}]}}=beam_lib:chunks("'$1'",["Code"]), io:format("~w",[byte_size(C)]), halt().'; }
file_bytes() { stat -c %s "$1"; }
row() { # name labels...
  local name=$1; shift; local out="" lab
  for lab in "$@"; do build $name "$work/$name.bs" $lab; b=$work/$name/$lab/out/$name.beam
    out+=" $lab=$(file_bytes $b)/$(code_bytes $b)"; done; printf '%-9s%s\n' "$name" "$out"
}
echo "# columns: emitter=<.beam file bytes>/<Code chunk bytes>"
for n in 1 3 8 16; do for vis in pub priv; do nm=R$vis$n; gen_rec $n $vis > "$work/$nm.bs"; row $nm base C A; done; done
gen_int pub  > "$work/Ipub.bs";  row Ipub  base D B
gen_int priv > "$work/Ipriv.bs"; row Ipriv base D B
gen_pass     > "$work/Ipass.bs"; row Ipass base D B
