#!/bin/sh
# 65 / probe 2 — what do Elixir, Erlang and Gleam do when USER code takes a name the standard environment owns?
set -u
W=${PROBE_TMP:-$(mktemp -d)}; STD=${GLEAM_STDLIB:?set GLEAM_STDLIB}
echo "== Elixir $(elixir --version | tail -1): defmodule Map (the standard module's own name)"
cat > "$W/map.exs" <<'X'
defmodule Map do
  def hello, do: :mine
end
IO.inspect(Map.hello(), label: "Map.hello()")
IO.inspect(function_exported?(Map, :get, 2), label: "Map.get/2 still exported?")
IO.inspect(Enum.into([a: 1], %{}), label: "Enum.into(kw, %{})  (Enum calls into Map)")
X
elixir "$W/map.exs" 2>&1 | cut -c1-170 | head -12
echo; echo "== Erlang: -type map() / -type list(T) redefining a built-in type, per OTP"
cat > "$W/t.erl" <<'X'
-module(t).
-export_type([map/0]).
-type map() :: {my, map}.
X
for E in /usr/bin/erlc /tmp/tc/otp28/bin/erlc; do [ -x $E ] && { printf '%s: ' "$($(dirname $E)/erl -noshell -eval 'io:format("OTP ~s",[erlang:system_info(otp_release)]),halt().')"; (cd "$W" && $E t.erl 2>&1 | head -2 | tr '\n' ' '; echo "(exit $?)"); }; done
echo; echo "== Gleam $(gleam --version): user type named like a prelude type; user module named like a stdlib module"
mkdir -p "$W/g/src/gleam" && cd "$W/g" && cat > gleam.toml <<T
name = "g"
version = "1.0.0"
[dependencies]
gleam_stdlib = { path = "$STD" }
T
cat > src/g.gleam <<'G'
pub type Result { Mine }
pub type Bool { Yes  No }
pub fn main() { Yes }
G
printf 'type Result / type Bool shadowing the prelude -> '; gleam build 2>&1 | grep -v '^$' | tail -2 | tr '\n' ' '; echo
cat > src/g.gleam <<'G'
import gleam/list
pub fn main() { list.length([1]) }
G
cat > src/list.gleam <<'G'
pub fn length(_x: List(a)) -> Int { 99 }
G
printf 'src/list.gleam beside import gleam/list     -> '; gleam build 2>&1 | grep -v '^$' | tail -2 | tr '\n' ' '; echo
printf 'src/gleam/list.gleam (same path as stdlib)  -> '; mv src/list.gleam src/gleam/list.gleam; gleam build 2>&1 | grep -v '^$' | head -6 | tr '\n' ' '; echo
