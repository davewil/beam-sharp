#!/usr/bin/env bash
# Probe 59-A/B: forged values reaching a PRIVATE function through a nested position.
# Usage: source env.sh; ./run-behaviour.sh   (builds both compilers into a temp dir)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
"$HERE/build-compilers.sh" "$W/c" >/dev/null
for v in head narrow widen; do
  mkdir -p "$W/$v"
  "$W/c/$v/bsc" --src-root "$HERE/src" -o "$W/$v" "$HERE/src/Nested/Nested.bs" || exit 1
  "$W/c/$v/bsc" --src-root "$HERE/src" -o "$W/$v" "$HERE/src/IntNested/IntNested.bs" || exit 1
done
echo "=== emitted tag tests per build (Nested.beam: 'Kind' guards; IntNested.beam: is_integer tests) ==="
for v in head narrow widen; do
  n=$(escript "$HERE/dump.escript" "$W/$v/Nested.beam" | grep -c "map_get('Kind'")
  i=$(escript "$HERE/dump.escript" "$W/$v/IntNested.beam" | grep -c "is_integer")
  printf '  %-7s %s tag guard(s) in Nested; %s is_integer test(s) in IntNested\n' "$v" "$n" "$i"
done
cat > "$W/call.escript" <<'X'
#!/usr/bin/env escript
%% usage: call.escript EBIN
main([Ebin]) ->
  code:add_patha(Ebin),
  Good  = #{'Kind' => 'Nested.Line',  'Qty' => 2, 'Price' => 3},
  Evil  = #{'Kind' => 'Evil.Line',    'Qty' => 2, 'Price' => 3},
  Other = #{'Kind' => 'Nested.Order', 'Qty' => 2, 'Price' => 3, 'Id' => 1, 'Lines' => []},
  O = fun(Lines) -> #{'Kind' => 'Nested.Order', 'Id' => 1, 'Lines' => Lines} end,
  t("R1 control: well-formed order",                     fun() -> 'Nested':'Total'(O([Good])) end),
  t("R2 control: forged OUTER tag (exported guard)",     fun() -> 'Nested':'Total'((O([Good]))#{'Kind' := 'Evil.Order'}) end),
  t("R3 forged ELEMENT tag 'Evil.Line' in Lines",        fun() -> 'Nested':'Total'(O([Good, Evil])) end),
  t("R4 wrong-record element (an Order where Line due)", fun() -> 'Nested':'Total'(O([Other])) end),
  t("I1 control: Band(200)",                             fun() -> 'IntNested':'Band'(200) end),
  t("I2 control: Band(200.5) exported scalar",           fun() -> 'IntNested':'Band'(200.5) end),
  t("I3 Bands([200.5]) float nested, private Inner",     fun() -> 'IntNested':'Bands'([200.5]) end),
  t("I4 Bands([foo]) atom nested, private Inner",        fun() -> 'IntNested':'Bands'([foo]) end),
  t("I5 Bands([-3.5]) float nested below range",         fun() -> 'IntNested':'Bands'([-3.5]) end),
  t("I6 Bands([1000]) out-of-range int nested",          fun() -> 'IntNested':'Bands'([1000]) end).
t(L, F) ->
  R = try {ok, F()} catch C:E:St -> {C, E, case St of [{M,Fn,A,_}|_] -> {M,Fn,A}; _ -> none end} end,
  io:format("  ~-52s -> ~0p~n", [L, R]).
X
for v in head narrow widen; do
  echo; echo "=== build: $v ==="
  escript "$W/call.escript" "$W/$v"
done
