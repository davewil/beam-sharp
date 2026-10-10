#!/usr/bin/env bash
# Gleam: negative literal patterns; guards with -5, 2+3, -{2}, a module constant; each snippet its own module.
source /tmp/claude-0/env.sh
W=$(mktemp -d); cd $W
gleam new probe --skip-git --skip-github >/dev/null 2>&1; cd probe
printf 'name = "probe"\nversion = "1.0.0"\ntarget = "erlang"\n' > gleam.toml
rm -f manifest.toml test/*.gleam src/probe.gleam
snip() { # label body
  rm -f src/*.gleam; printf '%s\n' "$2" > src/probe.gleam
  out=$(gleam build 2>&1); printf '== %s rc=%s\n%s\n' "$1" $? "$(echo "$out" | grep -v Resolving | grep -v Compiling | head -9)"
}
snip 'G-a pattern -1' 'pub fn a(x: Int) -> String {
  case x { -1 -> "neg1"  0 -> "zero"  _ -> "other" }
}'
snip 'G-b guard n >= -5' 'pub fn b(x: Int) -> String {
  case x { n if n >= -5 -> "ge"  _ -> "lt" }
}'
snip 'G-c guard n >= 2 + 3 (arithmetic in a guard)' 'pub fn c(x: Int) -> String {
  case x { n if n >= 2 + 3 -> "ge5"  _ -> "lt" }
}'
snip 'G-d guard n >= -{ 2 } (negation of a non-literal)' 'pub fn d(x: Int) -> String {
  case x { n if n >= -{ 2 } -> "ge"  _ -> "lt" }
}'
snip 'G-e guard against a module constant -5' 'pub const k = -5
pub fn e(x: Int) -> String {
  case x { n if n >= k -> "ge"  _ -> "lt" }
}'
snip 'G-f guard n >= - 5 (space)' 'pub fn f(x: Int) -> String {
  case x { n if n >= - 5 -> "ge"  _ -> "lt" }
}'
snip 'G-g exhaustiveness: Int guards never credited (control: needs a catch-all)' 'pub fn g(x: Int) -> String {
  case x { n if n >= 0 -> "ge"  n if n < 0 -> "lt" }
}'
