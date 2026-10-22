#!/usr/bin/env bash
# Probe 09 — ticket 59 quotes 26a: the tag test is "+14 bytes, flat in field count". Measure the private-function tag test (variant A minus B)
# on a 2-field and a 10-field record: Code-chunk bytes per function, and compile time of the whole module.
H="$(cd "$(dirname "$0")" && pwd)"; . "$H/lib.sh"
for V in "base:" "narrow:$H/patch-tag-exported-only.sh"; do IFS=: read -r N P <<<"$V"
  B=$(build_bsc "$N" "$P") || exit 1; O="$SCRATCH/o3-$N"; rm -rf "$O"; mkdir -p "$O"
  S=$(date +%s%N); $B --src-root "$H/src3" -o "$O" "$H/src3/T" || exit 1; E=$(date +%s%N)
  echo "--- $N : compile wall ms: $(( (E-S)/1000000 ))"
  erl -noshell -eval '
    F=hd(init:get_plain_arguments()), {ok,{_,[{"Code",C}]}}=beam_lib:chunks(F,["Code"]), io:format("Code chunk bytes (whole module): ~p  file bytes: ~p~n",[byte_size(C), filelib:file_size(F)]),
    {beam_file,_,_,_,_,Fs}=beam_disasm:file(F),
    [io:format("  ~s instrs=~p~n",[N2,length(Is)]) || {function,N2,_,_,Is} <- Fs, lists:member(N2,[(list_to_atom("P2")),(list_to_atom("P10"))])], halt().' -extra "$O/T.beam"
done
