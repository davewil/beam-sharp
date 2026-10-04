#!/bin/bash
# Probe 12 (d): call-time cost of the private-function guards in a hot private loop, on OTP 28.
# One B# source compiled by each compiler variant under a distinct, equal-length module name
# (HotB base, HotN narrow, HotW wide, and HotX = base again: the NOISE FLOOR - identical code, so
# any HotB-vs-HotX difference is measurement noise, not a guard).
#   Step(Order o, int acc)  private: record tag test (base,wide) / none (narrow)
#   Loop(Order o, int n, int acc) private recursive: acc is not provably an integer to the Erlang
#                           optimiser (it is `acc + o.Total`, a number), so wide keeps is_integer(acc) per iteration
#   HotE = the same Loop declared `public` under the CURRENT compiler: what the guards cost today when an author does not hide the worker.
# REPS interleaved rounds (variant order rotated every round) of N loop iterations each.
# Reported: per-iteration ns, median / min / max over rounds, and the spread. Quiet machine needed:
# run it alone (probe prints the load average).
cd "$(dirname "$0")"; . ./lib.sh
N=${N:-5000000}; REPS=${REPS:-25}
W=$(mktemp -d)
src() { cat <<BS
module $1
record Order { Id: int, Total: int }
int Step(Order o, int acc)
Step(o, acc) -> acc + o.Total
$2 int Loop(Order o, int n, int acc)
Loop(o, 0, acc) -> acc
Loop(o, n, acc) -> Loop(o, n - 1, Step(o, acc))
public int Run(Order o, int n)
Run(o, n) -> Loop(o, n, 0)
BS
}
mkdir -p $W/o
for pair in "base HotB private" "narrow HotN private" "wide HotW private" "base HotX private" "base HotE public"; do set -- $pair
  mkdir -p $W/$2; src $2 $3 > $W/$2/hot.bs; /tmp/p59/bin/bsc-$1 -o $W/o $W/$2 || exit 1
done
echo "loop functions as emitted (HotB=base, HotN=narrow, HotW=wide):"
for m in HotB HotN HotW HotE; do echo "--- $m"; abstr $W/o/$m.beam | grep -v '^$' | sed -n '/^.Step/,/^.Run/p' | sed '$d'; done
echo; echo "guard tests that SURVIVE in the BEAM code (disassembly), per function:"
for m in HotB HotN HotW HotE; do for f in "Step 2" "Loop 3"; do set -- $f; printf "  %s %s/%s  is_integer=%s  tag map_get('Kind')=%s\n" $m $1 $2 "$(asm $W/o/$m.beam $1 $2 | grep -c is_integer)" "$(asm $W/o/$m.beam $1 $2 | grep -c "'Kind'")"; done; done
echo; echo "load average before: $(cut -d' ' -f1-3 /proc/loadavg)   nproc=$(nproc)"
cat > $W/bench.erl <<'ERL'
-module(bench).
-export([main/1]).
main([NS, RS, Dir]) ->
    N = list_to_integer(NS), Reps = list_to_integer(RS),
    code:add_patha(Dir),
    Mods = ['HotB', 'HotN', 'HotW', 'HotX', 'HotE'],
    O = fun(M) -> #{'Kind' => list_to_atom(atom_to_list(M) ++ ".Order"), 'Id' => 1, 'Total' => 3} end,
    %% check the answers agree and warm up
    [ N3 = M:'Run'(O(M), 1000) || M <- Mods, N3 <- [3000] ],
    Time = fun(M) -> T0 = erlang:monotonic_time(nanosecond), R = M:'Run'(O(M), N), T1 = erlang:monotonic_time(nanosecond),
                     R = 3 * N, (T1 - T0) / N end,
    Rot = fun(L, K) -> {A, B} = lists:split(K rem length(L), L), B ++ A end,
    Rounds = [ [{M, Time(M)} || M <- Rot(Mods, I)] || I <- lists:seq(1, Reps) ],
    Per = fun(M) -> lists:sort([T || R <- Rounds, {M2, T} <- R, M2 =:= M]) end,
    Med = fun(L) -> lists:nth((length(L) + 1) div 2, L) end,
    io:format("~-6s ~10s ~10s ~10s ~10s   (ns per loop iteration; N=~w x ~w rounds, rotated order)~n",
              [mod, median, min, max, 'max-min', N, Reps]),
    Stats = [{M, Med(Per(M)), hd(Per(M)), lists:last(Per(M))} || M <- Mods],
    [io:format("~-6s ~10.3f ~10.3f ~10.3f ~10.3f~n", [M, Md, Mn, Mx, Mx - Mn]) || {M, Md, Mn, Mx} <- Stats],
    {_, B, _, _} = lists:keyfind('HotB', 1, Stats), {_, X, _, _} = lists:keyfind('HotX', 1, Stats),
    {_, Nn, _, _} = lists:keyfind('HotN', 1, Stats), {_, Wd, _, _} = lists:keyfind('HotW', 1, Stats),
    io:format("~nnoise floor (HotB vs HotX, identical code), median diff: ~.3f ns/iter~n", [B - X]),
    io:format("narrow - base (private tag test removed):        ~.3f ns/iter~n", [Nn - B]),
    io:format("wide   - base (private int kind test added):     ~.3f ns/iter~n", [Wd - B]),
    {_, E, _, _} = lists:keyfind('HotE', 1, Stats),
    io:format("exported Loop (today's cost of the same guards, base compiler) - base: ~.3f ns/iter~n", [E - B]),
    halt().
ERL
erlc -o $W $W/bench.erl && erl -noshell -pa $W -eval "bench:main([\"$N\",\"$REPS\",\"$W/o\"])" 
echo "load average after: $(cut -d' ' -f1-3 /proc/loadavg)"
