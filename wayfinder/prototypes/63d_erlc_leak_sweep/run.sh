#!/usr/bin/env bash
#
# 63d — compile every probe and the shipped examples corpus with the built
# `bsc`, and record for each whether a `compile:` line reached stderr.
#
# A `compile:` line is `bsc.erl`'s relay of the Erlang compiler's own report
# (it read `erlc:` while erlc was a subprocess; ENG-314 moved it in-process).
# Any probe that produces one is a program that cleared `bs_check` and was
# then refused, or warned about, in Erlang's voice — ENG-256's defect.
#
# Verdicts:
#   LEAK      exit ≠ 0 and a `compile:` line   — the defect
#   WARN-LEAK exit 0 and a `compile:` line     — the defect, as a warning
#   REFUSED   exit ≠ 0 and no `compile:` line  — refused in B#'s voice
#   CLEAN     exit 0 and no `compile:` line    — compiles
#
# Usage: bash run.sh [path/to/bsc] [results file]   (defaults: compiler/_build/default/bin/bsc, results.md beside this script)

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
BSC="${1:-$REPO/compiler/_build/default/bin/bsc}"
[ -x "$BSC" ] || { echo "no built bsc at $BSC — run rebar3 escriptize in compiler/"; exit 2; }

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
OUT="${2:-$HERE/results.md}"

verdict() {
  local rc="$1" log="$2"
  if grep -q '^compile:' "$log"; then
    [ "$rc" -eq 0 ] && echo "WARN-LEAK" || echo "LEAK"
  else
    [ "$rc" -eq 0 ] && echo "CLEAN" || echo "REFUSED"
  fi
}

{
  echo "# 63d — results"
  echo
  echo "bsc: \`$BSC\`, tree \`$(git -C "$REPO" rev-parse --short HEAD)\`, $(date -u +%Y-%m-%dT%H:%MZ)"
  echo
  echo "| Probe | Verdict | First line of output |"
  echo "|---|---|---|"
} > "$OUT"

# The probes. Each is a module directory whose root is this directory.
for dir in "$HERE"/[GAB][0-9][0-9]*/; do
  name="$(basename "$dir")"
  log="$W/$name.log"
  "$BSC" --src-root "$HERE" "$HERE/$name" > "$log" 2>&1; rc=$?
  v="$(verdict "$rc" "$log")"
  first="$(head -1 "$log" | sed 's/|/\\|/g')"
  printf '| %s | %s | `%s` |\n' "$name" "$v" "${first:-<none>}" >> "$OUT"
done

# The control must also RUN, or the probes above measured nothing.
ctl="$("$BSC" --src-root "$HERE" "$HERE/G14Control" Check 1 2>&1)"
{
  echo
  if [ "$ctl" = ":admin" ]; then
    echo "Control G14Control: ran, returned \`:admin\`."
  else
    echo "**Control G14Control did NOT run** (got \`$ctl\`) — the table above is not evidence."
  fi
} >> "$OUT"

# The shipped corpus: does any example already print a `compile:` line?
{
  echo
  echo "## Shipped examples"
  echo
  echo "| Example | Verdict |"
  echo "|---|---|"
} >> "$OUT"
for dir in "$REPO"/compiler/examples/*/; do
  name="$(basename "$dir")"
  [ "$name" = "exemplars" ] && continue
  log="$W/ex-$name.log"
  "$BSC" --src-root "$REPO/compiler/examples" "$REPO/compiler/examples/$name" > "$log" 2>&1; rc=$?
  printf '| %s | %s |\n' "$name" "$(verdict "$rc" "$log")" >> "$OUT"
done

cat "$OUT"
