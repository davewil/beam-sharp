#!/usr/bin/env bash
# Claim (ticket 18 s1 / 59 owes #2): one entry label serves local and external calls; the BEAM's
# discriminator for "no guard needed" is exported-vs-local-only, not local-call-vs-remote-call.
set -u; HERE="$(cd "$(dirname "$0")" && pwd)"; W=$(mktemp -d); cd $W; cp "$HERE/entry.erl" .
erlc +to_asm entry.erl 2>&1; erlc +no_inline entry.erl 2>&1
echo "=== asm: ex/1 body and the two call sites ==="
grep -n -E "^\{function|\{label|is_integer|call|func_info" entry.S | sed -n 1,40p
echo "=== beam_disasm export table (name,arity,entry label) ==="
erl -noshell -eval '{beam_file,_,Exps,_,_,_} = beam_disasm:file("entry.beam"), io:format("~p~n",[Exps]), halt().'
echo "(local_caller calls {f,2}; remote_caller calls extfunc entry:ex/1; the export row for ex/1 names label 2)"
echo
echo "=== local-only guarded fns: which guard survives erlc? (entry2.erl) ==="
cp "$HERE/entry2.erl" .; erlc +to_asm entry2.erl 2>&1
awk '/^\{function, (loc_int|proven|unproven|loc_rec|rec_proven)/{p=1} /^\{function, module_info/{p=0} p' entry2.S | grep -E "^\{function|is_integer|is_eq_exact|get_map|bif.*map_get|call_only|var_info|\{call,"
