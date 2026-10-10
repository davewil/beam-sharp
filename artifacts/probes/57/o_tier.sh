#!/usr/bin/env bash
# The documented O(n)-tier refinement: what does each compiler say to `int where WellFormed(value)`?
BSC=${1:?bsc}
W=$(mktemp -d); mkdir $W/P
printf 'module P\npublic atom WellFormed(int n)\nWellFormed(n) -> :yes\ntype Email = int where WellFormed(value)\npublic atom Take(Email e)\nTake(e) -> :ok\n' > $W/P/p.bs
(cd $W && "$BSC" -o $W/out P 2>&1 | head -3)
