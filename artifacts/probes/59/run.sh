#!/usr/bin/env bash
# Ticket 59 probes: where does the record TAG guard land, what does it cost, and is the private one ever load-bearing?
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
BSC=${BSC:-$HERE/../../../compiler/_build/default/bin/bsc}
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
mkdir -p "$W/P59"
cat > "$W/P59/p59.bs" <<'B'
module P59

record Inner { N: int }
record Outer { Id: int, In: Inner }

// exported, record param: tag guard expected
public int Direct(Inner i)
Direct(i) -> i.N

// exported -> private, PASS-THROUGH of a nested field the exported guard cannot see
public int ViaPrivate(Outer o)
ViaPrivate(o) -> Helper(o.In)

private int Helper(Inner i)
Helper(i) -> i.N

// private called ONLY from within, with a value built here (checked call site)
public int Built(int n)
Built(n) -> Helper2(Inner{ N = n })

private int Helper2(Inner i)
Helper2(i) -> i.N
B
cd "$W" && "$BSC" P59 2>&1 | head -3
BEAMDIR=$(find "$W" -name 'P59.beam' -printf '%h\n' | head -1)
echo "=== P1: which functions carry the tag test? (abstract code of the emitted beam)"
erl -noshell -eval '
 {ok,{_,[{abstract_code,{_,AC}}]}} = beam_lib:chunks("'"$BEAMDIR"'/P59.beam",[abstract_code]),
 [io:format("~s/~p exported=~p guards=~p~n  ~p~n",[N,A,lists:member({N,A},Ex),[G||{clause,_,_,G,_}<-Cs],[P||{clause,_,P,_,_}<-Cs]])
   || {function,_,N,A,Cs} <- AC, Ex <- [[{N2,A2}||{attribute,_,export,L}<-AC,{N2,A2}<-L]]],
 halt().' 2>&1
echo "=== P2: forged NESTED record from an Erlang caller (outer tag right, inner tag wrong)"
erl -noshell -pa "$BEAMDIR" -eval '
 Good = #{'"'"'Kind'"'"' => '"'"'P59.Outer'"'"', '"'"'Id'"'"' => 1, '"'"'In'"'"' => #{'"'"'Kind'"'"' => '"'"'P59.Inner'"'"', '"'"'N'"'"' => 42}},
 Bad  = #{'"'"'Kind'"'"' => '"'"'P59.Outer'"'"', '"'"'Id'"'"' => 1, '"'"'In'"'"' => #{'"'"'Kind'"'"' => '"'"'Other.Inner'"'"', '"'"'N'"'"' => 666}},
 Try = fun(Name, F, A) -> R = (catch apply('"'"'P59'"'"', F, A)), io:format("~-34s ~p~n",[Name, element(1,{R})]) end,
 Try("ViaPrivate(good)", '"'"'ViaPrivate'"'"', [Good]),
 Try("ViaPrivate(forged inner)", '"'"'ViaPrivate'"'"', [Bad]),
 Try("Direct(forged)", '"'"'Direct'"'"', [maps:get('"'"'In'"'"', Bad)]),
 halt().' 2>&1
echo "=== P3: the same, with the private function's tag test REMOVED (variant patch, see variant-private-unguarded.diff)"
echo "    (run separately: BSC=<patched bsc> run.sh; compare P2 line 2)"
