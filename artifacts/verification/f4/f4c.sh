#!/bin/sh
export BSC=/home/user/beam-sharp/compiler/_build/default/bin/bsc; . /home/user/beam-sharp/artifacts/probes/env.sh
W=$(mktemp -d); mkdir -p $W/Elixir/Enum; printf 'module Elixir.Enum\n\npublic int Go(int x)\nGo(x) -> x\n' > $W/Elixir/Enum/m.bs
$BSC --src-root $W -o $W/out $W/Elixir/Enum || exit 2
cd $W
echo "-- CONTROL: same purge/delete sequence, B# beam NOT on path"
cat > c.exs <<X
IO.inspect(Enum.map([1, 2], &(&1 + 1)), label: "before")
:code.purge(Enum); :code.delete(Enum)
IO.inspect(Code.ensure_loaded(Enum), label: "reload")
IO.inspect(Enum.map([1, 2], &(&1 + 1)), label: "after")
X
elixir c.exs 2>&1 | head -5 | cut -c1-160
echo "-- TREATMENT: B# beam prepended"
sed -i "2i Code.prepend_path(\"$W/out\")" c.exs
elixir c.exs 2>&1 | head -5 | cut -c1-160
rm -f erl_crash.dump
