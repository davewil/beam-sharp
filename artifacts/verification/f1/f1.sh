#!/bin/sh
export BSC=/home/user/beam-sharp/compiler/_build/default/bin/bsc; . /home/user/beam-sharp/artifacts/probes/env.sh
W=$(mktemp -d); cd $W
erlc -o $W /home/user/beam-sharp/artifacts/probes/62/Shop.erl
cat > Hy.erl <<'E'
-module('Hy').
-export(['PKCS-1'/1, '1st'/1, 'A b'/1, 'New'/1]).
'PKCS-1'(X) -> {pkcs, X}.
'1st'(X) -> {first, X}.
'A b'(X) -> {ab, X}.
'New'(X) -> {n,X}.
E
erlc Hy.erl
try() { printf '%-36s -> ' "$1"; elixir -pa $W -e "IO.inspect($1)" 2>&1 | head -2 | tr '\n' ' ' | cut -c1-200; echo; }
try ':Shop."New"(1)'
try ':Shop.New(1)'
try ':Hy."PKCS-1"(1)'
try ':Hy.PKCS-1(1)'
try ':Hy."1st"(1)'
try ':Hy.1st(1)'
try ':Hy."A b"(1)'
try ':Hy.New(1)'
try ':Hy."New"(1)'
try ':"Hy"."PKCS-1"(1)'
