#!/usr/bin/env bash
# P19: the dispatch route (key presence in a clause head) on map<string, term> -- refused today (48 Q2, ENG-323)
. "$(dirname "$0")/lib.sh"
mk MP <<'SRC'
module MP

public atom Who(map<string, term> m)
Who({ "user_id": uid }) -> :saw_user
Who(m) -> :no_user
SRC
$BSC "$W/MP" 2>&1 | sed "s#$W/##" | head -8
