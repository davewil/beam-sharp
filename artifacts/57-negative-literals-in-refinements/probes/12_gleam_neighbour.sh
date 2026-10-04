#!/usr/bin/env bash
# Gleam 1.12.0 (tickets measured 1.18.1). Negative literal in a pattern, guard, and arithmetic in a pattern/guard.
export PATH=/opt/otp28/bin:$PATH
G=/tmp/tc/gleam
d=$(mktemp -d); trap 'rm -rf $d' EXIT; cd $d
mkdir -p t && cd t
cat > gleam.toml <<'T'
name = "t"
version = "1.0.0"
T
mkdir -p src
cat > src/t.gleam <<'GL'
pub fn p(x: Int) -> String {
  case x {
    -5 -> "m5"
    _ -> "o"
  }
}
pub fn g(x: Int) -> String {
  case x {
    n if n >= -5 -> "ge"
    _ -> "lt"
  }
}
pub fn q(x: Int) -> String {
  case x {
    n if n >= 2 + 3 -> "ge5"
    _ -> "lt"
  }
}
GL
echo "== -5 in pattern, -5 in guard, 2+3 in guard"
$G build --target erlang 2>&1 | tail -15
echo "== generated Erlang"
f=$(find build -name 't.erl' | head -1); cat "$f"
echo "== arithmetic in a PATTERN"
cat > src/t.gleam <<'GL'
pub fn s(x: Int) -> String {
  case x {
    2 + 3 -> "five"
    _ -> "o"
  }
}
GL
$G build --target erlang 2>&1 | tail -15
