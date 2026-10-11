#!/usr/bin/env bash
# Probe (f): is ticket 24 sec.2's `unclassified` helper case solved today, by F12 alone?
# One command:  ./f_unclassified_helper.sh
HERE=$(cd "$(dirname "$0")" && pwd); OUT=$(mktemp -d)
source ${BS_ENV:-/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh}
cd "$HERE/proj_f"
echo "### F12 era: --api of Cart (what the boundary manifest advertises)"
"$HERE/bsc2" --api -o "$OUT" --src-root . Cart 2>&1
echo
echo "### (1) test module in another directory names the PRIVATE helper Recompute -> expect refusal"
"$HERE/bsc2" -o "$OUT" --src-root . CartTest 2>&1
echo
echo "### (2) test module names the PUBLIC CALLBACK HandleCall -> expect NO error (24 sec.1 says it is 'not a test target'; nothing enforces it)"
"$HERE/bsc2" -o "$OUT" --src-root . CartTest2 TestsCallback 7 2>&1
echo
echo "### (3) NEGATIVE CONTROL: make Recompute public; the same test now compiles -> shows (1) was refused for privacy, not for another reason"
mkdir -p "$OUT/ctl" && cp -r "$HERE/proj_f/." "$OUT/ctl/" && sed -i 's/^private int Recompute/public int Recompute/' "$OUT/ctl/Cart/Cart.bs"
(cd "$OUT/ctl" && "$HERE/bsc2" -o "$OUT/ctlout" --src-root . CartTest TestsHelper 4 2>&1)
echo
echo "### (4) a test FILE placed inside Cart/ declaring 'module Cart' joins the production module and reaches the private helper"
mkdir -p "$OUT/in" && cp -r "$HERE/proj_f/." "$OUT/in/"
cat > "$OUT/in/Cart/TestRecompute.bs" <<'EOT'
module Cart

public int TestRecompute(int s)
TestRecompute(s) -> Recompute(s)
EOT
(cd "$OUT/in" && "$HERE/bsc2" -o "$OUT/inout" --src-root . Cart TestRecompute 9 2>&1 && "$HERE/bsc2" -o "$OUT/inout" --src-root . Cart 2>&1; ls "$OUT/inout")
erl -noshell -pa "$OUT/inout" -eval 'E = (list_to_atom("Cart")):module_info(exports), io:format("Cart.beam exports (the test function ships in the production beam): ~ts~n",[[io_lib:format("~ts/~p ",[N,A]) || {N,A} <- E, N =/= module_info]]),halt().'
