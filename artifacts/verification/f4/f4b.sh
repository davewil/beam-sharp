#!/bin/sh
export BSC=/home/user/beam-sharp/compiler/_build/default/bin/bsc; . /home/user/beam-sharp/artifacts/probes/env.sh
W=$(mktemp -d); mkdir -p $W/Elixir/Enum; printf 'module Elixir.Enum\n\npublic int Go(int x)\nGo(x) -> x\n' > $W/Elixir/Enum/m.bs
$BSC --src-root $W -o $W/out $W/Elixir/Enum || exit 2
cd $W
echo "-- plain VM, no clobber:"; elixir -e 'IO.inspect(Enum.map([1],&(&1+1)))' 2>&1 | head -2
echo "-- -pz (B# beam at END of path):"; elixir -pz $W/out -e 'IO.inspect(Enum.map([1],&(&1+1))); IO.inspect(:code.which(Enum))' 2>&1 | head -3 | cut -c1-200
echo "-- -pa (B# beam at FRONT of path):"; elixir -pa $W/out -e 'IO.inspect(Enum.map([1],&(&1+1)))' 2>&1 | head -3 | cut -c1-200
rm -f erl_crash.dump
