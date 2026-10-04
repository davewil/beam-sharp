#!/usr/bin/env bash
# How OTP 28 treats a negative literal: parser leaves {op,_,'-',{integer,..}}; erl_lint folds it
# via erl_eval:partial_eval (stdlib-7.0/src/erl_lint.erl:2134-2147 patterns, :3432-3436 type ranges).
export PATH=/opt/otp28/bin:$PATH
d=$(mktemp -d); trap 'rm -rf $d' EXIT; cd $d
cat > nl.erl <<'ERL'
-module(nl).
-export([f/1,g/1,h/1,k/1]).
-type r() :: -5..5.
-type r2() :: (1+1)..(2*5).
-spec k(r() | r2()) -> ok.
k(_) -> ok.
f(X) when X >= -5 -> a;
f(_) -> b.
g(-5) -> m5;
g(2+3) -> five;
g(-(5)) -> also_m5;
g(_) -> o.
h(X) when X >= 2+3 -> big;
h(_) -> small.
ERL
echo "== erlc +to_core (no output = no warning/error)"; erlc +to_core nl.erl 2>&1
echo "== parser output, erl_parse"
erl -noshell -eval '
P=fun(S)->{ok,T,_}=erl_scan:string(S), io:format("~-28s ~p~n",[S, erl_parse:parse_exprs(T)]) end,
P("-5."), P("2+3."), P("-(5)."), P("- -5."), halt().'
echo "== BEAM asm: guard comparand and pattern are plain integer -5"
erlc -S nl.erl 2>/dev/null; grep -n "integer,-5\|integer,5" nl.S
echo "== Core Erlang: pattern literal and guard"
grep -n "<-5>\|<5>" nl.core
echo "== Core Erlang: guard comparand of f/1 (to_core runs after the Core optimisations, so this does not isolate v3_core from sys_core_fold)"
grep -n -B2 -A4 "when call .erlang.:.>=." nl.core
