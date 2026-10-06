#!/usr/bin/env bash
# 57d: Claim: Gleam folds neither in the grammar nor requires a literal: a negative literal in a
# pattern and in a guard both compile, and a guard comparand may be an arithmetic expression
# (so `value >= -5`, `>= 2 + 3`, `>= - -5` are all fine), but a pattern accepts only a literal.
# Controls: `-5` as a pattern must compile; `2 + 3` as a PATTERN must be refused (so the tool is able
# to say no); each case is its own project so one refusal cannot mask another.
# Gleam compiler SOURCE is not installed (only the binary): behaviour is observed, not read.
set -u
d=$(mktemp -d); cd "$d"
printf 'name = "probe"\nversion = "1.0.0"\ntarget = "erlang"\n' > gleam.toml
mkdir src
run() {  # NAME BODY
  printf '%s\n' "$2" > src/probe.gleam
  if out=$(gleam build 2>&1); then r=compiled; else r=REFUSED; fi
  printf '%-34s %s\n' "$1" "$r"
  [ "$r" = REFUSED ] && printf '%s\n' "$out" | grep -E "error|This|^ *│ +\^" | head -2 | sed 's/^/      /'
  if [ "$r" = compiled ] && [ -n "${3:-}" ]; then grep -E "$3" build/dev/erlang/probe/_gleam_artefacts/probe.erl | sed 's/^ */      erl: /'; fi
  rm -rf build
}
run "pattern -5"            'pub fn f(x: Int) { case x { -5 -> 1  _ -> 0 } }' ' -5 ->'
run "guard n >= -5"         'pub fn f(x: Int) { case x { n if n >= -5 -> 1  _ -> 0 } }' 'when'
run "guard n >= 2 + 3"      'pub fn f(x: Int) { case x { n if n >= 2 + 3 -> 1  _ -> 0 } }' 'when'
run "guard n >= - -5"       'pub fn f(x: Int) { case x { n if n >= - -5 -> 1  _ -> 0 } }' 'when'
run "guard n >= m (var)"    'pub fn f(x: Int, m: Int) { case x { n if n >= m -> 1  _ -> 0 } }' 'when'
run "CONTROL pattern 2 + 3" 'pub fn f(x: Int) { case x { 2 + 3 -> 1  _ -> 0 } }'
run "CONTROL guard bad type" 'pub fn f(x: Int) { case x { n if n >= "a" -> 1  _ -> 0 } }'
