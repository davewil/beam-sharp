#!/usr/bin/env bash
# Probe 59-E: ADJACENT finding. F3.9 says no tag test on a UNION record parameter.
# Does a forged map with no Kind at all reach an exported function over a union?
# Uses the repo's own examples/Shop (Amount(Doc d) -> d.Total) and a record parameter control.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
"$HERE/build-compilers.sh" "$W/c" >/dev/null
EX="$HERE/../../../compiler/examples"
"$W/c/head/bsc" --src-root "$EX" -o "$W/o" "$EX/Shop" >/dev/null || exit 1
cat > "$W/call.escript" <<'X'
#!/usr/bin/env escript
main([Ebin]) ->
  code:add_patha(Ebin),
  F = fun(L, Fn) -> R = try {ok, Fn()} catch C:E -> {C, E} end, io:format("  ~-60s -> ~0p~n", [L, R]) end,
  F("Squared(Order o), exported record param, forged Kind=Evil",   fun() -> 'Shop':'Squared'(#{'Kind' => 'Evil.Order', 'Id' => 1, 'Total' => 4}) end),
  F("Squared(Order o), no Kind key at all",                        fun() -> 'Shop':'Squared'(#{'Id' => 1, 'Total' => 4}) end),
  F("Amount(Doc d), exported UNION param, forged Kind=Evil",       fun() -> 'Shop':'Amount'(#{'Kind' => 'Evil.Order', 'Id' => 1, 'Total' => 4}) end),
  F("Amount(Doc d), exported UNION param, no Kind key at all",     fun() -> 'Shop':'Amount'(#{'Id' => 1, 'Total' => 4}) end).
X
escript "$W/call.escript" "$W/o"
