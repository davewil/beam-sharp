#!/bin/bash
# Ticket 57: the measurable costs. (a) term size of the node the checker sees; (b) parse+check time per variant.
. "$(dirname "$0")/../env.sh"
erl -noshell -eval '
A={e_neg,{2,29},{e_int,{2,30},5}}, B={e_int,{2,29},-5},
io:format("words  e_neg(e_int 5) = ~p   folded e_int -5 = ~p~n",[erts_debug:flat_size(A),erts_debug:flat_size(B)]),
halt().'
mkdir -p $S/work/57m/M; cat > $S/work/57m/M/M.bs <<'B'
module M
type D = int where value >= 3 and value <= 100
public int F(D d)
F(d) -> d
public atom H(int n)
H(n) when n >= 5 -> :hi
H(n) when n < 5 -> :lo
B
for v in c c57_checker c57_parser; do
  BSC_EBIN=$S/$v/ebin erl -noshell -pa $S/$v/ebin -eval '
  T=fun() -> bsc:status(["--src-root","'$S'/work/57m","'$S'/work/57m/M"], undefined) end,
  _=(catch T()),
  {Us,_}=timer:tc(fun() -> [catch T() || _ <- lists:seq(1,200)] end),
  io:format("~-14s 200 compiles of a 7-line module with a refinement and two guards: ~p ms total (~p us each)~n",["'$v'",Us div 1000, Us div 200]), halt().' 2>&1 | tail -1
done
