#!/usr/bin/env bash
# 10 — the blast-radius test for option C (v4): does a function's emitted guard change when a
# SIBLING FILE of the same module takes its name as a value?  18 §4 rejected whole-aggregate
# analysis because "an edit to format.bs alone silently changes the emitted boundary of
# describe.bs".  Run the same module twice: with and without the escaping sibling file.
HERE0="$(cd "$(dirname "$0")" && pwd)"; source "$HERE0/lib.sh"; cd "$WORK"
SCRATCH=${SCRATCH:-/tmp/claude-0/-home-user-beam-sharp/9b30e02b-d742-5d59-8509-86bd14e28edc/scratchpad}
mkdir -p X/Xm Y/Xm
cat > X/Xm/total.bs <<'B'
module Xm

record Order { Id: int, Total: int }

private int Inner(Order o)
Inner(o) -> o.Total

public int Outer(Order o)
Outer(o) -> Inner(o)
B
cp X/Xm/total.bs Y/Xm/total.bs
# the sibling file that makes Inner/1 escape, present only in Y
cat > Y/Xm/leak.bs <<'B'
module Xm

public fn(Order) -> int Leak()
Leak() -> Inner/1
B
for v in v0 v1 v4; do
  for t in X Y; do
    rm -rf out_$v$t; "$SCRATCH/var/$v/bsc" -o out_$v$t $t/Xm 2>&1 | head -3
    printf "%s %s  Inner guard: " $v $t
    erl -noshell -eval '
      {ok,Forms}=file:consult(hd(filelib:wildcard("out_'$v$t'/*.abstr"))),
      [io:format("~s~n",[string:trim(re:replace(erl_pp:form(Fm),"\\s+"," ",[global,{return,list}]))]) || {function,_,N,_,_}=Fm <- Forms, atom_to_list(N)=:="Inner"], halt().'
  done
done
