#!/usr/bin/env bash
# P9b: option B (caller-declared `only`). Same patched compiler as p9.sh. Callee Math has NO `within` here.
P=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad
export PATH=$P/beam/bin:$PATH LANG=C.UTF-8
bsc() { erl -noshell -pa $P/60/proto/ebin -eval 'bsc:main(init:get_plain_arguments()), halt(0).' -extra "$@"; }
rm -rf $P/60/p9b; cp -r "$(dirname "$0")/p9" $P/60/p9b; cd $P/60/p9b
sed -i '/^within Shop$/d' src/Shop/Support/Math/Math.bs
for t in Test/Shop/B1 Test/Shop/B2; do echo "## $t"; bsc --src-root src src/$t 2>&1 | head -4; echo "exit=${PIPESTATUS[0]}"; done
