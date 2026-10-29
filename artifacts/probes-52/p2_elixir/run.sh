#!/bin/bash
# Each case starts from a clean app/_build: mix caches the generated app spec, and a reused _build gave different
# warnings for identical inputs (observed: case C printed an :ssl warning when run after A/B in the same _build).
cd "$(dirname "$0")"; (cd widget && rm -rf _build && mix compile >/dev/null 2>&1)
cd app
f(){ grep -E '^warning' | cut -c1-120; }
echo "## A (no dep)";  rm -rf _build; mix compile --force 2>&1 | f
echo "## B (path dep)"; rm -rf _build; WITH_DEP=1 mix compile --force 2>&1 | f
echo "## C control: ssl in extra_applications"; rm -rf _build; EXTRA=logger,ssl mix compile --force 2>&1 | f
echo "## D widget only via ERL_LIBS, not in deps"; rm -rf _build; ERL_LIBS=$PWD/../widget/_build/dev/lib mix compile --force 2>&1 | f
echo "## C2 same-_build reuse (shows the staleness): run C twice"; rm -rf _build; mix compile --force >/dev/null 2>&1; EXTRA=logger,ssl mix compile --force 2>&1 | f
rm -rf _build ../widget/_build
