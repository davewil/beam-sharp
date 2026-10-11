#!/usr/bin/env bash
# Probe (d, Erlang): is there ONE entry label for local and remote calls?  Is a guard on a
# LOCAL function elided?  Uses erlc -S (symbolic BEAM assembly).  Run from this directory.
cd "$(dirname "$0")"
source /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh
erlc -S ent.erl && echo "--- ent.S (functions) ---" && sed -n '/{function, pub/,$p' ent.S | grep -v "^$" | head -70
echo
echo "--- exports table (see {pub,1,2}: the export points at label 2, the code AFTER func_info) ---"
sed -n '/{exports/,/{labels/p' ent.S
erlc ent.erl
echo "--- real export table of the .beam (ExpT chunk): {Name,Arity,EntryLabel} ---"
erl -noshell -eval '{ok,{M,[{"ExpT",<<N:32,R/binary>>},{atoms,As}]}}=beam_lib:chunks("ent.beam",["ExpT",atoms]), AT=maps:from_list(As), [io:format("  ~p/~p -> entry label ~p~n",[maps:get(A,AT),Ar,L]) || <<A:32,Ar:32,L:32>> <= R], halt().'
erl -noshell -eval '{ok,{_,[{exports,E}]}}=beam_lib:chunks("ent.beam",[exports]), io:format("exports (name,arity) only: ~p~n",[E]), halt().' | head -3
echo "--- the LOCAL call from via_pub/1 to the exported pub/1 targets the same label: ---"
sed -n '/{function, via_pub/,/{function, module_info, 0/p' ent.S | grep -i "call"
echo "CONTROL (the detector can fail): compile a variant where loc/1 has no guard and diff the loc body"
sed 's/loc(X) when is_integer(X) ->/loc(X) ->/' ent.erl > ent2.erl; sed -i 's/-module(ent)/-module(ent2)/' ent2.erl; erlc -S ent2.erl
echo "loc/1 in ent.S (guarded) vs ent2.S (unguarded), lines with is_integer:"
grep -c "is_integer" ent.S ent2.S
echo
echo "--- is a guard on a LOCAL function elided by erlc? (ent3.erl: loc_known has only provable callers, loc_unknown has an unprovable one) ---"
erlc -S ent3.erl
for f in loc_known loc_unknown; do echo "$f: is_integer tests = $(awk -v f="$f" '/^\{function, /{on=($2==f",")} on' ent3.S | grep -c 'test,is_integer')"; done
