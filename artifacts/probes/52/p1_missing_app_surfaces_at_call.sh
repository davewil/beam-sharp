#!/usr/bin/env bash
# p1 — what does the CURRENT compiler do about a dependency that is not installed?
# Claims (ticket 52 Question): "Compile it on a machine with a different ERL_LIBS and it fails at the call
# site with error:undef, having promised nothing."
#   C1  compile with the app ABSENT succeeds (the compiler consults nothing)
#   C2  run with the app ABSENT dies error:undef
#   C3  CONTROL: same source, app PRESENT on ERL_LIBS -> 42  (so C2 is the environment, not the source)
#   C4  the two .beam files are byte-identical: nothing about the environment is in the artefact
#   C5  the compiler does not even check a FUNCTION exists in a module that IS present (:lists.nope/0)
#   C6  a module that exists nowhere compiles too
source "$(dirname "$0")/common.sh"; mk_fakelib
bs_module Probe 'using :fakelib_mod {
    int hello()
}
public int Go()
Go() -> :fakelib_mod.hello()'
echo "== C1/C2 app absent"
out=$(env -u ERL_LIBS $BSC --src-root "$WORK/src" -o "$WORK/out_absent" "$WORK/src/Probe" 2>&1); echo "compile: exit=$? out=[$out]"
expect_empty "C1 compile succeeds with app absent (no diagnostics)" "$out"; [ -f "$WORK/out_absent/Probe.beam" ] && echo "ok  C1 beam produced" || { echo "!!  C1 no beam"; FAILS=$((FAILS+1)); }
run=$(env -u ERL_LIBS $BSC --src-root "$WORK/src" -o "$WORK/o2" "$WORK/src/Probe" Go 2>&1); echo "run: $run"
expect "C2 absent app -> error:undef at run time" "crashed: error:undef" "$run"
echo "== C3 control: app present"
run=$(ERL_LIBS="$WORK/libs" $BSC --src-root "$WORK/src" -o "$WORK/out_present" "$WORK/src/Probe" Go 2>&1); echo "run: $run"
expect "C3 present app -> 42" "42" "$run"
echo "== C4 artefact identical"
# (raw bytes differ only in the compile_info chunk, which records the -o directory; beam_lib:cmp ignores it)
r=$(beams_equal "$WORK/out_absent/Probe.beam" "$WORK/out_present/Probe.beam"); echo "beam_lib:cmp -> $r"
expect "C4 beams equal modulo compile_info" "ok" "$r"
echo "  (raw cmp, for the record:)"; cmp "$WORK/out_absent/Probe.beam" "$WORK/out_present/Probe.beam" || true
echo "  CONTROL: a beam for a different program must NOT compare equal"
bs_module Other 'public int Go()
Go() -> 7'
$BSC --src-root "$WORK/src" -o "$WORK/out_other" "$WORK/src/Other" >/dev/null 2>&1
r2=$(beams_equal "$WORK/out_absent/Probe.beam" "$WORK/out_other/Other.beam"); expect_not "C4-control different program differs" "ok" "$r2"
echo "== C5 function that does not exist, in a module that does"
bs_module Nope 'using :lists {
    int nope()
}
public int Go()
Go() -> :lists.nope()'
out=$($BSC --src-root "$WORK/src" -o "$WORK/o5" "$WORK/src/Nope" 2>&1); echo "compile: exit=$? out=[$out]"; expect_empty "C5 compiles" "$out"
run=$($BSC --src-root "$WORK/src" -o "$WORK/o5" "$WORK/src/Nope" Go 2>&1); expect "C5 dies at run time" "crashed: error:undef" "$run"
echo "== C6 module that exists nowhere"
bs_module Ghost 'using :no_such_module_anywhere {
    int hello()
}
public int Go()
Go() -> :no_such_module_anywhere.hello()'
out=$($BSC --src-root "$WORK/src" -o "$WORK/o6" "$WORK/src/Ghost" 2>&1); expect_empty "C6 compiles" "$out"
echo "== CONTROL that the harness can see a compile refusal at all"
bs_module Bad 'using :lists {
    int sum(list<int> xs)
public int Go()'
out=$($BSC --src-root "$WORK/src" -o "$WORK/o7" "$WORK/src/Bad" 2>&1); expect "control: a real syntax error IS refused" "error" "$out"
finish
