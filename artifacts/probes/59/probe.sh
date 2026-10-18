#!/bin/bash
# Ticket 59 (ENG-241): record tag test on private functions vs int kind test on exported only.
# Variants (scratch copies of compiler/src, patches in proto/):
#   c           baseline: tag test everywhere, kind test exported-only
#   c59_narrow  tag test exported-only too (resolves the asymmetry downward)
#   c59_wide    kind test on private too   (resolves it upward)
. "$(dirname "$0")/../env.sh"
for v in c c59_narrow c59_wide; do
  export BSC_EBIN=$S/$v/ebin
  work 59_$v
  mkdir G
  cat > G/G.bs <<'B'
module G
record Order { Id: int, Total: int }
record Other { Id: int, Total: int }
type Octet = int where value >= 0 and value <= 255

public int First(list<Order> os)
First([])       -> 0
First([o, ..])  -> Total(o)
private int Total(Order o)
Total(o) -> o.Total
public int Direct(Order o)
Direct(o) -> o.Total

public int FirstOctet(list<Octet> os)
FirstOctet([])      -> 0
FirstOctet([o, ..]) -> Classify(o)
private int Classify(Octet t)
Classify(>= 128) -> 1
Classify(<= 127) -> 0
public int Direct2(Octet t)
Direct2(>= 128) -> 1
Direct2(<= 127) -> 0
B
  cat > forge.erl <<'B'
-module(forge).
-export([run/0]).
try_(Label, F) ->
    R = try F() of V -> {returned, V}
        catch C:E -> {C, case E of {Tag, _} -> Tag; _ -> E end} end,
    io:format("  ~-44s ~p~n", [Label, R]).
run() ->
    Good  = #{'Kind' => 'G.Order', 'Id' => 1, 'Total' => 9},
    Alien = #{'Kind' => 'G.Other', 'Id' => 1, 'Total' => 77},   %% another record, same fields
    try_("First([Order])       genuine Order",  fun() -> 'G':'First'([Good]) end),
    try_("First([Order])       forged Other",   fun() -> 'G':'First'([Alien]) end),
    try_("Direct(Order)        forged Other",   fun() -> 'G':'Direct'(Alien) end),
    try_("FirstOctet([Octet])  200",            fun() -> 'G':'FirstOctet'([200]) end),
    try_("FirstOctet([Octet])  200.5 (a float)",fun() -> 'G':'FirstOctet'([200.5]) end),
    try_("Direct2(Octet)       200.5 (a float)",fun() -> 'G':'Direct2'(200.5) end).
B
  bsc --src-root . -o . G 2>&1 | head -3
  erlc forge.erl
  echo "=============== variant $v"
  erl -noshell -pa . -eval 'forge:run(), halt().'
  echo "  G.beam $(stat -c %s G.beam) bytes; tag tests (map_get) in G.abstr: $(grep -c map_get G.abstr)"
done
