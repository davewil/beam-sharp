#!/usr/bin/env bash
# S-ERL — does erlc keep a function-entry guard on a LOCAL function?  When is it elided?
# Ticket 18 §1 says elision is "exported vs local-only".  Test what actually decides it:
# erlc's beam_ssa_type infers argument types across local call sites, but only while
# every call site is known.  A fun that escapes makes the function reachable from anywhere.
source "$(dirname "$0")/../lib.sh"; cd "$WORK"
cat > e.erl <<'X'
-module(e).
-export([run_known/1, run_escape/0, run_exported/1, exported_guarded/1]).
%% 1. local fn, every call site passes an integer: guard is provably true
run_known(X) when is_integer(X) -> known(X) + 1.
known(N) when is_integer(N) -> N * 2.
%% 2. local fn whose name ESCAPES as a fun: callers unknown
run_escape() -> fun escaping/1.
escaping(N) when is_integer(N) -> N * 2.
%% 3. local fn called with an unknown term from an exported fn
run_exported(X) -> unknown(X).
unknown(N) when is_integer(N) -> N * 2.
%% 4. exported fn, same guard
exported_guarded(N) when is_integer(N) -> N * 2.
X
erlc -S e.erl
# print the instruction stream of each function, guard instruction present?
for f in known escaping unknown exported_guarded; do
  printf "%-18s is_integer test kept: " $f
  awk -v f="$f" '$0 ~ "^{function, "f", 1," {p=1} p&&/^{function, / && $0 !~ "{function, "f", 1," {p=0} p' e.S | grep -c "is_integer" | sed 's/^0$/NO (elided)/;s/^[1-9]/YES/'
done
