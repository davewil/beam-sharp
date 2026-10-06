#!/usr/bin/env bash
# 57f: Claim: which EXISTING tests move under each candidate fix. Applies patches/<v>.patch to a COPY of
# compiler/, builds, runs the whole eunit suite per variant SEQUENTIALLY (parallel runs time out under load).
# v0 (unpatched) is the control: its failures are harness artefacts (no rebar3 `TEST` define; AOC
# programs and gates live outside compiler/) and every variant is judged against v0, not against zero.
# Not run: bin/check-*.sh gates (they need the repo's bin/ environment) -- see brief "Not verified".
# Usage (repo root, env.sh sourced): 57f_eunit_variants.sh WORKDIR   (takes ~10-15 min)
set -u
here=$(cd "$(dirname "$0")" && pwd); root=$(pwd); W=$1; mkdir -p "$W"
for v in v0 v1 v2 v2b v2c v3; do
  mkdir -p "$W/$v"; cp -r "$root/compiler" "$W/$v/compiler"; rm -rf "$W/$v/compiler/_build"
  case $v in v1|v3) f=bs_parser.yrl;; v0) f=;; *) f=bs_check.erl;; esac
  [ -n "$f" ] && patch -s "$W/$v/compiler/src/$f" < "$here/patches/$v.patch"
  "$here/run_eunit.sh" "$W/$v/compiler" "$W/eunit_$v.txt" >/dev/null 2>&1
  echo "== $v: $(grep -c '\*failed\*' "$W/eunit_$v.txt") failed, $(grep -c 'timed out' "$W/eunit_$v.txt") timed out"
  grep '\*failed\*' "$W/eunit_$v.txt" | sed 's/\.\.\.\*failed\*//;s/^/     /'
done
