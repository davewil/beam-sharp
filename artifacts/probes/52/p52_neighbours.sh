#!/usr/bin/env bash
# Ticket 52 survey. Where does each neighbour record what a source file needs, and what enforces it?
. "$(dirname "$0")/../env.sh"
W=$(mktemp -d); LIBS=$W/libs; mkdir -p $LIBS/demo-1.2.3/ebin $LIBS/demo-1.2.3/include
printf 'defmodule Demo do\n  def double(n), do: n * 2\nend\n' > $W/demo.ex
(cd $W && elixirc -o $LIBS/demo-1.2.3/ebin demo.ex 2>&1 | grep -v 'native name')
printf '{application, demo, [{vsn, "1.2.3"}, {modules, [%s]}, {registered, []}, {applications, [kernel, stdlib]}]}.\n' "'Elixir.Demo'" > $LIBS/demo-1.2.3/ebin/demo.app
printf -- '-define(DEMO_K, 2).\n' > $LIBS/demo-1.2.3/include/demo.hrl
echo '--- Erlang: -include_lib("demo/include/demo.hrl") names the APPLICATION in source; compile time, both machines'
cat > $W/u.erl <<'X'
-module(u).
-export([k/0]).
-include_lib("demo/include/demo.hrl").
k() -> ?DEMO_K.
X
echo "[has dep]";  ERL_LIBS=$LIBS erlc -o $W $W/u.erl; echo "rc=$?"
echo "[lacks dep]"; env -u ERL_LIBS erlc -o $W $W/u.erl 2>&1 | sed "s|$W/||"
echo '--- Erlang: a call to a missing module compiles clean (this is beam-sharp'"'"'s status quo)'
cat > $W/v.erl <<'X'
-module(v).
-export([r/1]).
r(N) -> 'Elixir.Demo':double(N).
X
env -u ERL_LIBS erlc -o $W $W/v.erl; echo "rc=$? (compile with no dependency present)"
echo '--- Erlang: systools checks the release manifest for the application, at release-build time'
cat > $W/r.rel <<'X'
{release, {"r", "1"}, {erts, "16.4"}, [{kernel, "10.6.3"}, {stdlib, "7.3"}, {demo, "1.2.3"}]}.
X
(cd $W && env -u ERL_LIBS erl -noshell -eval 'R = systools:make_script("r", [silent, local]), io:format("~p~n", [element(1, R)]), (case R of {error, M, E} -> io:format("~p ~P~n", [M, E, 8]); _ -> ok end), halt().')
echo '--- Elixir: Mix.install declares dependencies IN the script (a path dep here; Hex is not reachable)'
mkdir -p $W/demo_proj/lib && cat > $W/demo_proj/mix.exs <<'X'
defmodule DemoProj.MixProject do
  use Mix.Project
  def project, do: [app: :demo_proj, version: "0.1.0", deps: []]
end
X
printf 'defmodule DemoProj do\n  def double(n), do: n * 2\nend\n' > $W/demo_proj/lib/demo_proj.ex
cat > $W/script.exs <<X
Mix.install([{:demo_proj, path: "$W/demo_proj"}])
IO.inspect(DemoProj.double(21))
X
(cd $W && MIX_HOME=$W/mixhome HEX_HOME=$W/hexhome timeout 120 elixir script.exs 2>&1 | grep -v 'native name' | tail -4)
echo '--- Elixir: a call to an absent module compiles with a warning; run fails'
printf 'defmodule X do\n  def r(n), do: Demo.double(n)\nend\nIO.inspect(try do X.r(1) rescue e -> e end)\n' > $W/x.exs
(cd $W && env -u ERL_LIBS elixir x.exs 2>&1 | grep -v 'native name' | head -6)
echo '--- Gleam: @external to a module in an undeclared package'
mkdir -p $W/g/src && printf 'name = "g"\nversion = "1.0.0"\ntarget = "erlang"\n' > $W/g/gleam.toml
cat > $W/g/src/g.gleam <<'X'
@external(erlang, "Elixir.Demo", "double")
fn double(n: Int) -> Int

pub fn r(n: Int) -> Int { double(n) }
X
(cd $W/g && gleam build 2>&1 | tail -2; echo "[gleam rc=${PIPESTATUS[0]}]")
echo '--- Gleam: a gleam-source import of a package that is not in gleam.toml'
printf 'import nopkg\npub fn r() -> Int { nopkg.x() }\n' > $W/g/src/g.gleam
(cd $W/g && gleam build 2>&1 | head -8; echo "[gleam rc=${PIPESTATUS[0]}]")
