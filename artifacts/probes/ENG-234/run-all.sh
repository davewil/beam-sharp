#!/usr/bin/env bash
# Re-runs every ENG-234 probe; outputs land beside the scripts as *.rerun.out (originals *.out untouched for diffing).
cd "$(dirname "$0")"
for f in a_missing_app b_app_boot c_mix_undeclared d_elm_undeclared d2_elm_with_core d3_elm_undeclared_import e_cost f_beam_attr g_using_census a2_xref_dialyzer; do
  echo "== $f"; ./$f.sh > $f.rerun.out 2>&1; echo "exit=$?"
done
echo "Compare: for f in *.rerun.out; do diff <(sed -E 's#/tmp/tmp\.[A-Za-z0-9]+#TMP#g' \${f%.rerun.out}.out) <(sed -E 's#/tmp/tmp\.[A-Za-z0-9]+#TMP#g' \$f); done  (timings in e_cost will differ)"
