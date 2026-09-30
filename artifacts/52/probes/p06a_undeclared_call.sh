#!/usr/bin/env bash
# p06a: is a foreign module reachable WITHOUT a `using :m { }` block?  (If yes, the block is not the only place a
# foreign module is named and a check hung on it is incomplete.)
cd "$(dirname "$0")"
./bsc.sh --src-root programs programs/Undecl Total "[1,2]"; echo "exit=$?"
