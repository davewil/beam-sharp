#!/usr/bin/env bash
# p03 -- ticket 18 section 4 / 18a: "a non-exported function has the test elided entirely".
# Reproduce on OTP 28.5 with erlc -S, then ask the same of the tag test, then of what bsc emits.
# REFUTED claim "elided entirely" (as a general statement) if ANY of:
#   (c) a private callee reached from an unproven caller loses its test   [it must keep it]
#   (d) erlc elides the private record-tag test even though the caller proved it
# The 18a claim ITSELF is reproduced only if (a) keeps, (b) drops, (c) keeps the is_integer test.
. "$(dirname "$0")/lib.sh"; cd "$HERE"
O="$OUT/p03"; rm -rf "$O"; mkdir -p "$O"
erl -noshell -eval 'io:format("OTP ~s~n",[erlang:system_info(otp_release)]),halt().' | tee "$O/otp.txt"
erlc -S -o "$O" src/elide.erl
# one function's asm: from "{function, NAME," up to the next function
fn() { awk -v n="$1" '$0 ~ "^{function, "n","{p=1;print;next} /^{function,/{p=0} p' "$O/elide.S"; }
for f in ex_f lo_f un_f tag_f; do fn $f > "$O/$f.S"; echo "---- $f"; cat "$O/$f.S"; done
echo "## assertions (erlc)"
expect "a  exported callee keeps is_integer (called locally, proven)" "$O/ex_f.S" "is_integer"
absent "b  private callee, proven caller: is_integer elided"        "$O/lo_f.S" "is_integer"
expect "c  private callee, unproven caller: is_integer kept"        "$O/un_f.S" "is_integer"
expect "d  private callee, proven caller: record tag test KEPT (not elided)" "$O/tag_f.S" "is_eq_exact"
echo "## BEAM entry label: the local call from ex_caller targets the label that carries ex_f's guard"
fn ex_caller > "$O/ex_caller.S"; cat "$O/ex_caller.S"
CALL_LABEL=$(grep -Eo "call_only,1,\{f,[0-9]+\}" "$O/ex_caller.S" | grep -Eo "[0-9]+\}$" | tr -d '}')
ENTRY_LABEL=$(grep -Eo "^  \{label,[0-9]+\}" "$O/ex_f.S" | tail -1 | grep -Eo "[0-9]+")
echo "call_only target label=$CALL_LABEL  ex_f entry label (after func_info)=$ENTRY_LABEL" | tee "$O/labels.txt"
expect "local call lands on the label whose first instruction is the guard" "$O/labels.txt" "label=([0-9]+)  ex_f entry label \(after func_info\)=\1$"
echo "## bsc, option b emits is_integer on private InnerInt; does erlc drop it?"
mkdir -p "$O/b"; "$(bscv b)" -o "$O/b" src/Scope >/dev/null
./pp.escript "$O/b/Scope.abstr" > "$O/b/emitted.erl"
./dis.escript "$O/b/Scope.beam" 'InnerInt/1' 'InnerRec/1' > "$O/b/dis.txt"
expect "option b emits is_integer on private InnerInt in the Erlang forms" <(grep -A4 "^'InnerInt'" "$O/b/emitted.erl") "is_integer"
sed -n "/^== 'InnerInt'/,\$p" "$O/b/dis.txt" > "$O/b/innerint.txt"
absent "option b: erlc drops it from the beam (caller OuterInt proved it)" "$O/b/innerint.txt" "is_integer"
sed -n "/^== 'InnerRec'/,/^== 'InnerInt'/p" "$O/b/dis.txt" > "$O/b/innerrec.txt"
expect "option b: tag test stays in the beam" "$O/b/innerrec.txt" "is_eq_exact"
echo "p03 FAILS=$FAILS"; exit $FAILS
