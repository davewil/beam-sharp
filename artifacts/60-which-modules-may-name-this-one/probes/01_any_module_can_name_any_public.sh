#!/bin/bash
# (a) Today any module can name any public function; add_module_import reads only exports.
export PATH=/opt/otp28/bin:$PATH
HERE=$(cd "$(dirname "$0")" && pwd)
BSC=${BSC:-/home/user/beam-sharp/compiler/_build/default/bin/bsc}
SRC=${SRC:-/home/user/beam-sharp/compiler/src}
cd "$HERE/tree"
echo "## Acme.Billing is a SIBLING of Acme.Orders and reaches into Acme.Orders.Rules (the helper):"
$BSC -o /tmp/o60a --src-root . Acme/Billing Invoice "[1,2,3]"; echo "exit=$?"
echo
echo "## Acme.Reports has NO using line and names Acme.Orders.Rules.Recompute qualified:"
$BSC -o /tmp/o60b --src-root . Acme/Reports Digest "[4,5]"; echo "exit=$?"
echo
echo "## add_module_import at HEAD (what it reads) -- the whole function:"
awk '/^add_module_import\(M, World, Acc\)/,/^add_namespace_import/' $SRC/bs_check.erl | head -16
echo
echo "## every key the World entry carries (built in bsc.erl build/4):"
sed -n '/World1 = World#{Mod => #{/,/implements => bs_check:implements_of/p' $SRC/bsc.erl | grep -o '^ *[a-z_]* =>' | tr -d ' '
echo
echo "## occurrences of internal/friend/sealed/visible_to in src/ (case-insensitive, word-ish):"
grep -n -i -E "\b(internal|friend|sealed|visible_to)\b" $SRC/*.erl $SRC/*.yrl $SRC/*.xrl | head || true
echo "(end)"
