#!/usr/bin/env bash
# P11: option 2 as a PROTOTYPE (probes/opt2-patch/*.diff on a COPY of the compiler; the repo is untouched):
# standard operations are spelled Std.List.Sum(...); `Std` and `Std.*` are the one burned prefix. User `module List` is then legal.
# Control: the same sources under HEAD bsc (where `module List` is refused and `Std.List.Sum` is "not imported").
S=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad
export PATH=$S/beam/bin:$PATH
for V in bsc bsc-opt2; do
  D=$S/65/p11-$V; rm -rf $D; mkdir -p $D/src/List $D/src/Lib $D/src/App $D/src/Std $D/src/Old $D/out
  printf 'module List\n\npublic int Sum(list<int> xs)\nSum(xs) -> 1000\n' > $D/src/List/List.bs
  printf 'module Lib\n\npublic int Total(list<int> xs)\nTotal(xs) -> Std.List.Sum(xs)\n' > $D/src/Lib/Lib.bs
  printf 'module App\n\nusing List\nusing Lib\n\npublic int Mine(list<int> xs)\nMine(xs) -> List.Sum(xs)\n\npublic int Theirs(list<int> xs)\nTheirs(xs) -> Std.List.Sum(xs)\n\npublic int Dep(list<int> xs)\nDep(xs) -> Total(xs)\n' > $D/src/App/App.bs
  printf 'module Std\n\npublic int Go(int n)\nGo(n) -> n\n' > $D/src/Std/Std.bs
  printf 'module Old\n\npublic int Go(list<int> xs)\nGo(xs) -> List.Sum(xs)\n' > $D/src/Old/Old.bs
  for q in "App Mine [1,2,3]" "App Theirs [1,2,3]" "App Dep [1,2,3]" "Std Go 1" "Old Go [1,2,3]"; do
    set -- $q; echo "######## $V: $q"; $S/$V --src-root $D/src $D/src/$1 $2 "$3" 2>&1 | sed "s#$S/65/##" | head -6
  done
done
