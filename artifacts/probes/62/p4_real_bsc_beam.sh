#!/usr/bin/env bash
# Ticket 62, re-measured on a beam bsc actually emitted (p1 used a hand-written Erlang stand-in):
#  (a) the export names and module atom; (b) every Elixir call spelling; (c) an Elixir struct and a wrong tag.
# Usage: bash p4_real_bsc_beam.sh   (bsc from the repo build; OTP>=26 + elixir on PATH)
set -u; here=$(cd "$(dirname "$0")" && pwd); BSC=${BSC:-$here/../../../compiler/_build/default/bin/bsc}
out=$(mktemp -d); "$BSC" -o "$out" "$here/../59/prog/Shop59" || exit 1
echo "beam files: $(ls $out)"
erl -noshell -eval '{ok,{M,[{exports,E}]}}=beam_lib:chunks("'$out'/Shop59.beam",[exports]), io:format("module ~p exports ~p~n",[M,[X||X={N,_}<-E, N=/=module_info]]), halt().'
t() { printf '%-46s -> ' "$1"; o=$(elixir -pa "$out" -e "$2" 2>&1); echo "$(echo "$o" | head -1 | cut -c1-120)"; }
t ':Shop59.SumAll([])'                       'IO.inspect(:Shop59.SumAll([]))'
t ':Shop59."SumAll"([])'                     'IO.inspect(:Shop59."SumAll"([]))'
t 'apply(:Shop59, :SumAll, [[]])'            'IO.inspect(apply(:Shop59, :SumAll, [[]]))'
t 'Elixir struct to Direct/1'                'Code.compile_string("defmodule S do defstruct [:Id, :Total] end")
IO.inspect(try do :Shop59."Direct"(struct(S, Id: 1, Total: 5)) rescue e -> e.__struct__ end)'
t 'map with the right Kind to Direct/1'      'IO.inspect(:Shop59."Direct"(%{Kind: :"Shop59.Order", Id: 1, Total: 5}))'
