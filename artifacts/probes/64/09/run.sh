#!/usr/bin/env bash
# Probe 64/09 - Gleam: always-tagged lookup. gleam/dict is stdlib (a hex package; hex.pm is blocked), so the
# stdlib SOURCE is cloned from github at a pinned tag and used as a PATH dependency. The Gleam compiler is the
# installed 1.19.0 binary (no compiler source is installed, so type behaviour here is evidenced by the run).
set -u
W=$(mktemp -d); trap 'rm -rf $W' EXIT
cd $W
git clone -q -c advice.detachedHead=false --depth 1 --branch v0.62.0 https://github.com/gleam-lang/stdlib.git stdlib 2>&1 | tail -1
echo "gleam: $(gleam --version)   stdlib: $(git -C stdlib describe --tags 2>/dev/null || git -C stdlib log --oneline -1)"
echo "--- stdlib source citations"
grep -n "^pub fn get(from: Dict(k, v), get: k) -> Result(v, Nil)" stdlib/src/gleam/dict.gleam
grep -n "^pub fn first(list: List(a)) -> Result(a, Nil)" stdlib/src/gleam/list.gleam
grep -n "^pub type Option(a)" stdlib/src/gleam/option.gleam; sed -n 19,22p stdlib/src/gleam/option.gleam | sed 's/^/    /'
grep -n "^pub fn flatten(option: Option(Option(a))) -> Option(a)" stdlib/src/gleam/option.gleam
mkdir -p proj/src
cat > proj/gleam.toml <<'T'
name = "proj"
version = "1.0.0"
[dependencies]
gleam_stdlib = { path = "../stdlib" }
T
cat > proj/src/proj.gleam <<'G'
import gleam/dict
import gleam/option.{type Option, None, Some}

// A Dict whose values are as unconstrained as a type can be: here Option(Int), which has a "nothing" member of its own.
pub fn main() {
  let d = dict.from_list([#("a", None), #("b", Some(1))])
  // present-and-None vs absent: two different values, because get ALWAYS wraps.
  echo dict.get(d, "a")      // Ok(None)
  echo dict.get(d, "zzz")    // Error(Nil)
  echo dict.get(d, "b")      // Ok(Some(1))
  // Option nests: Some(None) is not None
  let n: Option(Option(Int)) = Some(None)
  echo n
  echo option.flatten(n)
}
G
cd proj && gleam run 2>&1 | grep -v "^ *Compiling\|^ *Compiled\|^ *Running\|Downloading\|Resolving"
echo
echo "--- what the BEAM sees (Ok(V)/Error(Nil) and Some(V)/None are tagged tuples / atoms):"
cd $W/proj && gleam build 2>&1 | tail -1
erl -noshell -pa build/dev/erlang/*/ebin -eval '
D = gleam@dict:from_list([{<<"a">>, none}, {<<"b">>, {some, 1}}]),
io:format("gleam@dict:get(D, <<\"a\">>)   = ~p~n", [gleam@dict:get(D, <<"a">>)]),
io:format("gleam@dict:get(D, <<\"zzz\">>) = ~p~n", [gleam@dict:get(D, <<"zzz">>)]),
io:format("gleam@dict:get(D, <<\"b\">>)   = ~p~n", [gleam@dict:get(D, <<"b">>)]),
io:format("flat_size {ok,{some,1}} = ~p words; flat_size {ok,1}= ~p words~n", [erts_debug:flat_size({ok,{some,1}}), erts_debug:flat_size({ok,1})]),
halt().'
