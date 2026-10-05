#!/usr/bin/env bash
# CLAIM (ticket 60): "a module controls what it exposes, never who may name it" --
# any module can `using` any other module and call its public functions.
# REFUTED IF: `Outsider` (not under Shop) cannot compile+run against Shop.Internal
# (public fn), OR if the checker source contains a who-may-name construct.
. "$(dirname "$0")/lib.sh"
build_variant base || exit 1
B=$(bsc_of base)
cd "$HERE/fixtures/shop" || exit 1
rm -rf "$WORK/o1"; mkdir -p "$WORK/o1"
echo '$ bsc --src-root . Outsider Peek "[1,2,3]"     # Outsider is NOT under Shop; Shop.Internal is public'
"$B" --src-root . -o "$WORK/o1" Outsider Peek "[1,2,3]"; rc=$?
echo "exit=$rc"
verdict "any-module-can-name-any-public-module" $rc

echo; echo '$ bsc --src-root . Shop/Reports        # sibling inside the Shop namespace (control)'
"$B" --src-root . -o "$WORK/o1" Shop/Reports; echo "exit=$?"

echo; echo '$ bsc --src-root . Outsider2 Peek ...   # no using line: fully-qualified call only'
"$B" --src-root . -o "$WORK/o1" Outsider2 Peek "[1,2,3]"; echo "exit=$? (expected 1: a call needs a using line -- F11)"

echo; echo '$ private callee from outside (the shipped *what* half, F12) -- control'
mkdir -p "$WORK/priv/Outsider3"
cp -r "$HERE/fixtures/shop/Shop" "$WORK/priv/"
cat > "$WORK/priv/Outsider3/P.bs" <<'EOT'
module Outsider3

using Shop.Internal

public int Peek(list<int> xs)
Peek(xs) -> Sum(xs, 0)
EOT
(cd "$WORK/priv" && "$B" --src-root . -o "$WORK/o1" Outsider3 Peek "[1,2,3]"); echo "exit=$?"

echo; echo "--- the checker source: any who-may-name construct? (word-boundary grep, case-insensitive)"
grep -n -i -w -E 'internal|friend|sealed|visible_to|friends' "$REPO/compiler/src/bs_check.erl" ; echo "(grep exit $?; hits above are comments, not constructs, if any)"
grep -n -i -w -E 'internal|friend|sealed|visible_to' "$REPO/compiler/src/bs_parser.yrl" "$REPO/compiler/src/bs_lexer.xrl"; echo "(parser/lexer grep exit $?; 1 = no keyword)"

echo; echo "--- where is add_module_import/5 NOW? (ticket cites bs_check.erl:407-425 at 0b761f6)"
grep -n '^add_module_import' "$REPO/compiler/src/bs_check.erl"
sed -n "$(grep -n '^add_module_import' "$REPO/compiler/src/bs_check.erl" | head -1 | cut -d: -f1),+14p" "$REPO/compiler/src/bs_check.erl"
