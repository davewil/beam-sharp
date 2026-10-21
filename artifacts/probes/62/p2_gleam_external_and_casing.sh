#!/bin/sh
# 62 / probe 2 — (a) can Gleam call 'Shop':'New'/1 and does the call RUN (the ticket measured compile only)?
#                (b) what does Gleam do with PascalCase when it emits Erlang? (the ticket's "precedent" claim)
# Needs: gleam, erlc, escript. GLEAM_STDLIB = a stdlib checkout (path dependency; hex is not reachable).
set -u
D=$(cd "$(dirname "$0")" && pwd); W=${PROBE_TMP:-$(mktemp -d)}; STD=${GLEAM_STDLIB:?set GLEAM_STDLIB}
gleam --version
mkdir -p "$W/proj/src" && cd "$W/proj"
cat > gleam.toml <<T
name = "proj"
version = "1.0.0"
target = "erlang"
[dependencies]
gleam_stdlib = { path = "$STD" }
T
mkdir -p "$W/proj/ebin_extra" && erlc -o "$W/proj/ebin_extra" "$D/Shop.erl"
cat > src/proj.gleam <<'G'
import gleam/dynamic.{type Dynamic}
import gleam/io
import gleam/string

pub type Event { OrderPlaced(id: Int)  HTTPGet  GetID }

@external(erlang, "Shop", "New")
fn shop_new(id: Int) -> Dynamic

pub fn main() { io.println(string.inspect(shop_new(5))) }
G
gleam build 2>&1 | tail -3
echo '--- (a) run it, with the Erlang module on the path'
erl -noshell -pa build/dev/erlang/*/ebin ebin_extra -eval 'proj:main(),halt().'
echo '--- (b1) how Gleam emits a PascalCase CONSTRUCTOR'
grep -n "order_placed\|h_t_t_p\|http_get\|get_i_d\|get_id" build/dev/erlang/proj/_gleam_artefacts/proj.erl | head
echo '--- (b2) can a Gleam FUNCTION be PascalCase?'
cat > src/proj.gleam <<'G'
pub fn New(id: Int) -> Int { id }
G
gleam build 2>&1 | head -8
