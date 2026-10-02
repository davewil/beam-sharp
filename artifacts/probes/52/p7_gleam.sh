#!/usr/bin/env bash
# P7: Gleam 1.12.0 -- @external(erlang, "Mod", "fn") naming a module that does not exist,
# and what gleam.toml [dependencies] does/does not govern. No network used.
set -u
G=${GLEAM:-/tmp/claude-0/-home-user-beam-sharp/a3310f8a-c503-5acc-8cf0-37e76fb5554b/scratchpad/tc/gleam}
W="$(mktemp -d)"; cd "$W" || exit 2; fail=0
$G --version
$G new p --skip-git --skip-github >/dev/null 2>&1 || { echo "gleam new failed"; exit 2; }
cd p
cat > gleam.toml <<'EOT'
name = "p"
version = "1.0.0"
EOT
cat > src/p.gleam <<'EOT'
@external(erlang, "Elixir.Req", "new")
fn req_new(opts: List(Nil)) -> Nil

pub fn main() { req_new([]) }
EOT
rm -rf test
echo "== build with an @external to an absent module =="
$G build 2>&1 | tail -6; rc=${PIPESTATUS[0]}; echo "build exit=$rc"; [ $rc -eq 0 ] || { echo "UNEXPECTED: gleam refused"; fail=1; }
echo "== generated erlang: how is the foreign module referenced? =="
f=$(ls build/dev/erlang/p/_gleam_artefacts/p.erl); grep -n "Elixir.Req\|^-export\|^-spec\|^-file" "$f"
echo "== run =="
r=$(cd build/dev/erlang/p/ebin && erl -noshell -pa . -eval 'try p:main() catch C:R -> io:format("~p:~p~n",[C,R]) end, halt().'); echo "$r"; [ "$r" = "error:undef" ] || { echo UNEXPECTED; fail=1; }
echo "== beam imports chunk =="
erl -noshell -eval '{ok,{_,[{imports,I}]}}=beam_lib:chunks("build/dev/erlang/p/ebin/p.beam",[imports]), io:format("~p~n",[I]), halt().'
echo "== a gleam.toml dependency is only consulted for GLEAM imports: importing an undeclared package module =="
cat > src/p.gleam <<'EOT'
import gleam/io
pub fn main() { io.println("x") }
EOT
$G build 2>&1 | head -12; rc=${PIPESTATUS[0]}; echo "exit=$rc"; [ $rc -ne 0 ] || { echo UNEXPECTED; fail=1; }
rm -rf "${W:?}"; exit $fail
