#!/usr/bin/env bash
# Static survey (grep of the UNMODIFIED repo sources) of every place that reads a comparand/constant
# or an e_neg/e_int node feeding alternatives/1. Output is line numbers, not behaviour.
repo=$(cd "$(dirname "$0")/../../.." && pwd); cd "$repo/compiler/src"
echo "== callers of alternatives/1 and the readers it uses (bs_check.erl)"
grep -n 'alternatives(\|comparison(\|int_cmp(\|flip(' bs_check.erl
echo "== every construction/consumption of e_neg across compiler/src"
grep -n 'e_neg' *.erl bs_parser.yrl
echo "== emitter mirrors of comparison/1 that match {e_int,_,_} literally"
grep -n '{e_int, _, _}\|{e_int, L, K}\|rel_expr\|kind_expr' bs_emit.erl
echo "== who calls refine/3 and the opaque_refinement diagnostic"
grep -n 'refine(\|opaque_refinement' bs_check.erl bs_diag.erl
echo "== parser productions that build p_int / p_rel / int_lit / e_int / negate"
grep -n "int_lit\|p_int\|p_rel\|e_int\|negate" bs_parser.yrl
echo "== other consumers of a refinement expr besides refine/3 and apply_guard/3"
grep -n 'type_refined' bs_check.erl bs_emit.erl bs_diag.erl bs_api.erl bs_lower.erl | head -20
