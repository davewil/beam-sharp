#!/usr/bin/env bash
# Probe 11 — the strongest cost objection to "wide": a hot private loop. Variants A (as built) vs C (int guard on private too), src4/T.
# Prints the private functions' emitted heads, the erlc-surviving test instructions, and 1e6-iteration timings (OTP 25, this VM).
H="$(cd "$(dirname "$0")" && pwd)"; . "$H/lib.sh"
for V in "base:" "wide:$H/patch-int-everywhere.sh"; do IFS=: read -r N P <<<"$V"
  B=$(build_bsc "$N" "$P") || exit 1; O="$SCRATCH/o4-$N"; rm -rf "$O"; mkdir -p "$O"; $B --src-root "$H/src4" -o "$O" "$H/src4/T" || exit 1
  echo "--- $N: emitted Loop/Step heads ---"; pp_beam "$O/T.beam" | grep -E -A4 "^'(Loop|Step|Walk)'\(" | head -30
  erl -noshell -eval '{beam_file,_,_,_,_,Fs}=beam_disasm:file(hd(init:get_plain_arguments())),
    [io:format("  ~s: ~p test/guard instrs~n",[N2,length([I||I<-Is,is_tuple(I),element(1,I)=:=test])]) || {function,N2,_,_,Is}<-Fs, lists:member(N2,[(list_to_atom("Loop")),(list_to_atom("Step")),(list_to_atom("Walk"))])], halt().' -extra "$O/T.beam"
done
"$H/hot.escript" "$SCRATCH/o4-base" "$SCRATCH/o4-wide"; "$H/hot.escript" "$SCRATCH/o4-base" "$SCRATCH/o4-wide"
