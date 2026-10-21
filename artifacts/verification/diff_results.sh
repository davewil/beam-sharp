#!/bin/sh
A=/home/user/beam-sharp/artifacts/probes/results; B=/home/user/beam-sharp/artifacts/verification/results
norm() { sed -E 's#/tmp/tmp\.[A-Za-z0-9]+#TMP#g; s#/tmp/[A-Za-z0-9_.-]*tmp[A-Za-z0-9_.-]*#TMP#g' "$1"; }
for f in $B/*.txt; do n=$(basename $f); echo "##### $n"; diff <(norm $A/$n) <(norm $f) && echo SAME; done
