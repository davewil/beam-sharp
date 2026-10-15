#!/usr/bin/env bash
# 57_ast -- the parsed AST of the ticket's expression on stock / gramA / gramB (calls 57_ast.escript).
# Claim under test: ticket says `value >= -5` parses to {e_op,'-',{e_int,0},{e_int,5}}.
# REFUTED (stale) by: the stock block showing {e_neg,l,{e_int,l,5}} (it does, since F51).
# usage: V57=<dir> 57_ast.sh
. "$(dirname "$0")/env.sh"; : "${V57:?}"
for v in stock gramA gramB gramC; do echo "=== $v"; escript "$(dirname "$0")/57_ast.escript" "$V57/$v/_build/default/lib/bsc/ebin"; done
