#!/usr/bin/env bash
# Probe (a): re-measure the ticket's checker claim at the current HEAD.
# One command:  ./a_checker_today.sh
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=${BS_SRC:-/home/user/beam-sharp/compiler/src}
OUT=$(mktemp -d)
bsc() { (cd "$HERE/proj_a" && "$HERE/bsc2" -o "$OUT" --src-root . "$@" 2>&1 | grep -v 'Warning: function .Hidden'); }
echo "### repo rev: $(git -C /home/user/beam-sharp rev-parse --short HEAD)"
echo
echo "### 1. grep for any who-may-name-me token in lexer/parser/checker (control: 'private' must match)"
for w in internal friend sealed visible_to visibleto restricted private; do
  printf '%-11s lexer:%s parser:%s checker:%s\n' "$w" \
    "$(grep -c -w "$w" $SRC/bs_lexer.xrl)" "$(grep -c -w "$w" $SRC/bs_parser.yrl)" "$(grep -c -w "$w" $SRC/bs_check.erl)"
done
echo
echo "### 2. where is add_module_import now? (ticket cites add_module_import/5 at 407-425)"
grep -n 'add_module_import\|^add_import\|^add_namespace_import' $SRC/bs_check.erl
echo
echo "### 3. Elsewhere (unrelated top-level module) names Shop.Orders.RecomputeTotal via using -> expect NO error"
bsc Elsewhere; echo "exit-ish: compiled files: $(ls $OUT | tr '\n' ' ')"
echo
echo "### 4. Qual: qualified call with NO using -> expect 'never imported' (so using is the only door)"
bsc Qual
echo
echo "### 5. Ns: 'using Shop' (a NAMESPACE) then Orders.RecomputeTotal -> expect NO error (second door, add_namespace_import)"
bsc Ns; echo "Ns compiled: $(ls $OUT | grep -c '^Ns.beam')"
echo
echo "### 6. NEGATIVE CONTROL: private function from another module IS refused (the 'what' half works)"
bsc ElsewherePriv
echo
echo "### 7. 'internal' as a modifier"
bsc Kw
echo
echo "### 8. A sibling FILE in Shop/Orders declaring 'module Shop.Orders' reaches a private function (F15 aggregate)"
bsc Shop/Orders Probe 5
