#!/usr/bin/env bash
# The value-position half: is a negative literal accepted where a refinement admits it?
# Needs a compiler where `type Delta = int where value >= -100 and value <= 100` is writable (fixes A1 A2 B C).
BSC=${1:?bsc}
W=$(mktemp -d); mkdir $W/P
cat > $W/P/p.bs <<'EOS'
module P

type Delta = int where value >= -100 and value <= 100
type Positive = int where value > 0

public atom Take(Delta d)
Take(<= -1) -> :neg
Take(0) -> :zero
Take(>= 1) -> :pos

public atom Lit()
Lit() -> Take(-5)

public atom Lit2()
Lit2() -> Take(5)

public atom Bad()
Bad() -> Take(-500)

public atom Neg(Positive p)
Neg(p) -> :ok

public atom Ctl()
Ctl() -> Neg(-5)
EOS
(cd $W && "$BSC" -o $W/out P 2>&1 | head -30)
