#!/usr/bin/env bash
# Probe (b): can a forged value reach a PRIVATE record-typed function, and what happens
# with / without the private tag test?   Run: ./probe_b_forged.sh  (needs ./build-variants.sh first)
cd "$(dirname "$0")"
W=${W:-/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/59/variants}
run() { # variant module fn arg
  BSC_EBIN=$W/$1/ebin ./bsc.sh --src-root src -o out_$1 src/$2 $3 "$4" 2>&1 | head -3
}
echo "### 0. what does bsc accept/refuse when an UNCHECKED value is handed to a private record fn?"
for m in Fwd Fwd2 Fwd3 Narrow; do echo "--- src/$m"; BSC_EBIN=$W/base/ebin ./bsc.sh --src-root src -o out_base src/$m 2>&1 | head -4; done
echo
echo "### 1. nested record: Entry(Batch b) -> Inner(b.First), Inner private (Order o)"
N_OK='{ Kind = :'"'Nest.Batch'"', Name = 1, First = { Kind = :'"'Nest.Order'"', Id = 1, Total = 9 } }'
N_FORGED_SAMEFIELDS='{ Kind = :'"'Nest.Batch'"', Name = 1, First = { Kind = :'"'Nest.Invoice'"', Id = 1, Total = 9 } }'
N_FORGED_NOFIELD='{ Kind = :'"'Nest.Batch'"', Name = 1, First = { Kind = :'"'Nest.Invoice'"', Id = 1 } }'
for v in base notag; do
  echo "[$v] well-formed        : $(run $v Nest Entry "$N_OK")"
  echo "[$v] wrong Kind, has Total: $(run $v Nest Entry "$N_FORGED_SAMEFIELDS")"
  echo "[$v] wrong Kind, no Total : $(run $v Nest Entry "$N_FORGED_NOFIELD")"
done
echo
echo "### 2. list<Order>: Entry(list<Order>) folds private Inner(Order o) over elements"
L_OK='[{ Kind = :'"'Lst.Order'"', Id = 1, Total = 9 }]'
L_F='[{ Kind = :'"'Lst.Order'"', Id = 1, Total = 9 }, { Kind = :'"'Lst.Invoice'"', Id = 1, Total = 5 }]'
L_F2='[{ Kind = :'"'Lst.Order'"', Id = 1, Total = 9 }, { Kind = :'"'Lst.Invoice'"', Id = 1 }]'
for v in base notag; do
  echo "[$v] well-formed          : $(run $v Lst Entry "$L_OK")"
  echo "[$v] 2nd elem wrong Kind, has Total: $(run $v Lst Entry "$L_F")"
  echo "[$v] 2nd elem wrong Kind, no Total : $(run $v Lst Entry "$L_F2")"
done
echo
echo "### 3. CONTROL: the same forged nested value, but NO function boundary -- projected inline in the exported fn"
D='{ Kind = :'"'Direct.Batch'"', Name = 1, First = { Kind = :'"'Direct.Invoice'"', Id = 1, Total = 9 } }'
for v in base notag; do echo "[$v] inline projection of wrong-Kind nested value: $(run $v Direct Entry "$D")"; done
echo "(the answer is the same under today's emitter: the private tag test only fires if the nested value is handed on)"
echo
echo "### 4. The int mirror: Sum(list<int>) -> private Bump(int n), a float forged into the list"
for v in base widen; do
  echo "[$v] Sum [1, 2]   : $(BSC_EBIN=$W/$v/ebin ./bsc.sh --src-root src -o out_$v src/ScopeI Sum '[1, 2]' 2>&1)"
  echo "[$v] Sum [1, 1.5] : $(BSC_EBIN=$W/$v/ebin ./bsc.sh --src-root src -o out_$v src/ScopeI Sum '[1, 1.5]' 2>&1)"
done
echo "(base: a function published list<int> -> int returns 4.5 -- ticket 18's outcome 3, reachable today through a private helper)"
echo
echo "### 5. CONTROL for 4: same float, NO private helper -- widening cannot reach it"
for v in base widen; do
  echo "[$v] ScopeJ.Sum [1, 1.5] (inline): $(BSC_EBIN=$W/$v/ebin ./bsc.sh --src-root src -o out_$v src/ScopeJ Sum '[1, 1.5]' 2>&1)"
done
