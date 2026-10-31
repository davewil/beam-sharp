#!/usr/bin/env bash
# p7: compiled-code cost of matching a tagged vs a bare lookup result at 20 call sites.
# Run: ./p7_code_cost.sh > p7_code_cost.out     (needs erlc, erl). Builds in a temp dir.
# Exit 1 if the tagged module is NOT larger-or-equal in instructions (the measurement can fail).
set -e
t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT; cd "$t"
gen() { # $1 = bare|tagged
  local m=p7_$1
  echo "-module($m). -export([run/1, lk/1, bench/1])."
  if [ "$1" = bare ]; then
    echo "lk(K) -> maps:get(K, persistent_term:get(m), nothing)."
  else
    echo "lk(K) -> case maps:find(K, persistent_term:get(m)) of {ok,V} -> {ok,V}; error -> absent end."
  fi
  echo "h(X) -> X + 1."
  echo -n "run(_) -> ["
  for i in $(seq 1 20); do
    [ $i -gt 1 ] && echo -n ", "
    if [ "$1" = bare ]; then
      echo -n "case lk(k$i) of nothing -> {miss,$i}; V$i -> {hit,h(V$i)} end"
    else
      echo -n "case lk(k$i) of absent -> {miss,$i}; {ok,V$i} -> {hit,h(V$i)} end"
    fi
  done
  echo "], K."
  echo "bench(0) -> ok; bench(N) -> _ = run(x), bench(N-1)."
}
gen bare > p7_bare.erl; gen tagged > p7_tagged.erl
# run/1 above returns K after building a list: make it return the list instead
sed -i 's/\], K\./]./' p7_bare.erl p7_tagged.erl
for m in bare tagged; do erlc -S p7_$m.erl 2>&1 | grep -v "^%" || true; erlc p7_$m.erl; done
echo "beam bytes:   bare=$(stat -c%s p7_bare.beam)  tagged=$(stat -c%s p7_tagged.beam)"
# instruction count inside run/1 only
# real instructions only: 4-space-indented lines that are not {'%',..} annotations or {line,..}
cnt() { awk '/^{function, run, 1/{f=1} /^{function, bench/{f=0} f && /^    [{a-z]/ && !/^    \{.%.,/ && !/^    \{line,/ {n++} END{print n}' "$1"; }
ib=$(cnt p7_bare.S); it=$(cnt p7_tagged.S)
echo "instructions in run/1:   bare=$ib  tagged=$it"
echo "-- ops per site in run/1 (histogram of opcode names, bare then tagged) --"
for m in bare tagged; do
  echo "[$m]"; awk '/^{function, run, 1/{f=1} /^{function, bench/{f=0} f && /^    [{a-z]/ && !/^    \{.%.,/ && !/^    \{line,/ {match($0,/[{]?[a-z_0-9]+/); print substr($0,RSTART,RLENGTH)}' p7_$m.S | sort | uniq -c | sort -rn | head -8
done
# timing: both modules, same map, 200k iterations of run/1 (20 lookups each), 5 repeats, microseconds
erl -noshell -eval '
  persistent_term:put(m, maps:from_list([{list_to_atom("k"++integer_to_list(I)), I} || I <- lists:seq(1,20,2)])),
  T = fun(M) -> lists:sort([element(1, timer:tc(fun() -> M:bench(200000) end)) || _ <- lists:seq(1,5)]) end,
  B = T(p7_bare), G = T(p7_tagged),
  io:format("run/1 x200000 us (sorted, 5 reps): bare=~w tagged=~w~n", [B, G]),
  io:format("median: bare=~w tagged=~w ratio=~.2f~n", [lists:nth(3,B), lists:nth(3,G), lists:nth(3,G)/lists:nth(3,B)]),
  halt().' -pa .
[ "$it" -ge "$ib" ] || { echo "ASSERT FAILS: tagged has fewer instructions than bare"; exit 1; }
echo "ASSERT holds: tagged instructions >= bare"
