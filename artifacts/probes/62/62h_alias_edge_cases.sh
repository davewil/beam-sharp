#!/usr/bin/env bash
# PROBE 62h — where does a *derived* snake_case alias rule break on legal B# programs?
# Each case is one module compiled twice: BS_ALIAS=off (the real compiler: CONTROL, must compile) and
# BS_ALIAS=deleg (prototype delta: 62d). A case "breaks the rule" iff control compiles and deleg does not.
set -uo pipefail
: "${ALIASBSC:?}"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
try() { # name, body
  local n="$1" body="$2"; mkdir -p "$W/$n/Edge"; printf 'module Edge\n\n%s\n' "$body" > "$W/$n/Edge/edge.bs"
  for m in off deleg; do
    mkdir -p "$W/$n/out_$m"
    if BS_ALIAS=$m "$ALIASBSC" --src-root "$W/$n" -o "$W/$n/out_$m" "$W/$n/Edge" >"$W/$n/log_$m" 2>&1 && [ -f "$W/$n/out_$m/Edge.beam" ]; then r=compiles; else r="REFUSED: $(grep -m1 -i 'already\|error\|compile' "$W/$n/log_$m" | cut -c1-110)"; fi
    printf '  %-28s %-6s %s\n' "$n" "$m" "$r"
  done
}
try plain          $'public int Get(int x)\nGet(x) -> x + 1'
try bif_name_Length $'public int Length(int x)\nLength(x) -> x + 1'
try acronym_pair   $'public int GetId(int x)\nGetId(x) -> x + 3\n\npublic int GetID(int x)\nGetID(x) -> x + 4'
try module_info    $'public int ModuleInfo(int x)\nModuleInfo(x) -> x + 2'
try private_twin   $'public int GetId(int x)\nGetId(x) -> x + 3\n\nint GetID(int x)\nGetID(x) -> x + 4'
try arity_overload $'public int Get(int x)\nGet(x) -> x + 1\n\npublic int Get(int x, int y)\nGet(x, y) -> x + y'
