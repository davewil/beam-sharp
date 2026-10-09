#!/usr/bin/env bash
# P17: does bsc ALREADY check a dependency named by `using`? (premise: "the first thing bsc does with a dependency")
# Native form `using Pkg.Dep` (ticket 41): absent module -> ? ; present module under --src-root -> accepted (control).
# Foreign form `using :atom {..}` absent module -> accepted (P1).
. "$(dirname "$0")/../lib.sh"
W=$(mktemp -d); cd "$W"; mkdir -p src/Dep src/UsesMissing src/UsesPresent
printf 'module Dep\npublic int One()\nOne() -> 1\n' > src/Dep/a.bs
printf 'module UsesMissing\nusing Nope.Gone\npublic int Go()\nGo() -> Nope.Gone.One()\n' > src/UsesMissing/a.bs
printf 'module UsesPresent\nusing Dep\npublic int Go()\nGo() -> Dep.One()\n' > src/UsesPresent/a.bs
echo "--- native using, module ABSENT (expect refused at compile time)"
bsc --src-root src -o o1 src/UsesMissing/a.bs 2>&1 | head -4; echo "rc=${PIPESTATUS[0]}"
echo "--- native using, module PRESENT under --src-root (control: expect accepted, and Dep.beam emitted)"
bsc --src-root src -o o2 src/UsesPresent/a.bs 2>&1 | head -4; ls o2
