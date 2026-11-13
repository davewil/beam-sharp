#!/usr/bin/env bash
# PROTOTYPE 39a — does the 20% gap on the Day 1 hot loop still reproduce?
#
# Throwaway. Ticket 39, round 1 (2026-11-13). The ticket was written on
# 2026-08-15 at 18ca054. It measured beam-sharp 20% behind Erlang on
# aoc/bench's Day 1 loop and observed that Erlang's `spin/4` carried
# `{tr,{x,0},{t_integer,{0,99}}}` where beam-sharp's had a bare `{x,0}`.
# F12 shipped `public`/`private` two days later, and the benchmark source now
# marks six of its seven functions `private`. This probe measures what that
# left.
#
#   1. today's assembly for the benchmark, beside erlc's for bench_erl.erl
#   2. the same source with every `private` rewritten to `public`
#   3. bench_erl.erl compiled with +no_type_opt: Erlang with no annotations
#   4. the compiler at 18ca054 on the source of that day (skipped when the
#      clone is too shallow to hold the commit)
#   5. all of the above timed in one VM, the order reversed on alternate rounds
#
#   ./39a_the_hot_loop_today.sh
#
# Requires: OTP 28, rebar3, a built bsc. Elixir and Gleam are NOT timed: the
# ticket's own table puts them within 3% of Erlang, and Erlang is the control.
# Runs in a temp dir; step 4 adds and removes a detached git worktree there.
set -uo pipefail
export LC_ALL=C.UTF-8

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
COMPILER="$ROOT/compiler"
BSC="$COMPILER/_build/default/bin/bsc"
BENCH="$ROOT/aoc/bench"
INPUT="$ROOT/aoc/2025/Day01/input.txt"
OLD=18ca054
WORK="$(mktemp -d)"
cleanup() {
    [ -d "$WORK/old" ] && git -C "$ROOT" worktree remove --force "$WORK/old" >/dev/null 2>&1
    rm -rf "$WORK"
}
trap cleanup EXIT

if [ ! -x "$BSC" ]; then
    echo "building bsc..."
    (cd "$COMPILER" && rebar3 escriptize >/dev/null 2>&1)
fi

erl -noshell -eval 'io:format("OTP ~s, erts ~s, ~s, ~s~n",
    [erlang:system_info(otp_release), erlang:system_info(version),
     erlang:system_info(emu_flavor), erlang:system_info(system_architecture)]), halt().'
echo "compiler/ at $(git -C "$ROOT" rev-parse --short HEAD)"

# The body of one function from a .S file, without the line/location noise.
fn() { sed -n "/^{function, $2,/,/^\$/p" "$1" | grep -v -E '^\s*\{line,'; }

# The same, with labels, the module name and the function names' case removed,
# so an Erlang function and a B# one can be compared by `diff`.
norm() {
    fn "$1" "$2" | sed -E "s/\{f,[0-9]+\}/{f,N}/g; s/\{label,[0-9]+\}/{label,N}/g;
        s/^\{function, ([^,]+), ([0-9]+), [0-9]+\}/{function, \1, \2, N}/;
        s/'([A-Z][A-Za-z0-9]*)'/\L\1/g; s/part_two/parttwo/g; s/size_/size/g;
        s/\{atom,(bench_erl|day01)\}/{atom,M}/g"
}

cd "$WORK"
mkdir erl today pub notype

echo
echo "== 1. today's benchmark beside Erlang's =="
erlc -o erl "$BENCH/bench_erl.erl"
erlc -S -o erl "$BENCH/bench_erl.erl"
"$BSC" -o today "$BENCH/Day01" >/dev/null
(cd today && erlc -S +from_abstr Day01.abstr)
echo "--- 'Spin'/4 as bsc emits it today:"
fn today/Day01.S "'Spin'"
for pair in "wrap:'Wrap'" "hit:'Hit'" "spin:'Spin'" "clicks:'Clicks'" "part_two:'PartTwo'" "sign:'Sign'" "size_:'Size'"; do
    e="${pair%%:*}"; b="${pair##*:}"
    if diff <(norm erl/bench_erl.S "$e") <(norm today/Day01.S "$b") >/dev/null; then
        echo "  $e vs $b: identical, operand types included"
    else
        echo "  $e vs $b: DIFFERS"
    fi
done
echo "  t_integer annotations: Erlang $(grep -c t_integer erl/bench_erl.S), beam-sharp $(grep -c t_integer today/Day01.S)"

