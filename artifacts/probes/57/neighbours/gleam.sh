#!/usr/bin/env bash
# gleam.sh -- Gleam 1.18.1: the real compiler on `-5` / arithmetic in each position.
# Gleam's parser is Rust inside the binary (no grammar file installed), so this is a
# behavioural probe: one snippet per module, accepted or refused, with the first error.
export PATH=/tmp/otp/bin:$PATH
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
cd "$work" && gleam new probe --skip-git --skip-github >/dev/null 2>&1 && cd probe
python3 - <<'PY'
s=open('gleam.toml').read().split('[dependencies]')[0]+'[dependencies]\n'
open('gleam.toml','w').write(s)
PY
rm -rf test
gleam --version
try () {  # try LABEL BODY
  printf '%s\n' "$2" > src/probe.gleam
  if out=$(gleam build 2>&1); then printf 'ACCEPTED  %s\n' "$1"; else
    printf 'REFUSED   %-52s %s\n' "$1" "$(printf '%s' "$out" | grep -E '^error|expected|not expecting|Found|cannot|Unexpected' | head -3 | tr '\n' ' ')"; fi
}
try 'pattern  case x { -5 -> ..}'                'pub fn f(x: Int) { case x { -5 -> 1  _ -> 0 } }'
try 'pattern  case x { - 5 -> ..} (space)'       'pub fn f(x: Int) { case x { - 5 -> 1  _ -> 0 } }'
try 'pattern  case x { 2 + 3 -> ..}'             'pub fn f(x: Int) { case x { 2 + 3 -> 1  _ -> 0 } }'
try 'pattern  case x { -(5) -> ..}'              'pub fn f(x: Int) { case x { -(5) -> 1  _ -> 0 } }'
try 'pattern  tuple #(-1, b)'                    'pub fn f(p: #(Int, Int)) { case p { #(-1, b) -> b  #(a, _) -> a } }'
try 'guard    n if n >= -5'                      'pub fn f(x: Int) { case x { n if n >= -5 -> 1  _ -> 0 } }'
try 'guard    n if n >= 2 + 3'                   'pub fn f(x: Int) { case x { n if n >= 2 + 3 -> 1  _ -> 0 } }'
try 'guard    n if n >= -y (unary minus on name)' 'pub fn f(x: Int, y: Int) { case x { n if n >= -y -> 1  _ -> 0 } }'
try 'const    const lo = -5'                     'pub const lo = -5'
try 'const    const s = 2 + 3'                   'pub const s = 2 + 3'
try 'const    const lo = - 5 (space)'            'pub const lo = - 5'
try 'const    const lo = --5'                    'pub const lo = --5'
try 'const    const lo = -(5)'                   'pub const lo = -(5)'
try 'expr     let a = -5'                        'pub fn f() { let a = -5  a }'
try 'expr     let a = - -5'                      'pub fn f() { let a = - -5  a }'
try 'expr     let a = 0 - 5'                     'pub fn f() { let a = 0 - 5  a }'
try 'pattern  -5.0 float pattern'                'pub fn f(x: Float) { case x { -5.0 -> 1  _ -> 0 } }'
try 'bit-array pattern <<-1>>'                   'pub fn f(x: BitArray) { case x { <<-1>> -> 1  _ -> 0 } }'
