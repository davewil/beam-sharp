#!/usr/bin/env bash
# CLAIM (ticket 18 section 1, restated by ticket 60): the BEAM has ONE entry label per function, so a function
# that other modules may call must be EXPORTED, and an exported function pays the compiler's boundary guard
# on every call -- including calls from inside its own module. So candidate C (`internal` per function) cannot
# be "private plus a visibility rule": it costs the guard that `private` elides.
# REFUTED IF: the `internal` build of Bump/1 carries no more type tests than the `private` build, or `internal`
# is not in the export table.
. "$(dirname "$0")/lib.sh"
build_variant base >/dev/null || exit 1
build_variant pC C.patch >/dev/null || exit 1
T="$WORK/p13"; rm -rf "${T:?}"; mkdir -p "$T"
for vis in public private; do
  mkdir -p "$T/V_$vis"; cat > "$T/V_$vis/v.bs" <<EOT
module V_$vis

$vis int Bump(int n)
Bump(n) -> n + 1

public int Twice(int n)
Twice(n) -> Bump(Bump(n))
EOT
done
mkdir -p "$T/V_internal"; cat > "$T/V_internal/v.bs" <<EOT
module V_internal

internal int Bump(int n)
Bump(n) -> n + 1

public int Twice(int n)
Twice(n) -> Bump(Bump(n))
EOT
for vis in public private; do (cd "$T" && "$(bsc_of base)" --src-root . -o "$T/out_$vis" "V_$vis" >/dev/null 2>&1 || echo "compile V_$vis failed"); done
(cd "$T" && "$(bsc_of pC)" --src-root . -o "$T/out_internal" V_internal 2>&1 || echo "compile V_internal failed")
dis() { # beamdir module -> count of type tests and instructions inside Bump/1
  erl -noshell -eval '
    {beam_file,_,_Exp,_,_,Fs} = beam_disasm:file("'"$1"'/'"$2"'.beam"),
    [{function,_,1,_,Is}] = [F || {function,'"'"'Bump'"'"',1,_,_}=F <- Fs] ++ [],
    Tests = [I || I <- Is, element(1,I) =:= test],
    io:format("~s: exported=~p  type-tests-in-Bump/1=~p  instructions-in-Bump/1=~p~n",
       ["'"$2"'", lists:member({'"'"'Bump'"'"',1}, [{N,A}||{N,A}<-'"$3"']), length(Tests), length(Is)]),
    io:format("   tests: ~p~n", [[{element(2,T),element(3,T)} || T <- Tests]]).' -s init stop 2>&1
}
for vis in public private internal; do
  ex=$(erl -noshell -pa "$T/out_$vis" -eval 'io:format("~p",[[{N,A}||{N,A}<-'"'"'V_'"$vis"''"'"':module_info(exports), N=/=module_info]])' -s init stop)
  dis "$T/out_$vis" "V_$vis" "$ex"
done
echo "--- raw: Bump/1 disassembly, private vs internal"
for vis in private internal; do
  echo "== $vis"; erl -noshell -eval '{beam_file,_,_,_,_,Fs}=beam_disasm:file("'"$T/out_$vis/V_$vis"'.beam"), [io:format("~p~n",[I]) || {function,'"'"'Bump'"'"',1,_,Is}<-Fs, I<-Is].' -s init stop
done
tp=$(erl -noshell -eval '{beam_file,_,_,_,_,Fs}=beam_disasm:file("'"$T/out_private/V_private"'.beam"), [io:format("~p",[length([I||I<-Is,element(1,I)=:=test])]) || {function,'"'"'Bump'"'"',1,_,Is}<-Fs].' -s init stop)
ti=$(erl -noshell -eval '{beam_file,_,_,_,_,Fs}=beam_disasm:file("'"$T/out_internal/V_internal"'.beam"), [io:format("~p",[length([I||I<-Is,element(1,I)=:=test])]) || {function,'"'"'Bump'"'"',1,_,Is}<-Fs].' -s init stop)
echo "type tests: private=$tp internal=$ti"
[ "${ti:-0}" -gt "${tp:-0}" ]; verdict "internal-pays-the-boundary-guard-private-elides" $?
