#!/usr/bin/env bash
# Ticket 52, the premise: "Compile it on a machine with a different ERL_LIBS and it fails at the call site
# with error:undef, having promised nothing." Measured against the built bsc with a fake `req` application.
# Usage: bash p3_bsc_today.sh   (uses compiler/_build/default/bin/bsc; OTP >= 26 on PATH)
set -u; here=$(cd "$(dirname "$0")" && pwd); BSC=${BSC:-$here/../../../compiler/_build/default/bin/bsc}
W=$(mktemp -d); cd "$W"
mkdir -p libs/req-0.7.3/ebin app/Client
printf -- "-module('Elixir.Req').\n-export([new/1]).\nnew(O) -> {req, O}.\n" > Elixir.Req.erl && erlc -o libs/req-0.7.3/ebin Elixir.Req.erl
printf '{application, req, [{vsn, "0.7.3"}, {modules, [%s]}]}.\n' "'Elixir.Req'" > libs/req-0.7.3/ebin/req.app
cat > app/Client/a.bs <<'EOF'
module Client

using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}

public term Make()
Make() -> :'Elixir.Req'.new([])
EOF
echo "## ERL_LIBS holds req:";  ERL_LIBS=$W/libs "$BSC" app/Client Make 2>&1 | head -3; echo "exit=${PIPESTATUS[0]}"
echo "## ERL_LIBS empty (the other machine):"; env -u ERL_LIBS "$BSC" app/Client Make 2>&1 | head -3; echo "exit=${PIPESTATUS[0]}"
echo "## compile only (no run), ERL_LIBS empty:"; env -u ERL_LIBS "$BSC" -o "$W/out" app/Client 2>&1 | head -3; echo "exit=${PIPESTATUS[0]}"
