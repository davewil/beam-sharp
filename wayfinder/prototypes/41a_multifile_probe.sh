#!/usr/bin/env bash
# 41a — Is `bsc` single-file, and what does it already do with two?
#
# Ticket 41 §3 opens with "the compiler is single-file (`bsc FILE.bs`, one
# `module` declaration, one `.beam`)". This probe measures that sentence,
# because §3's fork A ("re-check the dependency's source") is priced entirely
# on how far the compiler already is from holding two modules at once.
#
# Run from anywhere:  bash wayfinder/prototypes/41a_multifile_probe.sh

set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BSC="$ROOT/compiler/_build/default/bin/bsc"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cd "$WORK" || exit 1

cat > Alpha.bs <<'EOF'
module Alpha

int Double(int n)

Double(n) -> n * 2
EOF

cat > Beta.bs <<'EOF'
module Beta

int Quad(int n)

Quad(n) -> n * 4
EOF

# Gamma calls a function defined in Alpha, by a bare name it never imports.
cat > Gamma.bs <<'EOF'
module Gamma

int Eight(int n)

Eight(n) -> Double(n) * 4
EOF

echo "=== 1. two independent files in one invocation ==="
"$BSC" Alpha.bs Beta.bs
echo "exit=$?"
echo "beams: $(ls ./*.beam 2>/dev/null | tr '\n' ' ')"
rm -f ./*.beam

echo
echo "=== 2. a file naming a function defined in the other ==="
"$BSC" Alpha.bs Gamma.bs
echo "exit=$?"
rm -f ./*.beam

echo
echo "=== 3. the same, order reversed ==="
"$BSC" Gamma.bs Alpha.bs
echo "exit=$?"
rm -f ./*.beam

echo
echo '=== 4. does a modpath `using` parse at all? ==='
cat > Delta.bs <<'EOF'
module Delta

using Alpha

int Eight(int n)

Eight(n) -> Double(n) * 4
EOF
"$BSC" Delta.bs
echo "exit=$?"
rm -f ./*.beam

echo
echo '=== 5. what does a dotted call site do? ==='
cat > Eps.bs <<'EOF'
module Eps

int Eight(int n)

Eight(n) -> Alpha.Double(n) * 4
EOF
"$BSC" Eps.bs
echo "exit=$?"
