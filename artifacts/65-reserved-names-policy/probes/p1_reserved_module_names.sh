#!/usr/bin/env bash
# P1: which bare module names does HEAD's bsc refuse? Control: Foo, Shop.List accepted.
# Layout per check-reserved-qualifiers.sh: --src-root src, module dir src/<M>.
S=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad
D=$S/65/p1; rm -rf $D; mkdir -p $D/src
for m in Map List Term Float String Binary Option Result Json Set Int Bool Atom Tuple Foo; do
  mkdir -p $D/src/$m; printf 'module %s\n\npublic int Go(int n)\nGo(n) -> n\n' $m > $D/src/$m/$m.bs
  echo "== module $m"; $S/bsc --src-root $D/src $D/src/$m Go 1 2>&1 | head -6
done
mkdir -p $D/src/Shop/List; printf 'module Shop.List\n\npublic int Go(int n)\nGo(n) -> n\n' > $D/src/Shop/List/List.bs
echo "== module Shop.List"; $S/bsc --src-root $D/src $D/src/Shop/List Go 1 2>&1 | head -6
# lowercase module names (the BEAM atoms of OTP's own modules): can B# even spell them?
mkdir -p $D/src/lists; printf 'module lists\n\npublic int Go(int n)\nGo(n) -> n\n' > $D/src/lists/lists.bs
echo "== module lists (lowercase)"; $S/bsc --src-root $D/src $D/src/lists Go 1 2>&1 | head -4 | sed "s#$S/65/##"
