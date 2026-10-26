#!/usr/bin/env bash
# Elm: exposed-modules in a package elm.json. Needs the package registry for elm/core.
D=$(mktemp -d); cd "$D"; mkdir -p src
cat > elm.json <<'EOF'
{ "type":"package","name":"author/shop","summary":"s","license":"BSD-3-Clause","version":"1.0.0",
  "exposed-modules":["Shop"],"elm-version":"0.19.0 <= v < 0.20.0",
  "dependencies":{"elm/core":"1.0.0 <= v < 2.0.0"},"test-dependencies":{} }
EOF
printf 'module Shop exposing (total)\nimport Shop.Internal\ntotal x = Shop.Internal.recompute x\n' > src/Shop.elm
mkdir -p src/Shop; printf 'module Shop.Internal exposing (recompute)\nrecompute x = x + 1\n' > src/Shop/Internal.elm
echo "ls ~/.elm/0.19.1:"; ls -la ~/.elm/0.19.1 2>&1 | head
elm make 2>&1 | head -20; echo "elm exit=${PIPESTATUS[0]}"
