#!/bin/sh
# 64 / probe 2 — how do neighbouring BEAM languages keep "absent" distinct at a `term`/dynamic value type?
set -u
W=${PROBE_TMP:-$(mktemp -d)}; STD=${GLEAM_STDLIB:?set GLEAM_STDLIB}
echo '== Elixir: Map.get/2 (bare, nil as absent) vs Map.fetch/2 (tagged)'
elixir -e '
m = %{present_but_nil: nil}
IO.inspect({Map.get(m, :present_but_nil), Map.get(m, :missing)}, label: "Map.get   (present-nil, missing)")
IO.inspect({Map.fetch(m, :present_but_nil), Map.fetch(m, :missing)}, label: "Map.fetch (present-nil, missing)")'
echo '== Gleam: Option(Dynamic) and dict.get at a dynamic value type'
mkdir -p "$W/g/src" && cd "$W/g" && cat > gleam.toml <<T
name = "g"
version = "1.0.0"
target = "erlang"
[dependencies]
gleam_stdlib = { path = "$STD" }
T
cat > src/g.gleam <<'G'
import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/string

pub fn main() {
  let d: dict.Dict(String, Dynamic) = dict.from_list([#("k", dynamic.nil())])
  io.println(string.inspect(#(dict.get(d, "k"), dict.get(d, "missing"))))
  let a: Option(Dynamic) = Some(dynamic.nil())
  let b: Option(Dynamic) = None
  io.println(string.inspect(#(a, b)))
}
G
gleam build 2>&1 | tail -1
erl -noshell -pa build/dev/erlang/*/ebin -eval 'g:main(), halt().'
echo '-- emitted Erlang for the Option type:'
grep -n 'option' build/dev/erlang/g/_gleam_artefacts/g.erl | head -3; grep -rn -- '-type option' build/dev/erlang/gleam_stdlib/_gleam_artefacts/gleam@option.erl