echo
echo "== 2. the same source, every function public =="
mkdir pub/Day01Pub
sed -e 's/^private /public /' -e 's/^module Day01/module Day01Pub/' "$BENCH/Day01/bench_bs.bs" > pub/Day01Pub/bench_bs.bs
"$BSC" -o pub pub/Day01Pub >/dev/null
(cd pub && erlc -S +from_abstr Day01Pub.abstr)
fn pub/Day01Pub.S "'Spin'"

echo
echo "== 3. Erlang with the type pass off =="
sed 's/-module(bench_erl)/-module(bench_erl_notype)/' "$BENCH/bench_erl.erl" > notype/bench_erl_notype.erl
(cd notype && erlc +no_type_opt bench_erl_notype.erl && erlc -S +no_type_opt bench_erl_notype.erl)
echo "  t_integer annotations: $(grep -c t_integer notype/bench_erl_notype.S)"

echo
echo "== 4. the compiler at $OLD, on that day's source =="
HAVE_OLD=no
if git -C "$ROOT" cat-file -e "$OLD^{commit}" 2>/dev/null &&
   git -C "$ROOT" worktree add --detach "$WORK/old" "$OLD" >/dev/null 2>&1 &&
   (cd "$WORK/old/compiler" && rebar3 escriptize >/dev/null 2>&1); then
    mkdir oldout
    "$WORK/old/compiler/_build/default/bin/bsc" -o oldout "$WORK/old/aoc/bench/bench_bs.bs" >/dev/null
    echo "--- the export attribute it emitted:"
    sed -n '/^{attribute,0,export,/,/}\.$/p' oldout/Day01.abstr
    sed "s/'Day01'/'Day01Old'/g" oldout/Day01.abstr > oldout/Day01Old.abstr
    (cd oldout && erlc +from_abstr Day01Old.abstr && erlc -S +from_abstr Day01Old.abstr)
    fn oldout/Day01Old.S "'Spin'"
    HAVE_OLD=yes
else
    echo "  skipped: $OLD is not in this clone (git fetch --shallow-since=2026-08-14 origin master)"
fi

echo
echo "== 5. timed: 25 runs a round, 6 rounds, order reversed on even rounds =="
cat > t39.erl <<'ERL'
-module(t39).
-export([main/1]).
-define(RUNS, 25).
-define(ROUNDS, 6).
main([Input | Mods]) ->
    Deltas = read(atom_to_list(Input)),
    Impls = [impl(M) || M <- Mods],
    [6770 = F(Deltas) || {_, F} <- Impls],
    io:format("~-22s ~s~n", ["", "min ms per round, then the best of them"]),
    Rounds = [[{N, lists:min([element(1, timer:tc(F, [Deltas])) || _ <- lists:seq(1, ?RUNS)])}
               || {N, F} <- order(R, Impls)] || R <- lists:seq(1, ?ROUNDS)],
    Best = [{N, lists:min([proplists:get_value(N, R) || R <- Rounds])} || {N, _} <- Impls],
    Base = lists:min([B || {_, B} <- Best]),
    [io:format("~-22s ~s  ~6.2f  ~.2fx~n",
               [N, [io_lib:format("~6.2f", [proplists:get_value(N, R) / 1000]) || R <- Rounds],
                B / 1000, B / Base]) || {N, B} <- Best],
    halt().
order(R, L) when R rem 2 =:= 0 -> lists:reverse(L);
order(_, L) -> L.
impl('Day01')    -> {"beam-sharp today",      fun 'Day01':'PartTwo'/1};
impl('Day01Pub') -> {"beam-sharp all public", fun 'Day01Pub':'PartTwo'/1};
impl('Day01Old') -> {"beam-sharp at 18ca054", fun 'Day01Old':'PartTwo'/1};
impl(bench_erl)  -> {"Erlang",                fun bench_erl:part_two/1};
impl(bench_erl_notype) -> {"Erlang +no_type_opt", fun bench_erl_notype:part_two/1}.
read(Path) ->
    {ok, Bin} = file:read_file(Path),
    [parse(L) || L <- string:split(binary_to_list(Bin), "\n", all), L =/= ""].
parse([$L | N]) -> -list_to_integer(N);
parse([$R | N]) -> list_to_integer(N).
ERL
erlc t39.erl
MODS="bench_erl Day01 Day01Pub bench_erl_notype"
PA="-pa erl -pa today -pa pub -pa notype"
[ "$HAVE_OLD" = yes ] && { MODS="$MODS Day01Old"; PA="$PA -pa oldout"; }
# shellcheck disable=SC2086
erl -noshell -pa . $PA -s t39 main "$INPUT" $MODS
