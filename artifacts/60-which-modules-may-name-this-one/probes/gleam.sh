#!/usr/bin/env bash
# P2: does Gleam's internal_modules / @internal REFUSE an import? Run from probes/.
export PATH=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/beam/bin:$PATH LANG=C.UTF-8
cd "$(dirname "$0")/gleam"
echo "## gleam.toml of app:"; cat app/gleam.toml
echo "## client (a SEPARATE package, path dependency on app) imports app's internal module shop/internal/tax"
cat > client/src/client.gleam <<'G'
import shop/internal/tax
pub fn main() { tax.recompute_tax(50) }
G
(cd client && gleam build 2>&1 | tail -5; echo "exit=${PIPESTATUS[0]}")
echo "## same-package intruder module importing the internal module"
mkdir -p app/src/other
cat > app/src/other/intruder.gleam <<'G'
import shop/internal/tax
pub fn probe(n: Int) -> Int { tax.recompute_tax(n) }
G
(cd app && gleam build 2>&1 | tail -3; echo "exit=${PIPESTATUS[0]}"); rm -rf app/src/other
echo "## @internal on a pub fn: client calls it"
cat > client/src/client.gleam <<'G'
import shop/reports
pub fn main() { reports.helper(50) }
G
(cd client && gleam build 2>&1 | tail -3; echo "exit=${PIPESTATUS[0]}")
echo "## docs: @internal fn and internal module hidden from docs? (control: 'gross' must appear)"
(cd app && gleam docs build >/dev/null 2>&1; for w in gross helper recompute_tax; do printf '%s: ' $w; grep -rl "$w" build/dev/docs/app --include=*.html | wc -l; done)
echo "## gleam binary strings mentioning the publish-time rule"
strings $(which gleam) | grep -o 'internal types in their public API[^.]*\|CannotPublishLeakedInternalType' | sort -u
