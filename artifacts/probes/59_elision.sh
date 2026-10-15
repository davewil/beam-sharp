#!/usr/bin/env bash
# 59_elision.sh -- 18a s4 says erlc drops a private function's guard when every caller proves the
# type, and keeps it when a caller does not ("(b) elided / (c) paid"). Claim tested HERE, on the
# B#-emitted beams: does the same hold for (1) the is_integer test, (2) the record tag test?
# Prints the real BEAM code (beam_disasm) of the private callee in the proven and unproven case under
# ALL (int guard on every fn) and HEAD (tag test on every record fn).
# REFUTED if a test is present in the "proven" callee (nothing elided) or absent in the "unproven" one.
set -u
cd "$(dirname "$0")"; . ./env.sh; . ./59_lib.sh
T=$(mktemp -d "${TMPDIR:-/tmp}/p59eli.XXXXXX")
for V in HEAD ALL; do var=BSC_$V; mkdir -p "$T/$V"; (cd 59_elision && "${!var}" --src-root . -o "$T/$V" Q) || exit 1; done
echo "##### ALL: is_integer on every function"
./59_disasm.escript "$T/ALL/Q.beam" PI/1 PU/1
echo "##### HEAD: tag test on every record function"
./59_disasm.escript "$T/HEAD/Q.beam" PR1/1 PR2/1
echo "##### instruction counts, ALL vs HEAD compiled Q (int guards only differ)"
./59_size.escript "$T/HEAD/Q.beam" "$T/ALL/Q.beam"
