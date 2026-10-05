# lib.sh -- sourced by every probe. Sets env, paths, and helpers.
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "${W59_ENV:-/tmp/claude-0/-home-user-beam-sharp/c0642514-f9d1-5f22-91e2-015f96c1f119/scratchpad/env.sh}"
REPO=$(cd "$HERE/../../.." && pwd)
W=${W59_WORK:-/tmp/claude-0/-home-user-beam-sharp/c0642514-f9d1-5f22-91e2-015f96c1f119/scratchpad/w59/work}
REPO_BSC="$REPO/compiler/_build/default/bin/bsc"      # the oracle, as built in the repo
bscv() { echo "$W/$1/compiler/_build/default/bin/bsc"; }   # base | a | b | c
OUT="$HERE/out"; mkdir -p "$OUT"
FAILS=0
# expect NAME FILE PATTERN : PASS when PATTERN (egrep) is found in FILE, else FAIL (counts).
expect()  { if grep -Eq -- "$3" "$2"; then echo "PASS  $1"; else echo "FAIL  $1   (pattern not found: $3)"; FAILS=$((FAILS+1)); fi; }
# refute NAME FILE PATTERN : PASS when PATTERN is ABSENT.
absent()  { if grep -Eq -- "$3" "$2"; then echo "FAIL  $1   (unexpected: $3)"; FAILS=$((FAILS+1)); else echo "PASS  $1"; fi; }
