#!/usr/bin/env bash
# Builds a PATCHED COPY of the compiler (never touches compiler/). Prints the path of the patched bsc on stdout.
set -e
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../../../.." && pwd)
dest=${PROTO_DIR:-${TMPDIR:-/tmp}/bs60-proto}
if [ ! -x "$dest/_build/default/bin/bsc" ]; then
  rm -rf "$dest"; mkdir -p "$dest"
  (cd "$repo/compiler" && tar --exclude=_build --exclude=examples --exclude=bench -cf - .) | tar -xf - -C "$dest"
  (cd "$dest" && patch -p1 -s < "$here/ticket60.patch" && rebar3 escriptize) >"$dest.build.log" 2>&1
fi
echo "$dest/_build/default/bin/bsc"
