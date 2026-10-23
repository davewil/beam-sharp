#!/usr/bin/env bash
# PROBE 64h — option (d): "absence is a value that cannot be a term".
# Part 1 (bsc): can the CURRENT lattice express a member outside `term`? Try every opaque kind and a fresh atom.
# Part 2 (erl): ILLUSTRATION ONLY, TRUE BY CONSTRUCTION. It stores the sentinel and reads it back; that it reads as
#               'absent' follows from `=:=` and proves nothing about B#. Not cited as evidence in the brief. The evidence
#               for option (d) is Part 1 alone (the lattice has no member outside term).
set -uo pipefail
: "${BSC:?source env.sh first}"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
decl() { # id, type decl
  mkdir -p "$W/$1"; printf 'module %s\n\n%s\n\npublic X Go(int id)\nGo(id) -> :nothing\n' "$1" "$2" > "$W/$1/$1.bs"
  out="$("$BSC" --api "$W/$1/$1.bs" 2>&1 | tr '\n' ' ' | sed 's/  */ /g')"
  printf '%-3s %-34s => %s\n' "$1" "$2" "${out:0:150}"
}
echo "== Part 1: unions of term with an opaque kind or a fresh atom (all should be absorbed) =="
decl A1 'type X = term | reference'
decl A2 'type X = term | pid'
decl A3 'type X = term | port'
decl A4 'type X = term | :absent_marker'
echo "== control: the same members without term are fine =="
decl B1 'type X = int | reference'
decl B2 'type X = binary | :absent_marker'
echo
echo "== Part 2 [ILLUSTRATION ONLY, true by construction; not evidence]: a unique-reference sentinel, in Erlang =="
cat > "$W/s.erl" <<'ER'
-module(s).
-export([main/0]).
%% the 'op' returns the sentinel for an absent key
lookup(K, M, Sent) -> maps:get(K, M, Sent).
main() ->
    Sent = make_ref(),
    M1 = #{a => 1},
    %% Control: never store the sentinel -> every answer is right.
    R1 = lookup(zzz, M1, Sent), R2 = lookup(a, M1, Sent),
    io:format("control (sentinel never stored): zzz -> ~s, a -> ~s~n",
              [tag(R1, Sent), tag(R2, Sent)]),
    %% Treatment: the caller gets the sentinel back as an ordinary value and stores it
    %% (the type of an option<term> result flows into a `term` parameter: Put(m2, k, r)).
    M2 = maps:put(copy, R1, M1),
    io:format("treatment (sentinel stored in M2 under `copy`): copy -> ~s  [stored a value; reads back as absent]~n",
              [tag(lookup(copy, M2, Sent), Sent)]),
    %% It also survives a serialisation round trip on the same node, so it cannot be 'kept out' by encoding.
    io:format("round trip through term_to_binary still equals the sentinel: ~p~n",
              [binary_to_term(term_to_binary(Sent)) =:= Sent]),
    halt().
tag(V, Sent) when V =:= Sent -> "absent";
tag(_, _) -> "present".
ER
( cd "$W" && erlc s.erl && erl -noshell -s s main )
