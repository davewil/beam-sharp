#!/usr/bin/env bash
# 57_emit -- claim: the grammar fix changes the AST but not the emitted code (erlc folds {op,'-',5}
# either way). REFUTED by: differing .beam md5 or different `code` chunks between stock and gramA/gramB
# for the same source, or different run results.
# Control: a source with 1 - -5 and -(-5) and -2 * 3 that exercises the three parse shapes.
# usage: V57=<dir> 57_emit.sh
. "$(dirname "$0")/env.sh"; : "${V57:?}"
w=$(mktemp -d "${TMPDIR:-/tmp}/p57e.XXXXXX"); mkdir -p "$w/M"
cat > "$w/M/a.bs" <<'B'
module M
public int Lit()
Lit() -> -5
public int Sum(int n)
Sum(n) -> n + -5
public int Mix()
Mix() -> 1 - -5
public int Neg2()
Neg2() -> -(-5)
public int Mul()
Mul() -> -2 * 3
public int Div()
Div() -> -7 / 2
public int Rem()
Rem() -> -5 % 3
public int Big()
Big() -> -9223372036854775808
B
for v in stock stock gramA gramB gramC chk; do
  rm -rf "$w/out_$v"; mkdir -p "$w/out_$v"; "$V57/$v/_build/default/bin/bsc" -o "$w/out_$v" "$w/M" 2>&1 | head -3
  f=$(find "$w/out_$v" -name '*.beam' | head -1)
  echo "$v"; escript "$(dirname "$0")/57_emit.escript" "$w/out_$v" "$f"
done
