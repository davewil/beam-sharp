#!/usr/bin/env bash
# Behavioural probe: what Gleam accepts for negative / arithmetic constants in patterns, guards and constants.
export PATH=$HOME/.nix-profile/bin:$PATH
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; cd "$W"
t() { # name, body
  mkdir -p "p_$1/src" && cd "p_$1"
  printf 'name = "p"\nversion = "1.0.0"\n[dependencies]\n' > gleam.toml
  printf '%s\n' "$2" > src/p.gleam
  printf '%-34s ' "$1"; out=$(gleam check 2>&1); rc=$?; [ $rc -eq 0 ] && echo ok || echo "REFUSED: $(echo "$out" | grep -m1 -E '^error|^ *error' )"; echo "$out" | grep -A6 -m1 '^error' | sed 's/^/      /' | head -8 | grep -v '^\s*$' >/dev/null; cd ..
}
t pattern_neg_lit      'pub fn f(x: Int) { case x { -5 -> 1 _ -> 0 } }'
t guard_gte_neg_lit    'pub fn f(x: Int) { case x { n if n >= -5 -> 1 _ -> 0 } }'
t guard_arith_const    'pub fn f(x: Int) { case x { n if n >= 2 + 3 -> 1 _ -> 0 } }'
t guard_neg_neg        'pub fn f(x: Int) { case x { n if n >= - -5 -> 1 _ -> 0 } }'
t guard_sub_const      'pub fn f(x: Int) { case x { n if n >= 0 - 5 -> 1 _ -> 0 } }'
t pattern_arith        'pub fn f(x: Int) { case x { 2 + 3 -> 1 _ -> 0 } }'
t const_neg            'const lo = -5
pub fn f(x: Int) { case x { n if n >= lo -> 1 _ -> 0 } }'
t const_arith          'const lo = 2 + 3
pub fn f(x: Int) { x + lo }'
