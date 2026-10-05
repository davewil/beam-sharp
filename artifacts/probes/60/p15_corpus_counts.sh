#!/usr/bin/env bash
# See p15_corpus_counts.py for the claim and what would refute it.
. "$(dirname "$0")/lib.sh"
python3 "$HERE/p15_corpus_counts.py"; verdict "directory-path-alone-decides-a-subtree-rule" $?
