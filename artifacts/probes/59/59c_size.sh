#!/usr/bin/env bash
# 59c — CLAIM (ticket 59 "What this owes" 3): the tag test costs +14 bytes (flat in field count)
# and is_integer +3-5 bytes; so widening/narrowing the scope moves the .beam by about that per
# private function. Re-measured here, by diffing the .beam produced by three compilers
# (cur/narrow/widen, see lib.sh) over a generated module of K private record fns (3 fields)
# and K private int fns. Measures: .beam file bytes, stripped .beam bytes, `Code` chunk bytes
# (beam_lib:chunks), instruction count (beam_disasm). N=5 compiles per variant; the
# noise floor is whether the 5 outputs are byte-identical (a size measurement has noise 0
# iff they are). CONTROL: variant cur vs a second compile of cur must differ by 0 bytes.
set -uo pipefail
source "${ENV_SH:-/tmp/claude-0/-home-user-beam-sharp/5c54aeca-205c-5959-b98d-85886863a86f/scratchpad/env.sh}"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
export ERL_CRASH_DUMP=/dev/null; cd "$REPO"; build_variants
K=${K:-10}; N=${N:-5}
gen() { # $1 = K
  echo "module Many"; echo
  echo "record Order { Id: int, Total: int, Paid: int }"; echo
  for i in $(seq 1 $1); do
    echo "int R$i(Order o)"; echo "R$i(o) -> o.Total + $i"; echo
    echo "int I$i(int n)";   echo "I$i(n) -> n + $i"; echo
  done
  echo "public int Run(Order o, int n)"; echo -n "Run(o, n) -> 0"
  for i in $(seq 1 $1); do echo -n " + R$i(o) + I$i(n)"; done; echo
}
meas() { # $1=beam -> "<file bytes> <stripped bytes> <Code chunk bytes> <instrs> <Code md5>"
  erl -noshell -eval '
   [B]=init:get_plain_arguments(),
   {ok,{_,[{"Code",Code}]}}=beam_lib:chunks(B,["Code"]),
   {ok,Bin}=file:read_file(B), {ok,{_,Stripped}}=beam_lib:strip(Bin),
   {beam_file,_,_,_,_,Fs}=beam_disasm:file(B),
   NI=lists:sum([length([I||I<-Is,element(1,I)=/=label,element(1,I)=/=line,element(1,I)=/=func_info]) || {function,_,_,_,Is}<-Fs]),
   io:format("~p ~p ~p ~p ~s~n",[filelib:file_size(B),byte_size(Stripped),byte_size(Code),NI,
        binary:part(base64:encode(crypto:hash(md5,Code)),0,6)]), halt().' -extra "$1" 2>&1; }
for k in 1 $K; do
  mkdir -p "$WORK/src$k/Many"; gen $k > "$WORK/src$k/Many/many.bs"
  echo "### K=$k private record fns + $k private int fns"
  printf '%-8s %-4s %s\n' variant run 'beam stripped Code instrs Code-md5'
  for v in cur narrow widen; do
    for r in $(seq 1 $N); do
      mkdir -p "$WORK/o$k$v$r"; bsc_v $v "$WORK/src$k" "$WORK/o$k$v$r" "$WORK/src$k/Many" >/dev/null
      printf '%-8s %-6s %s\n' $v $r "$(meas "$WORK/o$k$v$r/Many.beam")"
    done
    echo "$v: distinct whole-.beam byte-streams over $N compiles: $(for r in $(seq 1 $N); do md5sum < "$WORK/o$k$v$r/Many.beam"; done | sort -u | wc -l); distinct sizes: $(for r in $(seq 1 $N); do stat -c %s "$WORK/o$k$v$r/Many.beam"; done | sort -u | wc -l)"
  done
done
echo "### Forge (src/Forge/forge.bs): the private fns here are fed by UNPROVEN values (list elements, nested fields)"
printf '%-8s %s\n' variant 'beam stripped Code instrs Code-md5'
for v in cur narrow widen; do
  mkdir -p "$WORK/of$v"; bsc_v $v "$PROBE/src" "$WORK/of$v" "$PROBE/src/Forge" >/dev/null
  printf '%-8s %s\n' $v "$(meas "$WORK/of$v/Forge.beam")"
done
echo "(Code-md5 equal for cur and widen on Many = the optimiser removed every private is_integer there;"
echo " on Forge it cannot, so widen costs real bytes exactly where the extra test is doing work.)"
