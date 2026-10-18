#!/bin/bash
# Ticket 59: measure what the private-function guards cost per call, in a hot loop.
. "$(dirname "$0")/../env.sh"
for v in c c59_narrow c59_wide; do
  export BSC_EBIN=$S/$v/ebin
  work 59c_$v; mkdir H
  cat > H/H.bs <<'B'
module H
record Order { Id: int, Total: int }
type Octet = int where value >= 0 and value <= 255

public int RunRec(int n, Order o) 
RunRec(n, o) -> SpinRec(n, o, 0)
private int SpinRec(int n, Order o, int acc)
SpinRec(<= 0, o, acc) -> acc
SpinRec(n, o, acc) -> SpinRec(n - 1, o, acc + Total(o))
private int Total(Order o)
Total(o) -> o.Total

public int RunInt(int n, Octet x)
RunInt(n, x) -> SpinInt(n, x, 0)
private int SpinInt(int n, Octet x, int acc)
SpinInt(<= 0, x, acc) -> acc
SpinInt(n, x, acc) -> SpinInt(n - 1, x, acc + Classify(x))
private int Classify(Octet t)
Classify(>= 128) -> 1
Classify(<= 127) -> 0
B
  bsc --src-root . -o . H 2>&1 | head -3
  cat > b.erl <<'B'
-module(b).
-export([run/0]).
t(F) -> lists:min([begin {U,_} = timer:tc(F), U end || _ <- lists:seq(1, 15)]).
run() ->
    O = #{'Kind' => 'H.Order', 'Id' => 1, 'Total' => 3}, N = 5000000,
    R = t(fun() -> 'H':'RunRec'(N, O) end),
    I = t(fun() -> 'H':'RunInt'(N, 200) end),
    io:format("  SpinRec ~p ms   SpinInt ~p ms   (min of 15, ~p calls each)~n", [R div 1000, I div 1000, N]).
B
  erlc b.erl; echo "=== variant $v"; erl -noshell -pa . -eval 'b:run(), halt().'
done
