#!/usr/bin/env bash
# PROBE 62_erlang_caller (ticket 62): Erlang callers use the PascalCase export with
# ordinary syntax -- compiled by erlc, in a module, with the xref-visible export
# list. REFUTES "Erlang is unaffected" if erlc rejects the call syntax or the call
# is undef. Control: the snake_case spelling `'Shop':new(1)` must be undef
# against the STOCK compiler (the thing option 2 would add).
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
W="$(bs_scratch)"; trap 'rm -rf "$W"' EXIT
"$BSC" --src-root "$REPO/compiler/examples" -o "$W" "$REPO/compiler/examples/Shop" >/dev/null || exit 2
cat > "$W/ecall.erl" <<'ER'
-module(ecall).
-export([a/1, b/1]).
a(Id) -> 'Shop':'New'(Id).
b(Id) -> 'Shop':new(Id).
ER
erlc -o "$W" "$W/ecall.erl" && echo "erlc: compiled"
erl -noshell -pa "$W" -eval '
  io:format("ecall:a(1) -> ~p~n", [ecall:a(1)]),
  io:format("ecall:b(1) (control, snake spelling) -> ~p~n", [catch ecall:b(1)]), halt().' 2>&1
