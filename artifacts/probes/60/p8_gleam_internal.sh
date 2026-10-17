#!/usr/bin/env bash
# Probe 8 - Gleam: is `internal` enforced? app imports lib/internal/secret from a path dependency.
command -v gleam >/dev/null || export PATH=/tmp/bin:$PATH
here=$(cd "$(dirname "$0")" && pwd); d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
cp -r $here/gleam_internal/. $d/; cd $d/app && gleam run 2>&1 | grep -v "^ *Compil\|Resolving\|Download\|Running\|Compiled" 
