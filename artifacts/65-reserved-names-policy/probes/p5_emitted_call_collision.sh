#!/usr/bin/env bash
# Probe (v): what a collision looks like to a B#-emitted call.
# bsc cannot be built on this machine (needs OTP 27+ leex), so the callers below are HAND-WRITTEN Erlang in the shape
# the F11/F62 feature files say bsc emits.  This is a SIMULATION of emitted shape, not bsc output.  Two designs:
#   SHIPPED-MODULE design (ticket 67's rejected build (a)): List.Reverse emits 'List':'Reverse'(Xs); a List.beam must ship.
#   AS BUILT (F62, compiler/features/F62-standard-signature-table.md): List.Reverse emits lists:reverse(Xs); nothing named 'List' exists.
# A user's own `module List` (bare: refused by bs_check:reserved_module_name/2 today; here assumed ALLOWED) would be 'List'.beam.
# Run: bash p5_emitted_call_collision.sh
set -u
T=$(mktemp -d); cd "$T"; mkdir stdlib user
cat > stdlib/List.erl <<'X'
-module('List').
-export(['Reverse'/1]).
'Reverse'(Xs) -> lists:reverse(Xs).
X
cat > user/List.erl <<'X'
-module('List').
-export(['Length'/1]).          % the user's own List module has a different API
'Length'(Xs) -> length(Xs) + 1000.
X
cat > caller_shipped.erl <<'X'
-module(caller_shipped).
-export([top/1]).
top(Xs) -> 'List':'Reverse'(Xs).        % shipped-module design
X
cat > caller_f62.erl <<'X'
-module(caller_f62).
-export([top/1]).
top(Xs) -> lists:reverse(Xs).           % as built
X
erlc -o stdlib stdlib/List.erl; erlc -o user user/List.erl; erlc caller_shipped.erl caller_f62.erl
run() { erl -noshell "$@" -eval '
  P = fun(Tag, F) -> io:format("  ~s: ~p~n", [Tag, catch F()]) end,
  P("shipped-design caller  ", fun() -> caller_shipped:top([1,2,3]) end),
  P("F62 (as built) caller  ", fun() -> caller_f62:top([1,2,3]) end),
  P("user List:Length([a])  ", fun() -> '"'"'List'"'"':'"'"'Length'"'"'([a]) end),
  halt().' 2>&1 | sed "s#$T/##g" | cut -c1-200; }
echo "=== A: only stdlib List.beam on path"; run -pa . -pa stdlib
echo "=== B: user List.beam FIRST (user shadows the shipped module by path order): shipped-design caller breaks, F62 caller does not"; run -pa . -pa stdlib -pa user
echo "=== C: stdlib first: the USER's own calls to List:Length now break instead"; run -pa . -pa user -pa stdlib
echo "=== D: is there any diagnostic at all? code:clash/0 (diagnostic offered by the VM; whether any build tool calls it is UNPROBED)"
erl -noshell -pa stdlib -pa user -eval 'code:clash(),halt().' 2>&1 | sed "s#$T/##g"
rm -rf "$T"
