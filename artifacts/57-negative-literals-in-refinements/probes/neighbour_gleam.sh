#!/usr/bin/env bash
# Gleam 1.19.1 (binary only; compiler source NOT available): negative literals in patterns and guards.
# Each snippet is built with `gleam build`; prints accepted/refused + first error line, and the Erlang it emits.
S=/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad
source $S/env.sh
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
mkdir -p $W/src; printf 'name = "p"\nversion = "1.0.0"\ntarget = "erlang"\n' > $W/gleam.toml
t () { # name  body
  printf '%s\n' "$2" > $W/src/p.gleam
  out=$(cd $W && gleam build 2>&1); rc=$?
  if echo "$out" | grep -q "^error"; then r=REFUSED; else r=accepted; fi
  printf '%-34s %-9s %s\n' "$1" "$r" "$(echo "$out" | grep -A1 '^error' | tr '\n' ' ' | cut -c1-110)"
}
t "pattern  -5"                 'pub fn f(x: Int) { case x { -5 -> 1 _ -> 0 } }'
t "pattern  - 5 (space)"        'pub fn f(x: Int) { case x { - 5 -> 1 _ -> 0 } }'
t "pattern  -(5)"               'pub fn f(x: Int) { case x { -(5) -> 1 _ -> 0 } }'
t "pattern  0 - 5"              'pub fn f(x: Int) { case x { 0 - 5 -> 1 _ -> 0 } }'
t "pattern  -5.0 float"         'pub fn f(x: Float) { case x { -5.0 -> 1 _ -> 0 } }'
t "pattern  -0x10 hex"          'pub fn f(x: Int) { case x { -0x10 -> 1 _ -> 0 } }'
t "guard    n >= -5"            'pub fn f(x: Int) { case x { n if n >= -5 -> 1 _ -> 0 } }'
t "guard    n == -5"            'pub fn f(x: Int) { case x { n if n == -5 -> 1 _ -> 0 } }'
t "guard    n >= - 5"           'pub fn f(x: Int) { case x { n if n >= - 5 -> 1 _ -> 0 } }'
t "guard    n >= -{5}"          'pub fn f(x: Int) { case x { n if n >= -{5} -> 1 _ -> 0 } }'
t "guard    n >= 0 - 5"         'pub fn f(x: Int) { case x { n if n >= 0 - 5 -> 1 _ -> 0 } }'
t "guard    n >= 2 + 3"         'pub fn f(x: Int) { case x { n if n >= 2 + 3 -> 1 _ -> 0 } }'
t "guard    -n >= 5 (CONTROL?)" 'pub fn f(x: Int) { case x { n if -n >= 5 -> 1 _ -> 0 } }'
t "guard    n >= m (non-const)" 'pub fn f(x: Int, m: Int) { case x { n if n >= m -> 1 _ -> 0 } }'
t "expr     -5"                 'pub fn f() { -5 }'
echo "--- emitted abstract form for the pattern and the guard (beam_lib; gleam deletes its .erl)"
printf 'pub fn f(x: Int) { case x { -5 -> 1 n if n >= -3 -> 2 _ -> 0 } }\n' > $W/src/p.gleam
(cd $W && gleam build >/dev/null 2>&1 && erl -noshell -eval 'case beam_lib:chunks("build/dev/erlang/p/ebin/p.beam",[abstract_code]) of {ok,{_,[{abstract_code,{_,F}}]}} -> [io:format("~p~n",[X]) || X={function,_,f,_,_} <- F]; E -> io:format("~p~n",[E]) end, halt().')
