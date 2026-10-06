#!/usr/bin/env bash
# 59h — CLAIM: how much of the real exemplar corpus is touched by either scope choice?
# For every module under compiler/examples (compiled with --src-root examples), compile under
# cur / narrow / widen and report modules whose Code chunk changes: narrow removes private tag
# tests, widen adds private is_integer tests (after the BEAM optimiser has run). Whole-.beam
# bytes are not used (debug info differs); Code chunk md5 is. Compiling a module dir also writes
# the dependencies' beams, so each row sums every .beam it produced. compiler/examples/exemplars
# is skipped: those files are out of the walking-skeleton slice and do not compile (bsc says so).
# CONTROL: cur vs cur (compiled twice) must report 0 differing modules.
set -uo pipefail
source "${ENV_SH:-/tmp/claude-0/-home-user-beam-sharp/5c54aeca-205c-5959-b98d-85886863a86f/scratchpad/env.sh}"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
export ERL_CRASH_DUMP=/dev/null
cd "$REPO"; build_variants
EX="$REPO/compiler/examples"
code() { # $1 = out dir: total Code bytes and md5 over EVERY .beam written (a module dir may pull in its dependencies)
  erl -noshell -eval '[D]=init:get_plain_arguments(), Bs=lists:sort(filelib:wildcard(D++"/*.beam")),
    Cs=[begin {ok,{_,[{"Code",C}]}}=beam_lib:chunks(B,["Code"]), C end || B<-Bs],
    io:format("~p/~p ~s",[length(Bs), lists:sum([byte_size(C)||C<-Cs]), binary:part(base64:encode(crypto:hash(md5,Cs)),0,8)]), halt().' -extra "$1"; }
mods=$(cd "$EX" && find . -name '*.bs' -not -path './exemplars/*' -printf '%h\n' | sort -u | sed 's|^\./||')
tot=0; dn=0; dw=0; dc=0; bn=0; bw=0
printf '%-26s %-18s %-18s %-18s   (beams/Code-bytes md5)\n' module cur narrow widen
for m in $mods; do
  for v in cur cur2 narrow widen; do o="$WORK/c_${v}_${m//\//_}"; mkdir -p "$o"; src=$v; [ $v = cur2 ] && src=cur
    bsc_v $src "$EX" "$o" "$EX/$m" >/dev/null 2>&1; done
  c=$(code "$WORK/c_cur_${m//\//_}"); c2=$(code "$WORK/c_cur2_${m//\//_}")
  n=$(code "$WORK/c_narrow_${m//\//_}"); w=$(code "$WORK/c_widen_${m//\//_}")
  tot=$((tot+1)); [ "$c" != "$c2" ] && dc=$((dc+1)); [ "$c" != "$n" ] && dn=$((dn+1)); [ "$c" != "$w" ] && dw=$((dw+1))
  printf '%-26s %-18s %-18s %-18s\n' "$m" "$c" "$n" "$w"
done
echo "modules compiled: $tot ; Code changed by narrow: $dn ; by widen: $dw ; CONTROL cur-vs-cur2 changed: $dc"
