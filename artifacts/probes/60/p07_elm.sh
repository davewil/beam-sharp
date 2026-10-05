#!/usr/bin/env bash
# CLAIM (neighbour survey): Elm's `exposed-modules` in elm.json decides which of a package's modules
# other packages may import. Elm 0.19.0 is installed, but it fetches its package registry on
# first use and the sandbox proxy blocks package.elm-lang.org.
# This probe only RECORDS whether elm can be run at all. It measures nothing about enforcement.
# Verdict is NOT-MEASURED if the registry is unreachable; CONFIRMED only if elm compiles the project.
. "$(dirname "$0")/lib.sh"
E="$WORK/elm"; rm -rf "${E:?}"; mkdir -p "$E/src/Lib"; cd "$E" || exit 1
export ELM_HOME="$E/elmhome"
elm --version
cat > elm.json <<'EOT'
{
    "type": "package",
    "name": "author/libpkg",
    "summary": "ticket 60 probe",
    "license": "BSD-3-Clause",
    "version": "1.0.0",
    "exposed-modules": ["Lib"],
    "elm-version": "0.19.0 <= v < 0.20.0",
    "dependencies": {},
    "test-dependencies": {}
}
EOT
cat > src/Lib.elm <<'EOT'
module Lib exposing (total)
import Lib.Internal as I
total : List Int -> Int
total xs = I.recompute xs
EOT
cat > src/Lib/Internal.elm <<'EOT'
module Lib.Internal exposing (recompute)
recompute : List Int -> Int
recompute xs = List.sum xs
EOT
timeout 90 elm make 2>&1 | head -25 | tee "$E/elm.out"; rc=${PIPESTATUS[0]}
echo "elm make exit=$rc"
if grep -q 'HTTP PROBLEM' "$E/elm.out"; then echo "VERDICT[elm-exposed-modules]: NOT MEASURED (registry blocked by sandbox proxy)"
elif [ "$rc" -eq 0 ]; then echo "VERDICT[elm-exposed-modules]: CONFIRMED-RAN (enforcement still untested: a second package would be needed)"
else echo "VERDICT[elm-exposed-modules]: NOT MEASURED (elm failed for another reason, see above)"; fi
