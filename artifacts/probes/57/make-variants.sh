#!/usr/bin/env bash
# Rebuild the scratch compilers matrix.sh expects: /tmp/bsbuild (base) and /tmp/bsb_{A,B,C,D}.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd); b=$here/../../build-bsc.sh
$b /tmp/bsbuild
$b /tmp/bsb_A  $here/patches/A-parser.patch
$b /tmp/bsb_B  $here/patches/B-check.patch
$b /tmp/bsb_C  $here/patches/C-check.patch
$b /tmp/bsb_D  $here/patches/D-check.patch
