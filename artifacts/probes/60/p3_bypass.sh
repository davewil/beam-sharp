#!/bin/bash
# P3: can a compile-time caller-side check be bypassed on the BEAM? (unpatched bsc; the facts are about B# + BEAM, not about any option)
. "$(dirname "$0")/lib60.sh"
R=$(mktemp -d)
mk $R B 'module B

public int Pub(int n)
Pub(n) -> n + 1

private int Priv(int n)
Priv(n) -> n + 2

// hands a private function out as a value
public fn(int) -> int Handout()
Handout() -> Priv'
mk $R A_direct 'module A_direct
using B
public int Go(int n)
Go(n) -> B.Priv(n)'
mk $R A_value 'module A_value
using B
public fn(int) -> int Go()
Go() -> Priv/1'
mk $R A_viafun 'module A_viafun
using B
public int Apply(fn(int) -> int f, int n)
Apply(f, n) -> f(n)
public int Go(int n)
Go(n) -> Apply(B.Handout(), n)'
echo "--- 1. CONTROL: A names B.Priv directly (must be refused)"; cc $R A_direct 5 | grep -v Warning | head -3
echo "--- 2. CONTROL: A names Priv/1 in value position (unqualified, via using B) (must be refused)"; cc $R A_value | grep -v Warning | head -3
echo "--- 3. BYPASS: B.Handout() returns Priv as a fun; A calls it (accepted+runs => private body reached from outside)"
cc $R A_viafun Go 5 | grep -v Warning | head -3
echo "--- 4. runtime facts: exports of the emitted B.beam, and Erlang-side callers"
cc $R B >/dev/null
cat > $R/rt.erl <<'ERL'
-module(rt).
-export([main/0]).
main() ->
    M = list_to_atom("B"), Pub = list_to_atom("Pub"), Priv = list_to_atom("Priv"),
    io:format("B exports: ~p~n", [[E || E = {N,_} <- M:module_info(exports), N =/= module_info]]),
    io:format("erlang:apply(B,Pub,[1])         -> ~p~n", [erlang:apply(M, Pub, [1])]),
    io:format("dynamic M:F(A) of Pub           -> ~p~n", [M:Pub(1)]),
    io:format("apply Priv (unexported)         -> ~p~n", [catch erlang:apply(M, Priv, [1])]).
ERL
(cd $R && erlc rt.erl && erl -noshell -pa . -eval 'rt:main(), halt().')
rm -rf $R
