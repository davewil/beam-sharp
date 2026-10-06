#!/usr/bin/env bash
# 59a — CLAIM (ticket 59 "The measurement"): bs_emit:boundary_guards gives a PRIVATE
# function the record TAG test but not the int KIND test; an EXPORTED function gets both.
# Re-run against the CURRENT compiler, 6 weeks after the ticket. Also looks at the final
# optimised BEAM code (not just the abstract code), in case the Erlang compiler elides it.
# CONTROL: the same greps are run on the exported functions; if the pattern were wrong
# the control rows would be FAIL.
set -uo pipefail
source "${ENV_SH:-/tmp/claude-0/-home-user-beam-sharp/5c54aeca-205c-5959-b98d-85886863a86f/scratchpad/env.sh}"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
OUT="$WORK/out"; mkdir -p "$OUT"
$BSC --src-root "$PROBE/src" -o "$OUT" "$PROBE/src/Scope" 2>&1 | grep -v 'is unused'
echo "--- emitted Erlang (abstract code in the .beam) ---"
show_fns "$OUT/Scope.beam" InnerTotal,InnerInt,OuterTotal,OuterInt,ViaTotal,ViaInt
echo "--- final optimised BEAM instructions (beam_disasm) ---"
erl -noshell -eval '
  {beam_file,_,_,_,_,Fs}=beam_disasm:file(hd(init:get_plain_arguments())),
  [begin io:format("~s/~p~n",[N,A]), [io:format("    ~p~n",[I]) || I<-Is, element(1,I)=/=line, element(1,I)=/=label, element(1,I)=/=func_info] end
   || {function,N,A,_,Is}<-Fs, lists:member(N,[(list_to_atom("InnerTotal")),(list_to_atom("OuterTotal")),(list_to_atom("InnerInt")),(list_to_atom("OuterInt"))])], halt().' -extra "$OUT/Scope.beam"
echo "--- assertions ---"
A=$(show_fns "$OUT/Scope.beam" InnerTotal);  B=$(show_fns "$OUT/Scope.beam" InnerInt)
C=$(show_fns "$OUT/Scope.beam" OuterTotal);  D=$(show_fns "$OUT/Scope.beam" OuterInt)
chk() { if [ "$2" = "$3" ]; then echo "PASS  $1 (expected=$2)"; else echo "FAIL  $1 expected=$2 got=$3"; fi; }
has() { grep -q "$2" <<<"$1" && echo yes || echo no; }
chk "private record fn has tag test"   yes "$(has "$A" "'Kind'")"
chk "private int fn has is_integer"    no  "$(has "$B" is_integer)"
chk "CONTROL exported record has tag"  yes "$(has "$C" "'Kind'")"
chk "CONTROL exported int is_integer"  yes "$(has "$D" is_integer)"
