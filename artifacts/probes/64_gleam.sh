#!/usr/bin/env bash
# 64_gleam.sh
# CLAIM: Gleam's dict.get returns Result(v, Nil); because Option is a real constructor type (Some/None) and Ok is
#   a constructor, Gleam NEVER collapses absence into a stored value: Ok(None) (present, value is None) and
#   Error(Nil) (absent) stay distinct, even for Dynamic values (where None is an erased atom).
# NEEDS: github (clones gleam-lang/stdlib v0.62.0 as a path dependency; hex is blocked).
# REFUTED if: the three lines below do not print three DIFFERENT strings (absent / present-None / present-nil-Dynamic),
#   or the program fails to compile.
. "$(dirname "$0")/env.sh"
W=$(bs_scratch); trap 'rm -rf "$W"' EXIT
git clone -q --depth 1 --branch v0.62.0 https://github.com/gleam-lang/stdlib.git "$W/stdlib" 2>&1 | tail -1
echo "stdlib dict.get declaration:"; grep -n 'pub fn get(from: Dict' "$W/stdlib/src/gleam/dict.gleam"
echo "its erlang external:"; grep -n '"map_get"' "$W/stdlib/src/gleam/dict.gleam" | head -1
P="$W/proj"; mkdir -p "$P/src"
cat > "$P/gleam.toml" <<T
name = "probe"
version = "1.0.0"
target = "erlang"
[dependencies]
gleam_stdlib = { path = "$W/stdlib" }
T
cat > "$P/src/probe.gleam" <<'G'
import gleam/dict
import gleam/dynamic
import gleam/io
import gleam/option.{type Option, None, Some}

fn show(r: Result(Option(Int), Nil)) -> String {
  case r {
    Error(Nil) -> "absent"
    Ok(None) -> "present, value is None"
    Ok(Some(n)) -> "present, Some"
  }
}

pub fn main() {
  let d = dict.from_list([#("a", None), #("b", Some(1))])
  io.println("get c  (no such key)         : " <> show(dict.get(d, "c")))
  io.println("get a  (stored None)          : " <> show(dict.get(d, "a")))
  // Dynamic values: a stored `nil`-like atom. Result still distinguishes.
  let dd = dict.from_list([#("k", dynamic.nil())])
  let r = case dict.get(dd, "k") {
    Error(Nil) -> "absent"
    Ok(_) -> "present, value is dynamic nil"
  }
  let r2 = case dict.get(dd, "zz") {
    Error(Nil) -> "absent"
    Ok(_) -> "present"
  }
  io.println("Dynamic: get k (stored nil)   : " <> r)
  io.println("Dynamic: get zz (no such key) : " <> r2)
}
G
cd "$P" && gleam run 2>&1 | grep -v -E '^ *(Compiling|Compiled|Resolving|Downloading|Downloaded|Running)' | sed "s|$W/||g"
