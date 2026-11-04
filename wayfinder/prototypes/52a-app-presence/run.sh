#!/usr/bin/env bash
# Ticket 52 probe: what the BEAM says when a dependency's application is / is not on the path.
set -euo pipefail
d=$(mktemp -d); here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$d/libs/req/ebin"; cp "$here/req.app" "$d/libs/req/ebin/"
erlc -o "$d/libs/req/ebin" "$here/Elixir.Req.erl"; erlc -o "$d" "$here/p.erl"
echo "--- without ERL_LIBS"; erl -noshell -pa "$d" -eval 'p:main(),halt().'
echo "--- with ERL_LIBS";    ERL_LIBS="$d/libs" erl -noshell -pa "$d" -eval 'p:main(),halt().'
