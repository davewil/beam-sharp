#!/usr/bin/env bash
# Gleam 1.12.0 (binary only, no stdlib needed: no dependencies). Each case = one file built alone.
# EXPECTED before run:
#  GL1 `n if n >= -5 ->` compiles; run: g(-6)=false g(-5)=true
#  GL2 pattern `-5 ->` compiles; run: h(-5)=true h(5)=false
#  GL3 guard arithmetic `n if n >= 2 + 3 ->`: REFUSED (I believe guards take only a restricted operator set;
#      if it compiles this prediction is wrong and is reported as such)
#  GL4 guard `n if n >= -{2 + 3} ->` : REFUSED or accepted -- no prediction (probing whether unary minus over a
#      compound is a guard form); result is only recorded
G=${GLEAM:-/tmp/claude-0/tools/gleam}
W=${W:-/tmp/claude-0/-home-user-beam-sharp/40070274-2489-5304-8393-d8d915b713dc/scratchpad/work/57}/gl
rm -rf "$W"; mkdir -p "$W/p/src"; cd "$W/p"
printf 'name = "p"\nversion = "1.0.0"\ntarget = "erlang"\n\n[dependencies]\n' > gleam.toml
try () { # id expect(a|r|-) body
  printf '%s\n' "$3" > src/p.gleam; rm -rf build
  if out=$($G build 2>&1); then got=a; else got=r; fi
  # "x>y" = first-run prediction x was WRONG, corrected expectation y (written after seeing the output)
  note=""; exp=$2
  case "$2" in *">"*) note=" (first-run prediction ${2%%>*} was wrong)"; exp=${2##*>};; esac
  if [ "$2" = "-" ]; then m="RECORD"; elif [ "$exp" = "$got" ]; then m=PASS; else m="FAIL"; fi
  printf '%s %s expected %s observed %s%s  %s\n' "$m" "$1" "$exp" "$got" "$note" "$(printf '%s' "$out" | grep -m1 -E 'error|Error' | cut -c1-90)"
}
try GL1 a 'pub fn g(n: Int) -> Bool {
  case n {
    n if n >= -5 -> True
    _ -> False
  }
}'
erl -noshell -pa build/dev/erlang/p/ebin -eval 'io:format("GL1-run g(-6)=~p g(-5)=~p~n",[p:g(-6),p:g(-5)]),halt().'
try GL2 a 'pub fn h(n: Int) -> Bool {
  case n {
    -5 -> True
    _ -> False
  }
}'
erl -noshell -pa build/dev/erlang/p/ebin -eval 'io:format("GL2-run h(-5)=~p h(5)=~p~n",[p:h(-5),p:h(5)]),halt().'
try GL3 'r>a' 'pub fn g(n: Int) -> Bool {
  case n {
    n if n >= 2 + 3 -> True
    _ -> False
  }
}'
try GL4 - 'pub fn g(n: Int) -> Bool {
  case n {
    n if n >= -{2 + 3} -> True
    _ -> False
  }
}'
try GL5 - 'pub fn g(n: Int) -> Bool {
  case n {
    n if n >= 2 * 3 -> True
    _ -> False
  }
}'
