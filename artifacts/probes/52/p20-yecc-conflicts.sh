#!/usr/bin/env bash
# P20: does the `using :M in :app { }` production add grammar conflicts? yecc on the stock grammar vs the patched grammar.
# Control: a deliberately ambiguous production added to a third copy must RAISE the count (else the probe cannot fail).
W=$(mktemp -d); cd "$W"
mkdir s p c
cp /home/user/beam-sharp/compiler/src/bs_parser.yrl s/
cp /tmp/bsb_52_x/bs_parser.yrl p/
cp /home/user/beam-sharp/compiler/src/bs_parser.yrl c/
# control: brace-less `using :atom` alongside the existing brace form AND a brace-less `using modpath`-like duplicate
sed -i "s|^using_decl -> 'using' modpath : {import, line('\$1'), modatom('\$2')}.|&\nusing_decl -> 'using' modpath : {import, line('\$1'), modatom('\$2')}.|" c/bs_parser.yrl
for d in s p c; do (cd $d; printf '%-8s ' $d; erl -noshell -eval 'yecc:file("bs_parser.yrl"), halt().' 2>&1 | grep -i conflicts || echo "no conflict line"); done
echo "(s = stock, p = patched with 'in :app', c = control with a duplicated production)"
