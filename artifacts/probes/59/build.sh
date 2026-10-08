#!/usr/bin/env bash
# build.sh SRCROOT RELFILE OUTROOT
# Compile one module four ways: base, A, B, E (E = guard public-or-address-taken, patches/E-*.patch).
# patches/A-*.patch), B (kind/range/float tests also on private, patches/B-*.patch).
set -e
here=$(cd "$(dirname "$0")" && pwd); . "$here/../lib.sh"
srcroot=$1; rel=$2; out=$(cd "$3" 2>/dev/null && pwd || (mkdir -p "$3" && cd "$3" && pwd))
for v in base:/tmp/bsbuild/ebin A:/tmp/bsb_59_a/ebin B:/tmp/bsb_59_b/ebin E:/tmp/bsb_59_e/ebin; do
  n=${v%%:*}; mkdir -p "$out/$n"
  (cd "$srcroot" && BSC_EBIN=${v#*:} bsc -o "$out/$n" "$rel")
done
