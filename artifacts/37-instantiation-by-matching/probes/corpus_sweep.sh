#!/usr/bin/env bash
# 37 decision-brief probe — re-run the ticket's own corpus sweep on today's HEAD.
#
# Method: reproduce the ticket's own counting rule verbatim ("a signature is a
# public/private declaration line carrying no ->"), applied to the exemplar
# corpus as it stands today (2026-09-04), to check whether the corpus moved
# again since the ticket's last measurement (2026-08-28, 54 signatures,
# 9/5/9/17/14 across 25a-25e).
set -euo pipefail
cd "$(dirname "$0")/../../.." # repo root
cd compiler/examples/exemplars

echo "== per-directory signature counts (ticket's counting rule) =="
for d in 25a-http-api-server 25b-websocket-handler 25c-event-queue-consumer 25d-database-querying 25e-dynamic-web-page; do
  n=$(grep -hE '^\s*(public|private)\b' "$d"/*.bs | grep -v -- '->' | wc -l)
  echo "$d: $n"
done

echo
echo "== total =="
grep -hrE '^\s*(public|private)\b' */*.bs | grep -v -- '->' | wc -l

echo
echo "== which exemplar directories exist today =="
ls -d 25*/

echo
echo "== every signature, for shape inspection (does any carry a <T> declaration list?) =="
grep -hrnE '^\s*(public|private)\b' */*.bs | grep -v -- '->'

echo
echo "== signatures carrying an angle-bracket TYPE PARAMETER DECLARATION (Name<T,...>(...)) =="
echo "   (as opposed to a ground application like list<OrderRow> or result<X,Y>)"
grep -hrnE '^\s*(public|private)[^(]*\b[A-Z][A-Za-z0-9_]*<[A-Z][A-Za-z0-9_]*(,\s*[A-Z][A-Za-z0-9_]*)*>\(' */*.bs || echo "  (none found)"
