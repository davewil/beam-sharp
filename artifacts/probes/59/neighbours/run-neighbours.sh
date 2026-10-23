#!/usr/bin/env bash
# Probe 59-D: the same nested-forgery question put to Gleam and Elixir.
# Usage: source env.sh; ./run-neighbours.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
echo "=== GLEAM $(gleam --version): records are tagged tuples; no guard on any function head ==="
cp -r "$HERE/gleam" "$W/g"
(cd "$W/g" && gleam build 2>&1 | grep -iE 'error|warning' | head -3)
cat > "$W/g/call.escript" <<'X'
#!/usr/bin/env escript
main([Ebin]) ->
  code:add_patha(Ebin),
  Good = {line,2,3}, Forged = {evil,2,3}, Plain = {order,9,9},
  F = fun(L, Fn) -> R = try {ok, Fn()} catch C:E -> {C, E} end, io:format("  ~-52s -> ~0p~n", [L, R]) end,
  F("control: well-formed order",                       fun() -> nested:total({order,1,[Good]}) end),
  F("forged ELEMENT {evil,2,3} -> private line_total",  fun() -> nested:total({order,1,[Forged]}) end),
  F("wrong-record element {order,9,9} where line due",  fun() -> nested:total({order,1,[Plain]}) end),
  F("forged OUTER {evil,1,[..]} -> exported total",     fun() -> nested:total({evil,1,[Good]}) end).
X
escript "$W/g/call.escript" "$W/g/build/dev/erlang/nested/ebin"
echo "  -- emitted functions (erl_pp of the shipped beam's abstract code):"
escript "$HERE/../dump.escript" "$W/g/build/dev/erlang/nested/ebin/nested.beam" | sed 's/^/     /' | head -30
echo
echo "=== ELIXIR $(elixir --version | tail -1): the author writes the struct pattern or gets no check ==="
elixir "$HERE/elixir/nested.exs" 2>&1 | grep -E '^  [a-z].* -> '
echo "  (Elixir 1.19's own set-theoretic checker also printed a compile-time warning on the forged OUTER call; elided here, see the run)"
