#!/usr/bin/env bash
# 57_gleam -- survey: negative literals in Gleam patterns, expressions, guards and constants.
# Claims: (1) `-5` is a pattern and an expression; (2) a guard `n if n >= -5` is accepted;
# (3) arithmetic over literals (`2 + 3`, `- -5`) is accepted in a guard/expression but refused in a
# pattern; (4) Gleam has no refinement types so there is no analogue of the refined-type case.
# REFUTED by: (1) or (2) refused, or `2 + 3` accepted as a pattern. Gleam is a binary here:
# no compiler source is installed, so this survey is by running programs only.
. "$(dirname "$0")/env.sh"
W=$(bs_scratch); trap 'rm -rf "$W"' EXIT
P=$W/proj; mkdir -p $P/src
printf 'name = "probe"\nversion = "1.0.0"\ntarget = "erlang"\n' > $P/gleam.toml
HDR=$'@external(erlang, "erlang", "display")\nfn show(x: a) -> b\n'
try () { # label body-of-main-and-helpers
  printf '%s\n%s\n' "$HDR" "$2" > $P/src/probe.gleam
  out=$(cd $P && gleam build 2>&1 | grep -v "^ *Compiling\|^ *Compiled\|^$" | head -${3:-4})
  if [ -z "$out" ] || ! echo "$out" | grep -q "error"; then
     run=$(cd $P && gleam run -m probe 2>&1 | grep -v "^ *Compiling\|^ *Compiled\|^ *Running\|^$" | tr '\n' ' ')
     printf '%-40s accepted ; run: %s\n' "$1" "$run"
  else printf '%-40s REFUSED\n%s\n' "$1" "$(echo "$out" | sed 's/^/      /')"; fi
}
gleam --version
try "expr  -5"                  $'pub fn main() { show(-5) }'
try "expr  - -5"                $'pub fn main() { show(- -5) }'
try "expr  5 - -5"              $'pub fn main() { show(5 - -5) }'
try "expr  -2 * 3"              $'pub fn main() { show(-2 * 3) }'
try "const lo = -5"             $'const lo = -5\npub fn main() { show(lo) }'
try "const lo = 2 + 3 (const expr)" $'const lo = 2 + 3\npub fn main() { show(lo) }'
try "pattern -5"                $'fn f(x: Int) { case x { -5 -> "m5" _ -> "other" } }\npub fn main() { show(#(f(-5), f(3))) }'
try "pattern - -5 (MUST refuse)" $'fn f(x: Int) { case x { - -5 -> "p5" _ -> "other" } }\npub fn main() { show(f(5)) }'
try "pattern 2 + 3 (MUST refuse)" $'fn f(x: Int) { case x { 2 + 3 -> "five" _ -> "other" } }\npub fn main() { show(f(5)) }'
try "guard  n if n >= -5"       $'fn f(x: Int) { case x { n if n >= -5 -> "ge" _ -> "lt" } }\npub fn main() { show(#(f(-5), f(-6))) }'
try "guard  n if n >= 2 + 3"    $'fn f(x: Int) { case x { n if n >= 2 + 3 -> "ge" _ -> "lt" } }\npub fn main() { show(#(f(5), f(4))) }'
try "guard  n if n >= - -5"     $'fn f(x: Int) { case x { n if n >= - -5 -> "ge" _ -> "lt" } }\npub fn main() { show(#(f(5), f(4))) }'
try "guard  n if n >= m (var)"  $'fn f(x: Int, m: Int) { case x { n if n >= m -> "ge" _ -> "lt" } }\npub fn main() { show(#(f(5, 5), f(4, 5))) }'
try "exhaustive: n>=-5 / n< -5 no catch-all (MUST refuse)" $'fn f(x: Int) { case x { n if n >= -5 -> "ge" n if n < -5 -> "lt" } }\npub fn main() { show(f(1)) }'
try "float pattern -5.0"        $'fn f(x: Float) { case x { -5.0 -> "m" _ -> "o" } }\npub fn main() { show(f(-5.0)) }'
