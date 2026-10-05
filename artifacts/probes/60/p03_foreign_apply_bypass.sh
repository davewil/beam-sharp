#!/usr/bin/env bash
# CLAIM: a compile-time who-may-name check is advisory against dynamic calls: B# can reach
# an exported function through a foreign `:erlang.apply` declaration, which names the
# callee only as run-time atoms, so no `using` (and therefore no check at the `using`
# line) is involved. Tested against each prototype (A subtree-by-path, B visible_to list,
# C internal marker).
# REFUTED IF: under any prototype the bypass module is refused at compile time or fails to
# return the callee's value, OR if the control (a direct `using` from the same outsider) is
# NOT refused (then the prototype proves nothing).
. "$(dirname "$0")/lib.sh"
fail=0
try() { # variant patch fixtureDir calleeDir outsiderDir bypassDir entry
    local v="$1" patch="$2" fx="$3" callee="$4" outs="$5" byp="$6" o="$WORK/p03_$1"
    build_variant "$v" "$patch" >/dev/null || { echo "build $v failed"; fail=1; return; }
    local B; B=$(bsc_of "$v"); rm -rf "${o:?}"; mkdir -p "$o"
    echo "=== $v"
    echo '--- control: outsider names the module with `using` (must be REFUSED)'
    (cd "$HERE/fixtures/$fx" && "$B" --src-root . -o "$o" "$outs" Peek "[1,2,3]" 2>&1 | head -3); 
    (cd "$HERE/fixtures/$fx" && "$B" --src-root . -o "$o" "$outs" >/dev/null 2>&1); crc=$?
    echo "control exit=$crc"
    echo '--- bypass: same outsider reaches it via :erlang.apply (foreign declaration, run-time atoms)'
    (cd "$HERE/fixtures/$fx" && "$B" --src-root . -o "$o" "$callee" >/dev/null 2>&1)
    out=$(cd "$HERE/fixtures/$fx" && "$B" --src-root . -o "$o" "$byp" Peek "[1,2,3]" 2>&1); brc=$?
    echo "$out"; echo "bypass exit=$brc"
    { [ "$crc" -ne 0 ] && [ "$brc" -eq 0 ] && [ "$out" = "6" ]; } || fail=1
}
try pA A.patch shop  Shop/Internal Outsider Bypass2
try pB B.patch shopB Shop/Orders   Outsider Bypass
try pC C.patch shopC Shop/Orders   Outsider Bypass
[ $fail -eq 0 ]; verdict "compile-time-check-is-bypassable-by-foreign-apply" $?
