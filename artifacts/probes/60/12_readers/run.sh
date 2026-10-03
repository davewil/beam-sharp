#!/bin/sh
# Probe 60/12: what a THIRD visibility marker would have to touch. Counts every reader of the signature's visibility field.
# UNMEASURED beyond the grep: no `internal` marker was prototyped.
cd /home/user/beam-sharp/compiler/src
echo "commit $(git rev-parse --short HEAD)"
echo "== readers of the visibility value (=:= public / =/= public / =/= private / =:= private):"
grep -n '=:= public\|=/= public\|=:= private\|=/= private' bs_*.erl
echo "== the grammar's own productions:"
grep -n "visibility" bs_parser.yrl
echo "== where the add_module_import the ticket names lives now, and its arity:"
grep -n '^add_module_import\|add_module_import(' bs_check.erl
echo "== the single caller's Self parameter (what a caller-side rule needs):"
grep -n '^add_import(' bs_check.erl
