#!/usr/bin/env bash
# 57_build_variants -- builds four patched COPIES (plus stock) of compiler/ (never the repo's) and prints
# the bsc path of each. Claim: each prototype patch applies to HEAD and builds warnings-as-errors.
# REFUTED by: a patch failing to apply, or rebar3 failing. Prints "VARIANT name path" lines.
#   gramA = parser: negate/2 folds an integer literal (as it already folds a float literal)
#   gramB = parser: new yecc rule  expr_low -> '-' integer
#   gramC = parser: refinement-only fold (fold_refinement/1 on the refinement rule)
#   chk   = checker: const_int/1 fold in bs_check:comparison/1 (e_neg, +, -, *)
# usage: 57_build_variants.sh [WORKDIR]   (default: fresh mktemp); then export V57=WORKDIR
. "$(dirname "$0")/env.sh"
here=$(cd "$(dirname "$0")" && pwd)
W=${1:-$(mktemp -d "${TMPDIR:-/tmp}/p57w.XXXXXX")}
for v in stock gramA gramB gramC chk; do
  mkdir -p "$W/$v"; cp -r "$REPO"/compiler/{src,rebar.config,rebar.lock,test} "$W/$v/"
  rm -f "$W/$v/src/bs_parser.erl" "$W/$v/src/bs_lexer.erl"
  [ $v = stock ] || (cd "$W/$v" && patch -p2 -s < "$here/57_$v.patch")
  (cd "$W/$v" && rebar3 escriptize >"$W/$v.build.log" 2>&1) && echo "VARIANT $v $W/$v/_build/default/bin/bsc" || { echo "BUILD FAILED $v"; exit 1; }
done
echo "export V57=$W"
