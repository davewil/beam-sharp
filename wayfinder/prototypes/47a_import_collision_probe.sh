#!/usr/bin/env bash
#
# 47a — Does any import collision in B# lack a legal spelling?
#
# Ticket 47 asks whether `using` gets an alias. Its owed item 3 claims an alias
# may be "not a convenience but the ONLY spelling" for a program whose name is
# reachable from two sources. This probe measures that claim against the
# compiler rather than reasoning about it.
#
# Seventeen shapes, each with an EXPECTED VERDICT pinned below. The fix belongs
# to a different ticket, so this probe is a record of what the compiler does
# TODAY: it goes red if a verdict moves in EITHER direction, which is what makes
# it evidence rather than a rubber stamp.
#
#   ./47a_import_collision_probe.sh
#
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BSC="$ROOT/compiler/_build/default/bin/bsc"
WORK="${TMPDIR:-/tmp}/bs47a.$$"

if [ ! -x "$BSC" ]; then
    echo "building bsc..."
    (cd "$ROOT/compiler" && rebar3 escriptize >/dev/null 2>&1)
fi
[ -x "$BSC" ] || { echo "FAIL: no bsc at $BSC"; exit 1; }

trap 'rm -rf "$WORK"' EXIT
SRC="$WORK/src"
mkdir -p "$SRC"

# ---------------------------------------------------------------- the callees
# Two modules with the same short name, each inside its own namespace, plus one
# TOP-LEVEL module with no namespace above it. All three export Sum/2.
for ns in Alpha Beta; do
    mkdir -p "$SRC/$ns/Coll/List"
    cat > "$SRC/$ns/Coll/List/list.bs" <<EOF
module $ns.Coll.List

public int Sum(list<int> xs, int acc)
Sum([], acc)          -> acc
Sum([x, ..rest], acc) -> Sum(rest, acc + x)
EOF
done

mkdir -p "$SRC/Solo"
cat > "$SRC/Solo/solo.bs" <<'EOF'
module Solo

public int Sum(list<int> xs, int acc)
Sum([], acc)          -> acc
Sum([x, ..rest], acc) -> Sum(rest, acc + x)
EOF

# ---------------------------------------------------------------- the consumers
mk() { mkdir -p "$SRC/$1"; cat > "$SRC/$1/$(echo "$1" | tr '[:upper:]' '[:lower:]').bs"; }

# Two NAMESPACE imports whose last segment collides, short name USED.
mk P1 <<'EOF'
module P1

using Alpha.Coll
using Beta.Coll

public int Go(int n)
Go(n) -> List.Sum([n], 0)
EOF

# The same collision, never used.
mk P1b <<'EOF'
module P1b

using Alpha.Coll
using Beta.Coll

public int Go(int n)
Go(n) -> n + 1
EOF

# Two MODULE-tier imports declaring the same {Name, Arity}, called unqualified.
mk P2 <<'EOF'
module P2

using Alpha.Coll.List
using Beta.Coll.List

public int Go(int n)
Go(n) -> Sum([n], 0)
EOF

# The same collision, never used.
mk P2b <<'EOF'
module P2b

using Alpha.Coll.List
using Beta.Coll.List

public int Go(int n)
Go(n) -> n + 1
EOF

# Both colliding modules imported, the call FULLY QUALIFIED.
mk P2c <<'EOF'
module P2c

using Alpha.Coll.List
using Beta.Coll.List

public int Go(int n)
Go(n) -> Alpha.Coll.List.Sum([n], 0)
EOF

# Fully qualified with NO `using` line: 41 §1 makes the line the dependency list.
mk P2d <<'EOF'
module P2d

public int Go(int n)
Go(n) -> Alpha.Coll.List.Sum([n], 0)
EOF

# A local RECORD named List beside a namespace import that binds `List`.
mk P3 <<'EOF'
module P3

using Alpha.Coll

record List { Id: int }

public int Go(int n)
Go(n) -> List.Sum([n], 0)
EOF

# The same file, using the RECORD rather than the module.
mk P3b <<'EOF'
module P3b

using Alpha.Coll

record List { Id: int }

public List Go(int n)
Go(n) -> List{ Id = n }
EOF

# An import and a local of the same NAME but different ARITY.
mk P4 <<'EOF'
module P4

using Alpha.Coll.List

public int Sum(int n)
Sum(n) -> n

public int Go(int n)
Go(n) -> Sum(n)
EOF

# Module-tier import of a name the module also declares, SAME arity.
mk P5 <<'EOF'
module P5

using Alpha.Coll.List

public int Sum(list<int> xs, int acc)
Sum(xs, acc) -> acc

public int Go(int n)
Go(n) -> Sum([n], 0)
EOF

# The same clash reached through the NAMESPACE tier instead.
mk P6 <<'EOF'
module P6

using Alpha.Coll

public int Sum(list<int> xs, int acc)
Sum(xs, acc) -> acc

public int Go(int n)
Go(n) -> List.Sum([n], 0) + Sum([n], 0)
EOF

