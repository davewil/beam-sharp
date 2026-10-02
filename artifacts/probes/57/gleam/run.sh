#!/usr/bin/env bash
# Probe G: where does Gleam 1.12 accept a negative literal, and where does folding stop?
# GLEAM=/path/to/gleam (default: scratchpad binary, else `gleam` on PATH)
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
G=${GLEAM:-/tmp/claude-0/-home-user-beam-sharp/a3310f8a-c503-5acc-8cf0-37e76fb5554b/scratchpad/tc/gleam}
[ -x "$G" ] || G=gleam
w=$(mktemp -d); trap 'rm -rf "$w"' EXIT; mkdir -p "$w/src"
printf 'name = "neg"\nversion = "1.0.0"\ntarget = "erlang"\n' > "$w/gleam.toml"
fail=0
mk() { # label expect(accepted|refused) source
  printf '%s\n' "$3" > "$w/src/neg.gleam"
  if (cd "$w" && "$G" build >/dev/null 2>&1); then got=accepted; else got=refused; fi
  [ "$got" = "$2" ] || { fail=1; mark='!!'; }; printf '%-3s %-34s %s (expected %s)\n' "${mark:-ok}" "$1" "$got" "$2"; mark=
}
mk "const lo = -5"                 accepted 'const lo = -5
pub fn f() { lo }'
mk "const s = 2 + 3"               refused  'const s = 2 + 3
pub fn f() { s }'
mk "const s = -{5}"                refused  'const s = -{5}
pub fn f() { s }'
mk "pattern -1"                    accepted 'pub fn f(n: Int) { case n { -1 -> 1  _ -> 0 } }'
mk "pattern -{1}"                  refused  'pub fn f(n: Int) { case n { -{1} -> 1  _ -> 0 } }'
mk "pattern 2 + 3"                 refused  'pub fn f(n: Int) { case n { 2 + 3 -> 1  _ -> 0 } }'
mk "guard x >= -5"                 accepted 'pub fn f(n: Int) { case n { x if x >= -5 -> 1  _ -> 0 } }'
mk "guard x >= -{5}"               refused  'pub fn f(n: Int) { case n { x if x >= -{5} -> 1  _ -> 0 } }'
mk "guard x >= 2 + 3"              accepted 'pub fn f(n: Int) { case n { x if x >= 2 + 3 -> 1  _ -> 0 } }'
mk "guard x >= named const (-5)"   accepted 'const lo = -5
pub fn f(n: Int) { case n { x if x >= lo -> 1  _ -> 0 } }'
mk "expr n - -5"                   accepted 'pub fn f(n: Int) { n - -5 }'
# the emitted Erlang keeps -5 as a literal and 2 + 3 as an operation
cat > "$w/src/neg.gleam" <<'EOS'
pub fn lit() -> Int { -5 }
pub fn arith() -> Int { 2 + 3 }
pub fn negate(n: Int) -> Int { -n }
EOS
(cd "$w" && "$G" build >/dev/null 2>&1)
sed -n '/^lit()/,$p' "$w"/build/dev/erlang/neg/_gleam_artefacts/neg.erl | grep -v '^$' | grep -v '^-spec\|^-file'
grep -q '^    -5\.' "$w"/build/dev/erlang/neg/_gleam_artefacts/neg.erl || fail=1
grep -q '^    2 + 3\.' "$w"/build/dev/erlang/neg/_gleam_artefacts/neg.erl || fail=1
exit $fail
