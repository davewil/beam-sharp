#!/usr/bin/env bash
# P19: does bsc have a non-fatal diagnostic class? (matters: Elixir's precedent P5 is a WARNING with exit 0)
# NOTE: my first version grepped 'severity => warn' (0 hits) and would have concluded "no warnings". That was wrong:
# warnings are built from {warning, Line, Fn, _} tuples (bs_diag.erl:694). This version runs a real program instead.
. "$(dirname "$0")/../lib.sh"
cd /home/user/beam-sharp/compiler/src
echo "grep 'severity => warn' bs_diag.erl : $(grep -c 'severity => warn' bs_diag.erl) hits (misleading)"
echo "grep 'Sev =:= warning' bs_diag.erl  : $(grep -c 'Sev =:= warning' bs_diag.erl) hit  (the real producer)"
W=$(mktemp -d); cd "$W"; mkdir U C
# the exact example from LANGUAGE.md:1163-1169 (unreachable_arm is documented as a WARNING; control C has no dead arm)
printf 'module U\npublic atom F(atom a)\nF(a) -> a switch {\n    _  => :any,\n    :x => :ex\n}\n' > U/a.bs
printf 'module C\npublic atom F(atom a)\nF(a) -> a switch {\n    :x => :ex,\n    _  => :any\n}\n' > C/a.bs
for m in U C; do echo "--- $m"; bsc -o o_$m $m/a.bs 2>&1 | head -3; echo "rc=${PIPESTATUS[0]} beam_emitted=$(ls o_$m/*.beam 2>/dev/null | wc -l)"; done
