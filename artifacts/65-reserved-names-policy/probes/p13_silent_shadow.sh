#!/usr/bin/env bash
# P13: the call-site collision 67 Q6(iii) refuses today (a namespace `using Shop` brings Shop.List in as `List`),
# with a Shop.List.Sum(xs) of the SAME arity as the standard row. HEAD refuses with a message; the option-3 prototype resolves silently.
S=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad
export PATH=$S/beam/bin:$PATH
for V in bsc bsc-opt3; do
  D=$S/65/p13-$V; rm -rf $D; mkdir -p $D/src/Shop/List $D/src/R
  printf 'module Shop.List\n\npublic int Sum(list<int> xs)\nSum(xs) -> 1000\n' > $D/src/Shop/List/List.bs
  printf 'module R\n\nusing Shop\n\npublic int Go(list<int> xs)\nGo(xs) -> List.Sum(xs)\n' > $D/src/R/R.bs
  echo "######## $V: R.Go [1,2,3]  (std List.Sum = 6; Shop.List.Sum = 1000)"; $S/$V --src-root $D/src $D/src/R Go '[1,2,3]' 2>&1 | sed "s#$S/65/##" | head -9
done
