#!/usr/bin/env bash
# P9: PROTOTYPE of option A (callee-declared subtree) on a patched COPY of the compiler
# (scratchpad/60/proto, built from repo HEAD sources + 'within'/'only' decls; the repo is untouched).
# Env PROTO=1 uses the patched compiler; PROTO=0 uses the HEAD compiler as the control.
P=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad
HERE="$(cd "$(dirname "$0")" && pwd)"
export PATH=$P/beam/bin:$PATH LANG=C.UTF-8
EB=${PROTO_EBIN:-$P/60/proto/ebin}
bsc() { erl -noshell -pa $EB -eval 'bsc:main(init:get_plain_arguments()), halt(0).' -extra "$@"; }
cd "$(dirname "$0")/p9"
for t in "Shop/Reports" "Test/Shop/Orders" "Test/Shop/Orders2" "Test/Shop/Via" "Test/Shop/Via2"; do
  echo "## $t"; bsc --src-root src src/$t 2>&1 | head -6; echo "exit=${PIPESTATUS[0]}"
done
echo "## run Shop.Reports Gross 50 (allowed caller; value 50+10 + 10 = 70)"; bsc --src-root src src/Shop/Reports Gross 50
echo
echo "## CONTROL: same tree with the 'within Shop' line deleted, compiled by the HEAD compiler (must ACCEPT the intruder, proving the line is what refuses it)"
rm -rf /tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/60/p9ctl; cp -r "$HERE/p9" /tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/60/p9ctl
cd /tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/60/p9ctl
sed -i '/^within Shop$/d' src/Shop/Support/Math/Math.bs
EB=$P/bsc-build/ebin
for t in "Test/Shop/Orders2" "Test/Shop/Via"; do echo "## HEAD, no within: $t"; bsc --src-root src src/$t 2>&1 | head -4; echo "exit=${PIPESTATUS[0]}"; done
echo
echo "## --api of the restricted module under the patched compiler: does the manifest consumer (ticket 24 s6) see the restriction?"
EB=$P/60/proto/ebin; cd "$HERE/p9"; bsc --src-root src --api src/Shop/Support/Math 2>&1 | head
echo "## CONTROL: the same file under the HEAD compiler cannot even parse 'within' (confirms nothing at HEAD reads it)"
EB=$P/bsc-build/ebin; bsc --src-root src --api src/Shop/Support/Math 2>&1 | head -3
