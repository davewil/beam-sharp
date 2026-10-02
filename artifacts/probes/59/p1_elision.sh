#!/usr/bin/env bash
# P1 - does erlc elide a guard in a local-only function? (ticket 59 / 18 s1 cost "exported vs local-only")
# Claim under test (ticket 59 text): "a non-exported function has the test elided entirely".
# Falsifiers: E2/E4/E5/E6 would show is_integer=1 if erlc did NOT elide; T2 shows tagtest=1 which
# CONTRADICTS the claim for the record tag test (erlc does not track map-value types).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
W="${1:-$(mktemp -d)}"; mkdir -p "$W/p1"; cd "$W/p1" || exit 2
fail=0
mk() { cat > "$1.erl"; erlc -S "$1.erl" || { echo "COMPILE FAIL $1"; exit 2; }; }
cnt() { "$HERE/asm_count.escript" "$1.S" "$2" "$3" | tail -1; }
want() { # label module fun arity key expected
  got=$(cnt "$2" "$3" "$4" | sed -E "s/.*$5=([0-9]+).*/\1/")
  if [ "$got" = "$6" ]; then echo "ok   $1: $2:$3/$4 $5=$got"; else echo "FAIL $1: $2:$3/$4 $5=$got (expected $6)"; fail=1; fi
}
mk e_ex <<'X'
-module(e_ex).
-export([f/1, caller/1]).
f(X) when is_integer(X) -> X + 1.
caller(X) when is_integer(X) -> f(X).
X
mk e_lo <<'X'
-module(e_lo).
-export([caller/1]).
f(X) when is_integer(X) -> X + 1.
caller(X) when is_integer(X) -> f(X).
X
mk e_un <<'X'
-module(e_un).
-export([caller/1]).
f(X) when is_integer(X) -> X + 1.
caller(X) -> f(X).
X
mk e_lit <<'X'
-module(e_lit).
-export([caller/0]).
f(X) when is_integer(X) -> X + 1.
caller() -> f(1).
X
mk e_res <<'X'
-module(e_res).
-export([caller/1]).
f(X) when is_integer(X) -> X + 1.
g(X) when is_integer(X) -> X * 2.
caller(X) when is_integer(X) -> f(g(X)).
X
mk e_chain <<'X'
-module(e_chain).
-export([main/1]).
g(X) when is_integer(X) -> h(X) + 1.
h(X) when is_integer(X) -> X + 1.
main(X) when is_integer(X) -> g(X).
X
mk t_ex <<'X'
-module(t_ex).
-export([f/1, caller/1]).
f(M) when map_get(kind, M) == order -> map_get(id, M).
caller(M) when map_get(kind, M) == order -> f(M).
X
mk t_lo <<'X'
-module(t_lo).
-export([caller/1]).
f(M) when map_get(kind, M) == order -> map_get(id, M).
caller(M) when map_get(kind, M) == order -> f(M).
X
mk t_un <<'X'
-module(t_un).
-export([caller/1]).
f(M) when map_get(kind, M) == order -> map_get(id, M).
caller(M) -> f(M).
X
mk t_pat <<'X'
-module(t_pat).
-export([caller/1]).
f(#{kind := order, id := I}) -> I.
caller(#{kind := order} = M) -> f(M).
X
echo "-- integer kind test (is_integer)"
want E1-exported-caller-proves   e_ex    f 1 is_integer 1
want E2-local-caller-proves      e_lo    f 1 is_integer 0
want E3-local-caller-unknown     e_un    f 1 is_integer 1
want E4-local-literal-arg        e_lit   f 1 is_integer 0
want E5-local-arg-is-guarded-res e_res   f 1 is_integer 0
want E6a-local-chain-g           e_chain g 1 is_integer 0
want E6b-local-chain-h           e_chain h 1 is_integer 0
mk e_loop <<'X'
-module(e_loop).
-export([main/1]).
loop(N, A) when is_integer(N), is_integer(A), N > 0 -> loop(N - 1, A + N);
loop(_, A) -> A.
main(N) when is_integer(N) -> loop(N, 0).
X
mk r_lo <<'X'
-module(r_lo).
-export([caller/1]).
f(X) when is_integer(X), X >= 0, X =< 255 -> X.
caller(X) when is_integer(X), X >= 0, X =< 255 -> f(X).
X
mk r_un <<'X'
-module(r_un).
-export([caller/1]).
f(X) when is_integer(X), X >= 0, X =< 255 -> X.
caller(X) when is_integer(X) -> f(X).
X
want E7-private-recursive-loop    e_loop  loop 2 is_integer 0
echo "-- range test (X >= 0, X =< 255) in a local-only function"
want R1-local-caller-proves-range r_lo    f 1 cmp 0
want R2-local-caller-proves-kind-only r_un f 1 cmp 2
echo "-- record tag test (map_get(kind,M) == order)"
want T1-exported-caller-proves   t_ex    f 1 tagtest 1
want T2-LOCAL-caller-proves      t_lo    f 1 tagtest 1
want T3-local-caller-unknown     t_un    f 1 tagtest 1
echo "-- listing, T2 local f/1 (tag test survives although caller/1 tests the same thing):"
"$HERE/asm_count.escript" t_lo.S f 1 | sed -n 5,9p
echo "-- listing, E2 local f/1 (is_integer gone, only a var_info annotation):"
"$HERE/asm_count.escript" e_lo.S f 1 | sed -n 4,6p
t_pat_count=$(cnt t_pat f 1 | sed -E 's/.*instrs=([0-9]+).*/\1/')
echo "T4 pattern form #{kind := order} in local f/1: instrs=$t_pat_count (listing follows)"
"$HERE/asm_count.escript" t_pat.S f 1 | sed -n 4,12p
exit $fail
