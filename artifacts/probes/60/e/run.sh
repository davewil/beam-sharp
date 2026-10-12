#!/usr/bin/env bash
# 60/e : per-function export control is exported-vs-local; the BEAM has ONE entry label per function.
w=$(mktemp -d); trap 'rm -rf "$w"' EXIT; cd "$w"
cat > ex.erl <<'EOF'
-module(ex).
-export([f/0]).
f() -> g().
g() -> 1.
EOF
cat > ex2.erl <<'EOF'
-module(ex2).
-export([f/0, g/0]).
f() -> g().
g() -> 1.
EOF
for m in ex ex2; do erlc +to_asm $m.erl; erlc $m.erl; done
echo "== ex.S  (g/0 local)";  grep -n "^{module\|{exports\|{function\|{label" ex.S | head -20; sed -n '/{exports/,/]}\./p' ex.S | head -3
echo "== ex2.S (g/0 exported)"; grep -n "{exports\|{function\|{label" ex2.S | head -20
echo "== diff of the two assembler files: only the exports line (and the module name) differ"
diff <(sed 's/ex2/ex/g' ex2.S) ex.S
echo "== runtime: ex:g() from outside"; erl -noshell -pa . -eval 'io:format("~p~n",[catch ex:g()]), io:format("~p~n",[catch ex2:g()]), halt().'
echo "== beam_lib exports/locals"; erl -noshell -pa . -eval '[io:format("~p ~p~n",[M, M:module_info(exports)]) || M <- [ex,ex2]], halt().'
