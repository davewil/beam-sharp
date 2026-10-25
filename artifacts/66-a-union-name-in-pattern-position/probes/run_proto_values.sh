#!/usr/bin/env bash
# Run prototype-compiled cases on concrete values (control: E record and non-map must NOT be members).
S=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad
cd "$(dirname "$0")/proto_cases"
r(){ printf '%-4s %-34s => ' "$1" "$2"; $S/66/bsc_proto --src-root . $1 H "$2" 2>&1 | head -2 | tr '\n' ' '; echo; }
r P1 "{ Kind = :'P1.A', Id = 1 }"
r P1 "{ Kind = :'P1.B', Id = 1 }"
r P1 "{ Kind = :'P1.E', Id = 1 }"
r P1 "5"
r P1 ":none"
r P6 "{ Kind = :'P6.A', Id = 11 }"
r P6 "{ Kind = :'P6.B', Id = 22 }"
r P6 ":none"
r P9 "{ Kind = :'P9.B', Id = 1 }"
r P9 ":none"
