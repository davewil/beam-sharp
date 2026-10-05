#!/usr/bin/env bash
# Prototype each candidate rule (patches/A|B|C.patch) in the real checker and record which programs
# compile and which are refused, with the diagnostic text.
#   A: callee declares nothing; a module whose path has an `Internal` segment is nameable only from the segment's
#      parent and below. Decided from the two module atoms.          (patches/A.patch)
#   B: callee declares `visible_to P1, P2` in any file of its directory; an entry is a module OR a namespace
#      (namespace = subtree).                                         (patches/B.patch)
#   C: third visibility marker `internal` per function; scope fixed to "the callee module's parent namespace".
#                                                                     (patches/C.patch)
# Each case lists the exit code it MUST have for the prototype to be doing its job. The verdict is CONFIRMED only if every
# case matches; ONE mismatch REFUTES the claim "this prototype refuses exactly the intended callers".
. "$(dirname "$0")/lib.sh"
fail=0
case_() { # variant fixture module expect(0|1) [entry args...]
    local v="$1" fx="$2" m="$3" want="$4" B o; B=$(bsc_of "$v"); o="$WORK/p11_$v"; mkdir -p "$o"
    echo "--- [$v] $fx: bsc --src-root . $m   (expected exit $want)"
    out=$(cd "$HERE/fixtures/$fx" && "$B" --src-root . -o "$o" "$m" 2>&1); rc=$?
    [ -n "$out" ] && echo "$out" | sed 's/^/    /'
    echo "    exit=$rc"
    [ "$rc" -eq "$want" ] || { echo "    MISMATCH: wanted $want"; fail=1; }
}
build_variant pA A.patch >/dev/null && {
  echo "=========== A: Internal path segment"
  case_ pA shop Shop/Reports 0
  case_ pA shop Outsider 1
  case_ pA shop OutsiderNs 1
  case_ pA shop Outsider2 1
}
build_variant pB B.patch >/dev/null && {
  echo "=========== B: visible_to list (fixture shopB: Orders lists Shop.Billing, Shop.Reports)"
  case_ pB shopB Shop/Billing 0
  case_ pB shopB Shop/Reports 0
  case_ pB shopB Shop/Audit 1       # under Shop, NOT listed: refused, which a subtree rule would have allowed
  case_ pB shopB Outsider 1
  # OutsiderNs imports the namespace `Shop`, which pulls in every child incl. Audit: run it on a tree without Audit
  rm -rf "$WORK/shopB_noaudit"; cp -r "$HERE/fixtures/shopB" "$WORK/shopB_noaudit"; rm -rf "$WORK/shopB_noaudit/Shop/Audit"
  echo "--- [pB] shopB minus Audit: bsc OutsiderNs  (namespace-tier import, short-qualified call; expected exit 1)"
  out=$(cd "$WORK/shopB_noaudit" && "$(bsc_of pB)" --src-root . -o "$WORK/p11_pB" OutsiderNs 2>&1); rc=$?; echo "$out" | sed 's/^/    /'; echo "    exit=$rc"; [ $rc -eq 1 ] || fail=1
  echo "=========== B': same construct, entry is a NAMESPACE (visible_to Shop = a subtree)"
  case_ pB shopB2 Shop/Audit 0
  case_ pB shopB2 Outsider 1
}
build_variant pC C.patch >/dev/null && {
  echo "=========== C: internal marker, scope = parent namespace of the callee module"
  case_ pC shopC Shop/Reports 0
  case_ pC shopC OutsiderPub 0       # public Fetch from outside: fine
  case_ pC shopC Outsider 1          # internal fn, unqualified through using
  case_ pC shopC OutsiderQ 1         # internal fn, fully qualified
  case_ pC shopC OutsiderNs 1        # internal fn, namespace-tier short-qualified
}
[ $fail -eq 0 ]; verdict "each-prototype-refuses-exactly-the-intended-callers" $?
