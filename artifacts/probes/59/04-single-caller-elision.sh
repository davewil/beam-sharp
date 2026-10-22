#!/usr/bin/env bash
# Probe 04 — ticket 59 quotes 18 §1: "the same code un-exported has the test elided entirely".
# Does erlc (this OTP 25) elide a private function's guard when its ONLY caller already proved the same fact?
# Fixture src2/T: Outer->Inner (record tag) and OuterI->Bump (refined int), one call site each. Variant C (wide) so Bump has a guard to elide.
H="$(cd "$(dirname "$0")" && pwd)"; . "$H/lib.sh"
B=$(build_bsc wide "$H/patch-int-everywhere.sh") || exit 1
O="$SCRATCH/o-single"; rm -rf "$O"; mkdir -p "$O"; $B --src-root "$H/src2" -o "$O" "$H/src2/T" || exit 1
echo "--- emitted (pre-erlc abstract code) ---"; pp_beam "$O/T.beam" | grep -v "^exports"
echo "--- after erlc (disassembly of Inner and Bump) ---"
erl -noshell -eval '
  {beam_file,_,_,_,_,Fs} = beam_disasm:file(hd(init:get_plain_arguments())),
  [io:format("~s:~n~p~n",[N,Is]) || {function,N,_,_,Is} <- Fs, lists:member(N,[(list_to_atom("Inner")),(list_to_atom("Bump"))])], halt().' -extra "$O/T.beam"
