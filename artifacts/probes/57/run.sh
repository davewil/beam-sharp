#!/usr/bin/env bash
# run.sh -- re-execute every ticket-57 probe from scratch.
#   bash run.sh               everything, including the ~7 minute eunit step
#   SKIP_EUNIT=1 bash run.sh  everything except the eunit suites
# Sources env.sh (override with ENVSH=...), rebuilds every variant from a fresh
# COPY of the repo's compiler/ (the repo is never modified), and writes the raw
# output of each probe to out/NN_*.txt. Lines starting REFUTED are findings:
# the claim stated in that probe's header comment did not hold.
cd "$(dirname "$0")" || exit 1
rm -rf out; mkdir -p out
for p in 00_build 01_ticket_table 02_mechanism_ast 03_guard_today 04_variant_matrix \
         05_expression_typing 06_emission 07_residual 08_neighbours 09_measure 11_incidental 12_options 10_eunit; do
    echo "### $p"
    bash "$p.sh" > "out/$p.txt" 2>&1
    echo "    exit $?  ->  out/$p.txt   ($(grep -c '^REFUTED' "out/$p.txt") REFUTED lines)"
done
find out -name '*.beam' -delete
echo "### REFUTED lines, all probes:"; grep -h '^REFUTED' out/*.txt
