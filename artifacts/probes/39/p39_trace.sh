#!/usr/bin/env bash
# Ticket 39. Debuggability cost of inlining: crash inside a tiny PRIVATE function; what does the stack trace name?
. "$(dirname "$0")/../env.sh"; ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
W=$(mktemp -d); mkdir -p $W/src/T
cat > $W/src/T/t.bs <<'X'
module T

using :erlang {
    int hd(list<int> xs)
}

private int First(list<int> xs)
First(xs) -> :erlang.hd(xs)

public int Run(list<int> xs)
Run(xs) -> First(xs) + 1
X
for v in base I1 I2; do
  e=$SCRATCH/ebin; [ $v != base ] && e=$SCRATCH/v39/$v/ebin
  BSC_EBIN=$e bsc -o $W/$v $W/src/T >/dev/null 2>&1 || { echo "$v: compile failed"; continue; }
  echo "== $v"
  erl -noshell -pa $W/$v -eval 'try '"'"'T'"'"':'"'"'Run'"'"'([]) catch C:R:St -> io:format("~p:~p~n",[C,R]), [io:format("   ~p~n",[{M,F,A,proplists:get_value(line,L)}]) || {M,F,A,L} <- St] end, halt().'
done
