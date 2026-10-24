#!/usr/bin/env bash
# PROBE 65f — how does Gleam 1.18.1 treat a user type named like a prelude type, and a user
# module named like a reserved / stdlib one? One real project, gleam_stdlib as a path
# dependency (hex is blocked here), one variant at a time. CONTROLS: fresh names compile clean.
#
#   source env.sh; bash artifacts/probes/65/65f_gleam_shadowing.sh
set -uo pipefail
: "${REF:?source env.sh first}"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; P="$W/p"; mkdir -p "$P/src"; cd "$P"
cat > gleam.toml <<T
name = "probe"
version = "1.0.0"
target = "erlang"

[dependencies]
gleam_stdlib = { path = "$REF/stdlib" }
T
echo "gleam: $(gleam --version)   stdlib clone: $(git -C "$REF/stdlib" rev-parse --short HEAD)   compiler clone: $(git -C "$REF/gleam" rev-parse --short HEAD)"
PASS=0; FAIL=0
build() { # label wanted-exit [lines] [required-output-regex]
  rm -rf build/dev/erlang/probe 2>/dev/null
  local out rc; out="$(gleam build 2>&1)"; rc=$?
  if [ "$rc" = "$2" ] && { [ -z "${4:-}" ] || printf '%s' "$out" | grep -Eq "$4"; }; then PASS=$((PASS+1)); m="[ok]"; else FAIL=$((FAIL+1)); m="[FAILED: wanted exit $2${4:+ and output matching $4}]"; fi
  printf '== %s (exit %s) %s\n' "$1" "$rc" "$m"
  printf '%s\n' "$out" | grep -v -E '^ *(Resolving|Added|Compiling gleam_stdlib|Downloading|Compiled in)' | sed '/^$/d' | head -${3:-8} | sed 's/^/   /'
}
reset() { rm -rf src; mkdir -p src; }

reset; cat > src/probe.gleam <<'X'
pub type Result {
  Fine
}
pub type List(a) {
  Mine(a)
}
pub fn main() {
  let r: Result = Fine
  let l: List(Int) = Mine(1)
  #(r, l)
}
X
build "1. user types named Result and List (both prelude types)" 0

reset; cat > src/probe.gleam <<'X'
pub type Result {
  Fine
}
pub fn main() {
  // `Ok`/`Error` can only be the prelude's here: the user's Result has the one constructor Fine.
  echo case Ok(41) {
    Ok(x) -> x + 1
    Error(_) -> 0
  }
}
X
out="$(gleam run 2>&1)"; rc=$?
if [ "$rc" = 0 ] && printf '%s' "$out" | grep -Eq '^42$|\b42$'; then PASS=$((PASS+1)); m="[ok]"; else FAIL=$((FAIL+1)); m="[FAILED: wanted exit 0 and the value 42]"; fi
printf '== 1b. with a user Result in scope, the prelude Ok pattern-matches and RUNS to 42 (exit %s) %s\n' "$rc" "$m"
printf '%s\n' "$out" | grep -E '^[^ ].*42$|^42$|probe.gleam:[0-9]+:[0-9]+ echo|^[0-9]+$' | sed 's/^/   value printed: /' | head -3

reset; cat > src/probe.gleam <<'X'
pub type Outcome {
  Fine
}
pub fn main() {
  #(Fine, Ok(1))
}
X
build "1-control. fresh type name Outcome" 0

reset; printf 'pub fn main() { 1 }\n' > src/gleam.gleam
build "2. a user module named gleam (the prelude's module name)" 1 8 'Reserved module name'

reset; printf 'pub fn main() { 1 }\n' > src/list.gleam
build "3. a user module named list (the stdlib's is gleam/list)" 0

reset; mkdir -p src/gleam; printf 'pub fn main() { 1 }\n' > src/gleam/list.gleam
build "4. a user module named gleam/list (the stdlib's full path)" 1 12 'Duplicate module'

reset; mkdir -p src/shop; printf 'pub fn main() { 1 }\n' > src/shop/list.gleam
build "4-control. a user module named shop/list" 0

echo "--- tally: $PASS as expected, $FAIL failed"
echo "== compiler source behind 2 and 1"
grep -n 'fn validate_module_name' -A3 "$REF/gleam/compiler-core/src/analyse.rs" | sed "s#^#   compiler-core/src/analyse.rs:#"
grep -n 'pub fn is_prelude_module' -A3 "$REF/gleam/compiler-core/src/type_/prelude.rs" | sed "s#^#   compiler-core/src/type_/prelude.rs:#"
[ "$FAIL" = 0 ]
