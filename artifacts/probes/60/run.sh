#!/usr/bin/env bash
# Re-executes every probe for ticket 60 from scratch. Raw output: out/<probe>.out
# (stdout+stderr) and out/<probe>.exit. No probe is allowed to be edited after
# seeing its output without an entry in CHANGELOG.md.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE" || exit 2
. ./lib.sh
mkdir -p out
rm -f out/*.out out/*.exit
echo "repo compiler/src fingerprint: $(cd "$REPO/compiler/src" && find . -type f \( -name '*.erl' -o -name '*.xrl' -o -name '*.yrl' \) ! -name bs_lexer.erl ! -name bs_parser.erl | sort | xargs sha256sum | sha256sum | cut -c1-16)" | tee out/_fingerprint.out
for p in p01 p02 p03 p04 p05 p06 p07 p08 p09 p10 p11 p12 p13 p14 p15 p16 p17; do
    f=$(ls "$HERE"/${p}_*.sh 2>/dev/null | head -1)
    [ -n "$f" ] || { echo "missing $p"; continue; }
    n=$(basename "$f" .sh)
    echo "== $n"
    bash "$f" > "out/$n.out" 2>&1
    echo $? > "out/$n.exit"
    grep -h '^VERDICT' "out/$n.out"
done
