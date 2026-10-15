#!/usr/bin/env bash
# 64_silent_routes.sh
# CLAIM (ticket 64 + F31 S5/S7): the collapse is "refused at the declaration". This probes the routes AROUND a
# written declaration, to find whether any still collapse silently at HEAD:
#   R1 user parametric alias  `type MyOpt<T> = T | :nothing` used at T=term     (F31 amended 2026-10-08 says "not measured")
#   R2 generic function `option<T> Wrap<T>(T x)` instantiated at T=term by inference at a call site
#   R3 the ticket's four-signature table (hand-rolled, option<int>, result<term,atom>, option<term>) in ONE module
#   R4 foreign (using :maps) signature returning option<term>
#   R5 control: the tagged shape `(:ok, term) | :absent` in a signature
# Output per route: bsc --api rc + first diagnostic line or the rendered API.
# REFUTES "refused everywhere" if any of R1/R2 prints ACCEPTED with a bare `term` return type.
# R2 runtime: Use(:nothing) printing 0 means a present :nothing is read as absent (silent collapse at a call site).
# REFUTES the control if R5 prints REFUSED.
. "$(dirname "$0")/env.sh"
W=$(bs_scratch); trap 'rm -rf "$W"' EXIT
run() { local d="$W/$1"; mkdir -p "$d"; cat > "$d/m.bs"; echo "== $1: $2"; $BSC --api "$d" 2>&1 | sed "s#$W/##g" | head -${3:-4}; echo "   rc=${PIPESTATUS[0]}"; }
run R1 "user parametric alias at term" <<'EOF2'
module R1

type MyOpt<T> = T | :nothing

public MyOpt<term> F(int n)
F(n) -> n
EOF2
run R2 "generic Wrap<T> returning option<T>, caller instantiates T=term" 6 <<'EOF2'
module R2

public option<T> Wrap<T>(T x)
Wrap(x) -> x

public int Use(term t)
Use(t) -> Wrap(t) switch { :nothing => 0, v => 1 }
EOF2
run R2b "same, caller instantiates T=int (control: expected ACCEPTED)" 6 <<'EOF2'
module R2b

public option<T> Wrap<T>(T x)
Wrap(x) -> x

public int Use(int t)
Use(t) -> Wrap(t) switch { :nothing => 0, v => 1 }
EOF2
run R3 "ticket's four signatures in one module" 12 <<'EOF2'
module R3

public :absent | (:ok, atom | int | list<term>) FindF(int k)
FindF(k) -> :absent

public option<int> FindI(int k)
FindI(k) -> :nothing

public result<term, atom> FindR(int k)
FindR(k) -> :nothing

public option<term> FindT(int k)
FindT(k) -> :nothing
EOF2
run R3b "same module WITHOUT the two collapsing signatures (control)" 12 <<'EOF2'
module R3b

public :absent | (:ok, atom | int | list<term>) FindF(int k)
FindF(k) -> :absent

public option<int> FindI(int k)
FindI(k) -> :nothing
EOF2
run R4 "foreign signature returning option<term>" <<'EOF2'
module R4

using :maps {
    option<term> get(term k, map<string, term> m)
}
EOF2
run R5 "control: tagged (:ok, term) | :absent" <<'EOF2'
module R5

public (:ok, term) | :absent Find(map<string, term> m, string k)
Find(m, k) -> :absent
EOF2
echo "== R2 runtime: Wrap<T>(t) at T=term, then switch on :nothing (the intent: 'present, whose value is :nothing')"
mkdir -p "$W/R2o"; "$BSC" -o "$W/R2o" "$W/R2" Use :nothing 2>&1 | tail -1   # expected by a careful author: 1 (present). collapse gives 0.
"$BSC" -o "$W/R2o" "$W/R2" Use :some 2>&1 | tail -1
