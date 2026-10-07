#!/usr/bin/env bash
# Side finding: `value == K` in a refinement fails even for K=3 (non-negative), with "bad range type" at line 0.
BSC=${BSC:-/home/user/beam-sharp/compiler/_build/default/bin/bsc}
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; cd "$W"; mkdir M
for p in 'value == 3' 'value >= 3 and value <= 3' 'value != 3'; do
  printf 'module M\n\ntype T = int where %s\n\npublic int F(T x)\n\nF(x) -> 1\n' "$p" > M/m.bs
  echo "[$p]"; "$BSC" M 2>&1 | head -3; echo "rc=${PIPESTATUS[0]}"
done
