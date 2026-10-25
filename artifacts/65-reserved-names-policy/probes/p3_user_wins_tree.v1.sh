#!/usr/bin/env bash
# P3: two-module (three-file) tree. User `module Map` (own Size), transitive dep Lib calling std Map.Size
# WITHOUT importing the user Map, App that `using Map` and calls Map.Size and Lib.Count.
# Run on HEAD bsc (option 1, current) and on bsc-opt3 (a PROTOTYPE patch: probes/opt3-patch/*.diff, user names win).
S=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad
for V in bsc bsc-opt3; do
  D=$S/65/p3-$V; rm -rf $D; mkdir -p $D/src/Map $D/src/Lib $D/src/App $D/out
  cat > $D/src/Map/Map.bs <<'B'
module Map

public int Size(int n)
Size(n) -> n + 1000
B
  cat > $D/src/Lib/Lib.bs <<'B'
module Lib

public int Count(map<atom, int> m)
Count(m) -> Map.Size(m)
B
  cat > $D/src/App/App.bs <<'B'
module App

using Map
using Lib

public int Go(int n)
Go(n) -> Map.Size(n)

public int Both(int n)
Both(n) -> Count(Map.FromList([(:a, n)]))
B
  echo "######## $V: App.Go 5  (user Map.Size(5): expect 1005 if the user wins)"
  $S/$V --src-root $D/src $D/src/App Go 5 2>&1 | sed "s#$S/65/##" | head -12
  echo "######## $V: Lib.Count of a one-key map, compiled alone (std Map.Size: expect 1)"
  $S/$V --src-root $D/src $D/src/Lib Count '#{a => 1}' 2>&1 | sed "s#$S/65/##" | head -12
  echo "######## $V: App.Both 5 (Lib is a dependency; App also uses std Map.FromList through the shadow)"
  $S/$V --src-root $D/src $D/src/App Both 5 2>&1 | sed "s#$S/65/##" | head -12
done
