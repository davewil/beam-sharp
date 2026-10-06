#!/usr/bin/env bash
# p7 — Elm 0.19.3. The npm package is a downloaded binary: NO Elm source is installed, so no file:line is cited.
# The package registry (package.elm-lang.org) is unreachable through the sandbox proxy, so the interesting half
# -- does `import Foo` get checked against elm.json's declared packages -- is NOT PROBED.
# What CAN run offline:
#   L1  the compiler names elm.json as the file that records dependencies (shape: dependencies.direct / .indirect, written by me here)
#       (it reads this hand-written file and refuses it by name)
#   L2  the compiler checks elm.json itself before it fetches anything: an application without elm/json is refused with
#       "MISSING DEPENDENCY" (observable offline)
#   L3  CONTROL: `elm init` and a fetch fail here for network reasons -- recorded so nobody reads silence as success
source "$(dirname "$0")/common.sh"; export HOME="$WORK/home"; mkdir -p "$HOME" "$WORK/p/src"; cd "$WORK/p"
cat > elm.json <<'EOT'
{"type":"application","source-directories":["src"],"elm-version":"0.19.1","dependencies":{"direct":{"elm/core":"1.0.5"},"indirect":{}},"test-dependencies":{"direct":{},"indirect":{}}}
EOT
printf 'module Main exposing (main)\nimport Html\nmain = Html.text "x"\n' > src/Main.elm
o=$(timeout 60 elm make src/Main.elm --output=/dev/null 2>&1 | head -6); echo "$o"
expect "L2 offline refusal names the missing dependency, from elm.json alone" "MISSING DEPENDENCY" "$o"
expect "L1 it names the file that records dependencies" "elm.json" "$o"
echo "== L3 control: anything needing the network fails, so the import-vs-elm.json check is unobserved"
n=$(cd "$WORK" && mkdir -p i && cd i && yes | timeout 60 elm init 2>&1 | tail -4 | tr '\n' ' '); echo "$n"
expect "L3 elm init cannot reach the registry" "internet" "$n"
echo "NOT PROBED: whether the compiler refuses \`import Html\` when elm/html is absent from elm.json (needs package download)."
finish
