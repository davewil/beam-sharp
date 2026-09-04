#!/usr/bin/env bash
# Probe: rebar.config's {deps, [...]} vs. what rebar3 actually checks at
# `rebar3 compile` time. Uses a LOCAL file:// git remote (no network) as the
# dependency source, since repo.hex.pm is unreachable from this sandbox.
set -euo pipefail
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

rebar3 new lib rebarlib >/dev/null 2>&1
cat > rebarlib/src/rebarlib.erl <<'EOF'
-module(rebarlib).
-export([greet/1]).
greet(Name) -> "hello, " ++ Name.
EOF
cd rebarlib
git init -q
git config user.email t@t.com
git config user.name t
git add -A
git commit -q -m init
git tag 0.1.0
cd ..

rebar3 new app rebardemo >/dev/null 2>&1
cd rebardemo
python3 - <<PY
s = open("rebar.config").read()
s = s.replace(
    "{deps, []}.",
    '{deps, [{rebarlib, {git, "file://$WORK/rebarlib", {tag, "0.1.0"}}}]}.'
)
open("rebar.config", "w").write(s)
PY
cat > src/rebardemo_app.erl <<'EOF'
-module(rebardemo_app).
-behaviour(application).
-export([start/2, stop/1]).
start(_StartType, _StartArgs) ->
    io:format("~s~n", [rebarlib:greet("world")]),
    rebardemo_sup:start_link().
stop(_State) -> ok.
EOF

echo "=== real rebar.config, dependency declared via a real (local) git remote ==="
cat rebar.config

echo
echo "=== 1. dependency PRESENT: rebar3 compile ==="
rebar3 compile
echo "exit: $?"

echo
echo "=== 2. dependency REMOVED from rebar.config AND rebar.lock (fully undeclared), call left in source ==="
python3 - <<PY
s = open("rebar.config").read()
s = s.replace(
    '{deps, [{rebarlib, {git, "file://$WORK/rebarlib", {tag, "0.1.0"}}}]}.',
    "{deps, []}."
)
open("rebar.config", "w").write(s)
PY
rm -rf _build _checkouts rebar.lock
echo "--- rebar3 compile (plain compile: does it notice the undefined remote call?) ---"
rebar3 compile
echo "exit: $?"

echo
echo "--- running the built app: does it crash with error:undef at RUN time? ---"
erl -pa _build/default/lib/rebardemo/ebin -noshell \
    -eval 'io:format("~p~n",[catch rebardemo_app:start(normal,[])]), halt().'

echo
echo "--- rebar3 xref (a SEPARATE, non-default pass): does IT catch the same thing at compile time? ---"
set +e
rebar3 xref
echo "exit: $?"
