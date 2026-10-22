#!/usr/bin/env bash
. "$(dirname "$0")/../lib.sh"
BSC=$(build_bsc plain) || exit 1
compile_shop "$BSC" "$SCRATCH/shop-ebin"
echo "== Erlang caller (ordinary quoted-atom syntax)"
erl -noshell -pa "$SCRATCH/shop-ebin" -eval "
  io:format(\"'Shop':'New'(1) -> ~p~n\", ['Shop':'New'(1)]),
  io:format(\"'Shop':'Which'(#{'Kind'=>'Shop.Order','Id'=>1,'Total'=>2}) -> ~p~n\", ['Shop':'Which'(#{'Kind'=>'Shop.Order','Id'=>1,'Total'=>2})]),
  halt()."
echo "== Elixir caller (via the quoted-name form; see probe 01)"
BS_EBIN="$SCRATCH/shop-ebin" elixir "$(dirname "$0")/probe.exs" 2>&1
