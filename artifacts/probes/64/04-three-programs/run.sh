#!/usr/bin/env bash
# Probe 04 -- the same task ("read key k from a map<string, term> whose value may be the atom :nothing")
# written three ways, each compiled by three bscs:
#   base     = repo HEAD under OTP 25                         (option<T> = T | :nothing)
#   tagged   = base + prelude option<T> = (:some, T) | :nothing   (Option 1's one-line delta)
#   callsite = base + prototype refusal of an absorbed member at a generic call (Option 2/3's delta)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../lib/env.sh"
TAGGED="$("$HERE/../lib/build-bsc-tagged-option.sh" | tail -1)"
CALLSITE="$("$HERE/../lib/build-bsc-callsite-refusal.sh" | tail -1)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; cd "$W"
for P in Opt1 Opt2 Opt3; do
  for V in base tagged callsite; do
    case $V in base) B="$BSC";; tagged) B="$TAGGED";; callsite) B="$CALLSITE";; esac
    echo "=== $P under $V ==="
    out="$("$B" "$HERE/$P" </dev/null 2>&1)"; rc=$?
    if [ $rc -ne 0 ]; then printf '%s\n' "$out" | head -3 | sed "s#$HERE/##"; echo "(refused, exit=$rc)"; continue; fi
    echo "compiles. --api:"; "$B" --api "$HERE/$P" </dev/null 2>&1 | grep -E 'Get|Describe'
    for f in Present PresentNothing Absent; do printf '  %-15s -> ' "$f"; "$B" "$HERE/$P" "$f" </dev/null 2>&1 | tail -1; done
  done
done
