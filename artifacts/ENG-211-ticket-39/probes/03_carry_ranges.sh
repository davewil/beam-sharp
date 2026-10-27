#!/usr/bin/env bash
# ticket 39 §3.3. Hypothesis H3: the optimizer can be handed a range fact through (a) a -spec, (b) a range
# guard on an exported entry, (c) an is_integer guard. For each, does {tr,..}/var_info on the operand of an
# arithmetic BIF in the body gain a range it lacked? Falsified per carrier if the body's t_integer stays `any`.
# Body under test: f(N) -> (N + 1) rem 7.   N's range decides the {tr} on the `+` and `rem` operands.
set -e
W=/tmp/claude-0/-home-user-beam-sharp/e165fddb-d743-5cdb-816c-e9e70eb257c6/scratchpad/bsc39/v03; rm -rf $W; mkdir -p $W; cd $W
mk() { # name, spec line, guard
cat > $1.erl <<EOF
-module($1).
-export([f/1]).
$2
f(N) $3 -> (N + 1) rem 7.
EOF
}
mk c0_plain   ""                                  ""
mk c1_spec    "-spec f(0..99) -> 0..6."           ""
mk c2_isint   ""                                  "when is_integer(N)"
mk c3_range   ""                                  "when is_integer(N), N >= 0, N =< 99"
mk c4_both    "-spec f(0..99) -> 0..6."           "when is_integer(N), N >= 0, N =< 99"
for m in c0_plain c1_spec c2_isint c3_range c4_both; do
  erlc -S $m.erl; erlc $m.erl
  printf "%-10s beam=%4sB  " $m "$(stat -c%s $m.beam)"
  grep -E "gc_bif|is_integer|is_ge|is_lt|test," $m.S | sed 's/^ *//' | tr -s ' \n' ' ' | cut -c1-400; echo
done
echo "--- to_asm detail for c0 and c3"; sed -n '/^{function, f/,/^$/p' c0_plain.S c3_range.S
