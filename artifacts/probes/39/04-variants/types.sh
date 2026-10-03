#!/usr/bin/env bash
# What the variants did to the type annotations and instruction counts (needs ./run.sh's vbuild/).
set +e
source "$(dirname "$0")/../common.sh"; cd "$(dirname "$0")"
[ -d vbuild ] || ./run.sh >/dev/null 2>&1
printf '%-24s %6s %8s %6s %6s %s\n' variant beam_B tr_annot var_info instrs functions
for s in vbuild/*.S; do n=$(basename $s .S)
  tr=$(grep -o '{tr,' $s | wc -l); vi=$(grep -c "var_info" $s)
  ins=$(grep -cE '^ {4}(\{(gc_bif|bif|call|call_last|call_only|test|move|select_val|jump|get_|put_|allocate|deallocate|test_heap|init_yregs|swap|trim|is_)|return)' $s)
  fns=$(grep -o '^{function, *[^,]*, *[0-9]*' $s | grep -v module_info | sed 's/{function, *//; s/, */\//' | tr '\n' ' ')
  printf '%-24s %6s %8s %6s %6s %s\n' $n $(stat -c %s vbuild/$n.beam) $tr $vi $ins "$fns"
done
echo; echo "== Spin/4 in b0 (beam-sharp) vs e1 (Erlang, no_type_opt): are annotations really gone?"
for n in e1_erlang_no_type b2_bs_no_type; do echo "-- $n"; awk '/^\{function, *(spin|.Spin.), *4/{p=1} p{print} p&&/call_last/{exit}' vbuild/$n.S | grep -E "gc_bif|tr,|var_info" | head -8; done
echo; echo "== b5_bs_guard_fact: Spin after the guard-fact edit"
awk '/^\{function, *.Spin., *4/{p=1} p{print} p&&/call_last|call_only/{exit}' vbuild/b5_bs_guard_fact.S
