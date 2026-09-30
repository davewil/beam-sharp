#!/usr/bin/env bash
# 57h: Gleam 1.12.0 and Elm 0.19.1 - negative literal in pattern, guard, expression. Compile-only.
# Gleam/Elm have no refinement types, so the question is only whether `-5` is a literal in each position.
G=/tmp/tools/gleam; E=/tmp/tools/elm
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
echo "=== gleam: $($G --version) ==="
cd "$d" && mkdir -p g/src && cd g
cat > gleam.toml <<'T'
name = "p57h"
version = "1.0.0"
T
cat > src/p57h.gleam <<'G'
pub fn f(x: Int) -> Int {
  case x {
    -5 -> 1
    n if n >= -5 -> 2
    _ -> 3
  }
}

pub fn lit() -> Int { -5 }
pub fn sum() -> Int { -5 + 2 }
pub fn bad(x: Int) -> Int {
  case x {
    n if n >= 2 + 3 -> 1
    _ -> 0
  }
}
G
"$G" build 2>&1 | head -30
echo "--- same file without the function named bad (is the rest accepted?)"
python3 - <<'PY'
s=open('src/p57h.gleam').read(); s=s[:s.index('pub fn bad')]; open('src/p57h.gleam','w').write(s)
PY
"$G" build 2>&1 | tail -4; echo "rc=$?"
echo "=== elm: $($E --version) ==="
echo "elm 0.19.1 needs elm/core and elm/json in ~/.elm/0.19.1/packages; only the lock file is present (no package cache)."
echo "Two attempts (elm/core only; then without) both stopped at MISSING DEPENDENCY. Elm: NOT PROBED (and it has no refinement types)."
