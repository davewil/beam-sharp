#!/usr/bin/env bash
# Probe 65/03: what does Gleam do when user code takes a name the compiler's PRELUDE owns,
# or a module name the compiler/stdlib owns? Dependency-free projects only (Hex is blocked
# here), so `gleam/*` stdlib modules are NOT available: every claim below is about the
# prelude (types Bool Int Float String List Result Nil BitArray, constructors Ok Error True ...)
# and about module names, not about gleam_stdlib.
set -u
G="${GLEAM:-/tmp/claude-0/gleamx/gleam}"
$G --version
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

# variant NAME 'file1:content' ...  -- builds a fresh project, prints compile output.
mk() { # $1 name ; then pairs of path and content via heredoc function bodies
  local d="$T/$1"; mkdir -p "$d/src"; printf 'name = "p"\nversion = "1.0.0"\n' > "$d/gleam.toml"; echo "$d"; }
run() { # $1 dir
  (cd "$1" && "$G" build 2>&1 | grep -v 'Resolving versions' | sed 's/^/    > /'; echo "    exit=${PIPESTATUS[0]}"); }

echo "=== V1: user type named Result shadows the prelude's Result"
d=$(mk v1); cat > $d/src/p.gleam <<'EOS'
pub type Result(a, e) { Good(a) Bad(e) }
pub fn main() -> Result(Int, String) { Good(1) }
EOS
sed 's/^/    | /' $d/src/p.gleam; run $d

echo "=== V2: user CONSTRUCTOR named Ok (prelude constructor), then use it"
d=$(mk v2); cat > $d/src/p.gleam <<'EOS'
pub type T { Ok(Int) }
pub fn main() { Ok(1) }
EOS
sed 's/^/    | /' $d/src/p.gleam; run $d

echo "=== V3: user type named List"
d=$(mk v3); cat > $d/src/p.gleam <<'EOS'
pub type List { Cons(Int, List) Empty }
pub fn main() -> List { Cons(1, Empty) }
EOS
sed 's/^/    | /' $d/src/p.gleam; run $d

echo "=== V4: user type named Bool with constructors True/False redefined"
d=$(mk v4); cat > $d/src/p.gleam <<'EOS'
pub type Bool { True False Maybe }
pub fn main() -> Bool { Maybe }
EOS
sed 's/^/    | /' $d/src/p.gleam; run $d

echo "=== V5: a module file named gleam.gleam (the prelude's own module name)"
d=$(mk v5); echo 'pub fn f() { 1 }' > $d/src/gleam.gleam; echo 'pub fn main() { 1 }' > $d/src/p.gleam
echo "    | src/gleam.gleam: pub fn f() { 1 }"; run $d

echo "=== V6: a local module named list (what a stdlib user would import as gleam/list's last segment)"
d=$(mk v6); echo 'pub fn sum(xs: List(Int)) -> Int { case xs { [] -> 0 [h, ..t] -> h + sum(t) } }' > $d/src/list.gleam
printf 'import list\npub fn main() { list.sum([1,2,3]) }\n' > $d/src/p.gleam
echo "    | src/list.gleam defines sum; src/p.gleam does 'import list'"; run $d

echo "=== V7: a module at src/gleam/list.gleam (the stdlib's path, with the stdlib NOT present)"
d=$(mk v7); mkdir -p $d/src/gleam; echo 'pub fn f() { 1 }' > $d/src/gleam/list.gleam; echo 'pub fn main() { 1 }' > $d/src/p.gleam
run $d

echo "=== V8: the compiler binary's own reserved-name messages (no source tree installed; this is the binary's strings)"
strings -a "$G" | grep -ao 'is a reserved word in Erlang\.\|is a standard library module in Erlang\.\|is a reserved word in Gleam\.\|is a reserved module name in Gleam\.\|has the reserved prefix `gleam_`' | sort -u | sed 's/^/    /'
echo "=== V9: a module named like an Erlang stdlib module (lists), to see which of the two reservations fires"
d=$(mk v9); echo 'pub fn f() { 1 }' > $d/src/lists.gleam; echo 'pub fn main() { 1 }' > $d/src/p.gleam; run $d
echo "=== V10: a module named string (also an Erlang stdlib module)"
d=$(mk v10); echo 'pub fn f() { 1 }' > $d/src/string.gleam; echo 'pub fn main() { 1 }' > $d/src/p.gleam; run $d
