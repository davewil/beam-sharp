#!/usr/bin/env bash
# Ticket 57 probes. Usage: run.sh  (needs erl, elixir, gleam, elm on PATH and a built bsc in $BSC)
# Every probe prints its raw result; nothing is asserted by the script itself.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
BSC=${BSC:-$HERE/../../../compiler/_build/default/bin/bsc}
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT

echo "=== P1: refinement matrix on the CURRENT compiler"
i=0
while IFS= read -r pred; do
  i=$((i+1)); mkdir -p "$W/R$i/R$i"
  printf 'module R%s\ntype T = int where %s\npublic int Id(T t)\nId(t) -> t\n' "$i" "$pred" > "$W/R$i/R$i/R$i.bs"
  out=$(cd "$W/R$i" && "$BSC" R$i 2>&1 | head -1)
  printf '%-48s %s\n' "$pred" "${out:-ACCEPTED}"
done <<'P'
value >= -5
value >= -5 and value <= 5
value >= 1 or value <= -1
value <= 3 or value >= 10
value != 0
value != -1
value == -3
-5 <= value
value >= 2 + 3
value >= -(-5)
value >= -0
value > -1.5
P

echo "=== P2: a GUARD with a negative literal — does it credit coverage? (exhaustiveness)"
mkdir -p "$W/G/G"; cat > "$W/G/G/G.bs" <<'B'
module G
public atom Sign(int n)
Sign(n) when n >= 1 -> :pos
Sign(n) when n <= -1 -> :neg
Sign(0) -> :zero
B
(cd "$W/G" && "$BSC" G 2>&1 | head -6)
echo "--- same, but the negative bound written as a pattern (the control)"
mkdir -p "$W/H/H"; cat > "$W/H/H/H.bs" <<'B'
module H
public atom Sign(int n)
Sign(>= 1) -> :pos
Sign(<= -1) -> :neg
Sign(0) -> :zero
B
(cd "$W/H" && "$BSC" H 2>&1 | head -6; echo "rc=$?")

echo "=== P3: AST shape of -5 at each site (erts_debug:flat_size, bytes = words*8)"
erl -noshell -pa "$HERE/../../../compiler/_build/default/lib/bsc/ebin" -eval '
  {ok,T,_}=bs_lexer:string("module X\ntype T = int where value >= -5\n"),
  io:format("~p~n",[catch bs_parser:parse(T)]),
  A={e_neg,1,{e_int,1,5}}, B={e_int,1,-5},
  io:format("e_neg node words=~p ; folded literal words=~p~n",[erts_debug:flat_size(A),erts_debug:flat_size(B)]),
  halt().' 2>&1 | head -20
