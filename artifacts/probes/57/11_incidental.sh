#!/usr/bin/env bash
# 11 -- INCIDENTAL, found while probing `value == -3`; not part of ticket 57.
# Claim under test: a refinement that denotes exactly ONE integer cannot be
# declared on the unpatched compiler, whatever its sign, and the failure is the
# Erlang linter's "bad range type" on the emitted -spec (erl_lint.erl:3443,
# `when X < Y`), not the checker's opaque_refinement.
# REFUTES the claim: `value == 3` or `value >= 3 and value <= 3` being accepted,
# or the message being opaque_refinement's text.
. "$(dirname "$0")/lib.sh"
mk () { printf 'type T = int where %s\npublic int Id(T b)\nId(b) -> b' "$1"; }
for p in 'value == 3' 'value >= 3 and value <= 3' 'value >= 3 and value <= 4' 'value != 3'; do
  probe repo S "$(mk "$p")"; printf '%-30s %-9s %s\n' "$p" "$verdict" "$(head -1 "$OUT/cases/repo/S.out" | sed 's|.*/a.bs:||')"
done
probe repo S "$(mk 'value == 3')"; grep -q 'bad range type' "$OUT/cases/repo/S.out" && r=bad-range-type || r=other
expect "singleton refinement fails with erl_lint's message" bad-range-type $r
probe g1 S "$(mk 'value == -3')"; grep -q 'bad range type' "$OUT/cases/g1/S.out" && r=bad-range-type || r=other
expect "g1: the same failure for a negative singleton" bad-range-type $r
