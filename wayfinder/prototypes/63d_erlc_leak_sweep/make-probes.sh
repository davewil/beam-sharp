#!/usr/bin/env bash
#
# 63d — WHICH ERLANG-COMPILER REFUSALS CAN REACH AN AUTHOR WHOSE PROGRAM CLEARED bs_check?
#
# ENG-256's first owed item. 63b found one leak (a local call in a guard) and
# measured nothing else. This writes one module per candidate, so `run.sh` can
# compile each with the built `bsc` and record whether a `compile:` line — the
# relay of OTP's own report text — reached stderr.
#
# Each probe is its own module directory (F15: a module is a directory named
# for it). The candidates are every expression node the grammar lets into a
# guard (a guard shares the whole expression grammar), the same call in a
# switch-arm guard, and the body-level linter faults that bs_check might not
# see: an unsafe variable, an unused binding, an unused private function, and
# a re-bound parameter. G14 is the control and must compile and run.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

mk() {
  local name="$1" file
  file="$name/$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]').bs"
  mkdir -p "$name"
  cat > "$file"
}

mk G01Call <<'EOF'
// G01 — a local call in a clause guard (63b's case).
module G01Call
public atom IsAdmin(int u)
IsAdmin(1) -> :yes
IsAdmin(_) -> :no
public atom Check(int u)
Check(u) when IsAdmin(u) == :yes -> :admin
Check(_)                         -> :ordinary
EOF

mkdir -p G02Qcall/Helper
cat > G02Qcall/Helper/helper.bs <<'EOF'
module G02Qcall.Helper
public atom IsAdmin(int u)
IsAdmin(1) -> :yes
IsAdmin(_) -> :no
EOF
cat > G02Qcall/g02qcall.bs <<'EOF'
// G02 — a qualified call to a sibling B# module in a guard.
module G02Qcall
public atom Check(int u)
Check(u) when Helper.IsAdmin(u) == :yes -> :admin
Check(_)                                -> :ordinary
EOF

mk G03ForeignBif <<'EOF'
// G03 — a foreign call in a guard whose target IS a BEAM guard BIF.
module G03ForeignBif
using :erlang {
    int byte_size(binary b)
}
public atom Check(binary b)
Check(b) when :erlang.byte_size(b) > 2 -> :long
Check(_)                               -> :short
EOF

mk G04ForeignNonBif <<'EOF'
// G04 — a foreign call in a guard whose target is NOT a guard BIF.
module G04ForeignNonBif
using :string {
    int length(binary s)
}
public atom Check(binary s)
Check(s) when :string.length(s) > 2 -> :long
Check(_)                            -> :short
EOF

mk G05Valve <<'EOF'
// G05 — a valve in a guard. `result<int, atom>` is `int | (:error, atom)`, so
// `Half` returns the int itself; the first draft returned `(:ok, u)` and failed
// its own return check, which measured nothing.
module G05Valve
public result<int, atom> Half(int u)
Half(u) -> u
public atom Check(int u)
Check(u) when (u |?> Half()) == 1 -> :one
Check(_)                          -> :other
EOF

mk G06Pipe <<'EOF'
// G06 — a pipe in a guard (lowers to a local call before the checker).
module G06Pipe
public atom IsAdmin(int u)
IsAdmin(1) -> :yes
IsAdmin(_) -> :no
public atom Check(int u)
Check(u) when (u |> IsAdmin()) == :yes -> :admin
Check(_)                               -> :ordinary
EOF

mk G07Proj <<'EOF'
// G07 — a field projection in a guard.
module G07Proj
record Order { Id: int, Total: int }
public atom Check(Order o)
Check(o) when o.Total > 5 -> :big
Check(_)                  -> :small
EOF

mk G08With <<'EOF'
// G08 — a record update in a guard.
module G08With
record Order { Id: int, Total: int }
public atom Check(Order o)
Check(o) when (o with { Total = 1 }) == o -> :same
Check(_)                                  -> :other
EOF

mk G09Record <<'EOF'
// G09 — a record construction in a guard.
module G09Record
record Order { Id: int, Total: int }
public atom Check(Order o)
Check(o) when Order{ Id = 1, Total = 1 } == o -> :unit
Check(_)                                      -> :other
EOF

mk G10Inst <<'EOF'
// G10 — an instantiation-bracket call in a guard.
module G10Inst
public atom Check(term t)
Check(t) when ValidateAs<int>(t) == (:ok, 1) -> :one
Check(_)                                     -> :other
EOF

mk G11Str <<'EOF'
// G11 — a string literal in a guard.
module G11Str
public atom Check(binary s)
Check(s) when s == "abc" -> :abc
Check(_)                 -> :other
EOF

mk G12TupleList <<'EOF'
// G12 — tuple and list construction in a guard.
module G12TupleList
public atom Check(int u)
Check(u) when (u, [u]) == (1, [1]) -> :one
Check(_)                           -> :other
EOF

mk G13Arith <<'EOF'
// G13 — division and remainder in a guard.
module G13Arith
public atom Check(int u)
Check(u) when u / 2 == 1 and u % 2 == 0 -> :two
Check(_)                                -> :other
EOF

mk G14Control <<'EOF'
// G14 — THE CONTROL: a comparison guard. Must compile and run.
module G14Control
public atom Check(int u)
Check(u) when u == 1 -> :admin
Check(_)             -> :ordinary
EOF

mk A01ArmCall <<'EOF'
// A01 — a local call in a SWITCH-ARM guard.
module A01ArmCall
public atom IsAdmin(int u)
IsAdmin(1) -> :yes
IsAdmin(_) -> :no
public atom Check(int u)
Check(u) -> u switch {
    n when IsAdmin(n) == :yes => :admin,
    _                         => :ordinary
}
EOF

mk B01ArmBind <<'EOF'
// B01 — a name bound inside one switch arm and read after it (unsafe_var).
// An arm is a single expression, so no binding can appear in one; the probe
// asks whether a bare `=` inside an arm can introduce a name.
module B01ArmBind
public int Check(int u)
Check(u) ->
    var r = u switch { 1 => (y = 2), _ => 3 }
    r
EOF

mk B02UnusedBind <<'EOF'
// B02 — a bound name never read (unused_var warning).
module B02UnusedBind
public int Check(int u)
Check(u) ->
    var y = u
    1
EOF

mk B03UnusedPrivate <<'EOF'
// B03 — a private function nobody calls (unused_function warning).
module B03UnusedPrivate
private int Helper(int n)
Helper(n) -> n + 1
public int Check(int u)
Check(u) -> u
EOF

mk B04Rebind <<'EOF'
// B04 — a parameter re-bound in the body.
module B04Rebind
public int Check(int u)
Check(u) ->
    var u = 1
    u
EOF

echo "wrote $(find . -name '*.bs' | wc -l | tr -d ' ') probe files"
