#!/usr/bin/env bash
# Helper (not a claim): builds a patched bsc in a fresh mktemp dir from the repo compiler + 60_internal.patch.
# Prints the path of the patched bsc on the last line. Never touches $REPO/compiler.
H="$(cd "$(dirname "$0")" && pwd)"; . "$H/env.sh"
T=$(mktemp -d /tmp/probe60build.XXXXXX)
cp -r "$REPO/compiler" "$T/compiler"; rm -rf "$T/compiler/_build"
( cd "$T" && patch -s -p1 < "$H/60_internal.patch" ) || exit 1
( cd "$T/compiler" && rebar3 escriptize >/dev/null 2>&1 ) || exit 1
echo "$T/compiler/_build/default/bin/bsc"