# The hardest shape that still has a spelling: a local Sum/2 AND both colliding
# modules, all three reached at once.
mk P7 <<'EOF'
module P7

using Alpha.Coll
using Beta.Coll

public int Sum(list<int> xs, int acc)
Sum(xs, acc) -> acc

public int Go(int n)
Go(n) -> Alpha.Coll.List.Sum([n], 0) + Beta.Coll.List.Sum([n], 0) + Sum([n], 0)
EOF

# Is a fully-qualified call satisfied by a NAMESPACE import of its parent?
mk P8 <<'EOF'
module P8

using Alpha.Coll

public int Go(int n)
Go(n) -> Alpha.Coll.List.Sum([n], 0)
EOF

# THE LOCKOUT. A TOP-LEVEL module has no namespace above it, so the P6/P7/P8
# escape does not exist. Import it and the local Sum/2 refuses the import...
mk P9 <<'EOF'
module P9

using Solo

public int Sum(list<int> xs, int acc)
Sum(xs, acc) -> acc

public int Go(int n)
Go(n) -> Solo.Sum([n], 0) + Sum([n], 0)
EOF

# ...and drop the import to escape that, and the qualified call is refused.
mk P9b <<'EOF'
module P9b

public int Sum(list<int> xs, int acc)
Sum(xs, acc) -> acc

public int Go(int n)
Go(n) -> Solo.Sum([n], 0) + Sum([n], 0)
EOF

# Control for P5: the shadow fires even when the import is ONLY ever qualified,
# which is the very spelling the diagnostic recommends.
mk P10 <<'EOF'
module P10

using Alpha.Coll.List

public int Sum(list<int> xs, int acc)
Sum(xs, acc) -> acc

public int Go(int n)
Go(n) -> Alpha.Coll.List.Sum([n], 0)
EOF

# Does the lockout survive 41 §4's AGGREGATE shape — `using` in index.bs, one
# function per file? i.e. is the shadow check per-file or per-directory?
mkdir -p "$SRC/P11"
cat > "$SRC/P11/index.bs" <<'EOF'
module P11

using Solo
EOF
cat > "$SRC/P11/sum.bs" <<'EOF'
module P11

public int Sum(list<int> xs, int acc)
Sum(xs, acc) -> acc
EOF
cat > "$SRC/P11/go.bs" <<'EOF'
module P11

public int Go(int n)
Go(n) -> Solo.Sum([n], 0) + Sum([n], 0)
EOF

# ------------------------------------------------------------------ verdicts
# shape | expected exit | expected substring in the output
CASES="
P1|1|is ambiguous
P1b|0|4
P2|1|is ambiguous
P2b|0|4
P2c|0|3
P2d|1|called but never imported
P3|0|3
P3b|0|P3b.List
P4|0|3
P5|1|which this module also declares
P6|0|3
P7|0|6
P8|0|3
P9|1|which this module also declares
P9b|1|called but never imported
P10|1|which this module also declares
P11|1|which this module also declares
"

fails=0
count=0
while IFS='|' read -r shape want_code want_text; do
    [ -z "$shape" ] && continue
    count=$((count + 1))
    out=$("$BSC" --src-root "$SRC" "$SRC/$shape" Go 3 2>&1)
    code=$?
    if [ "$code" != "$want_code" ]; then
        echo "FAIL $shape: exit $code, expected $want_code"
        echo "$out" | sed 's/^/      /'
        fails=$((fails + 1))
    elif ! printf '%s' "$out" | grep -qF "$want_text"; then
        echo "FAIL $shape: output does not contain '$want_text'"
        echo "$out" | sed 's/^/      /'
        fails=$((fails + 1))
    else
        echo "ok   $shape (exit $code) $want_text"
    fi
done <<EOF
$CASES
EOF

echo
echo "--- what the verdicts say ---"
cat <<'SUMMARY'
Item 3's premise is FALSE. Every collision between two IMPORTS already has a
legal spelling, and the diagnostic names it:
  P1/P2  the collision is an error only where the name is USED (P1b, P2b pass),
  P2c    both colliding modules may be imported together and called in full,
  P7     a local Sum/2 and BOTH colliding modules coexist in one module.
So an alias is never the only spelling for an ambiguity.

But one shape has NO spelling at all, and it is not an ambiguity:
  P9     `using Solo` is refused because the module declares Sum/2, and
  P9b    dropping the import makes the qualified call unreachable (41 §1).
  P11    splitting across files does not help — the check is per-DIRECTORY.
A TOP-LEVEL module has no namespace above it, so P6/P8's escape (reach it
through the namespace tier, which writes `mods` and never `funs`) does not
exist. The module cannot be called at all.

P10 is the diagnostic defect: the shadow fires even when the import is only
ever called in full, which is exactly what its own message tells you to do.
SUMMARY

echo
if [ "$fails" -eq 0 ]; then
    echo "47a: $count/$count shapes hold their pinned verdict."
else
    echo "47a: $fails of $count shapes moved. A verdict changing in EITHER"
    echo "     direction is a finding — read it before editing this file."
    exit 1
fi
