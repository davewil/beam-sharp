#!/usr/bin/env bash
# 59_entry_label.sh -- ticket 18 s1 / ticket 59 owes-item 2: "an exported function already pays its
# guard on calls from inside its own module (one entry label)". Tests it three ways:
#  (1) behaviour: OuterExp([1.5]) -- the guard-less Outer calling EXPORTED Inner locally -- must raise
#      function_clause; OuterPriv([1.5]) calling PRIVATE InnerP must return 1.5 (control).
#  (2) assembly: Inner/1 has exactly one func_info/label entry and the guard is_integer test is the
#      first instruction after it; OuterExp's local call targets that same label.
#  (3) pure Erlang control: same shape, `erlc -S`-level, so the claim is about the BEAM, not B#.
# REFUTED if OuterExp([1.5]) returns ok (the guard was skipped on the local call), or if the
# disassembly of Inner/1 shows two entry points.
set -u
cd "$(dirname "$0")"; . ./env.sh; . ./59_lib.sh
T=$(mktemp -d "${TMPDIR:-/tmp}/p59ent.XXXXXX"); mkdir -p "$T/head"
(cd 59_entry && "$BSC_HEAD" --src-root . -o "$T/head" E) || exit 1
echo "=== emitted guards (HEAD)"; ./59_guards.escript "$T/head/E.beam"
echo "=== behaviour (the B# source type-checks; the arguments are forged from Erlang)"
for c in "OuterExp [[1]]" "OuterExp [[1.5]]" "OuterPriv [[1]]" "OuterPriv [[1.5]]"; do
  set -- $c; ./59_call.escript "$T/head" E "$1" "$2"
done
echo "=== export table as stored in the file (function/arity -> entry label)"; ./59_expt.escript "$T/head/E.beam"
echo "=== assembly with labels: the local call in OuterExp targets the entry label of Inner"
./59_asm.escript "$T/head/E.beam" Inner/1 OuterExp/1 | sed -n '/^Inner/,$p'
echo "=== pure Erlang control"
mkdir -p "$T/erl"; cat > "$T/erl/c.erl" <<'ERL'
-module(c).
-export([inner/1, outer/1]).
inner(N) when is_integer(N) -> N.
outer([X|_]) -> inner(X).
ERL
(cd "$T/erl" && erlc +debug_info c.erl) && ./59_expt.escript "$T/erl/c.beam"; ./59_asm.escript "$T/erl/c.beam" inner/1 outer/1 | sed -n '/^inner/,$p'
