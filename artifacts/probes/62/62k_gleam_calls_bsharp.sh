#!/usr/bin/env bash
# PROBE 62k — 62a compiled a Gleam @external to 'Shop':'New' but did not RUN the call ("measured as far as compiling").
# This runs it: Gleam declares the foreign function, calls it from its own function, the VM loads the bsc-built Shop beam.
# CONTROL: the same declaration pointing at a name Shop does not export must fail at run time with undef (the call is real).
set -uo pipefail
: "${BSC:?}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; mkdir "$W/ebin"
"$BSC" --src-root "$REPO/compiler/examples" -o "$W/ebin" "$REPO/compiler/examples/Shop" >/dev/null 2>&1
mkdir -p "$W/proj/src" && cd "$W/proj"
printf 'name = "proj"\nversion = "1.0.0"\n' > gleam.toml
cat > src/proj.gleam <<'G'
pub type Opaque

@external(erlang, "Shop", "New")
fn shop_new(id: Int) -> Opaque

@external(erlang, "Shop", "Nope")
fn shop_nope(id: Int) -> Opaque

pub fn make(id: Int) -> Opaque { shop_new(id) }
pub fn make_bad(id: Int) -> Opaque { shop_nope(id) }
G
gleam build --target erlang 2>&1 | tail -1
erl -noshell -pa build/dev/erlang/proj/ebin -pa "$W/ebin" -eval '
  io:format("Gleam -> B#  proj:make(5)      = ~p~n", [proj:make(5)]),
  R = try proj:make_bad(5) catch error:E:_ -> {error, E} end,
  io:format("CONTROL absent name make_bad   = ~p~n", [R]), halt().'
