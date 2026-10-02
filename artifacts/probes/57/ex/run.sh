#!/usr/bin/env bash
# Probe X: Elixir 1.14 AST for `-5`, and which typespec ranges it accepts. (Elixir's own source is not
# installed here; the stack trace of the refusal names lib/kernel/typespec.ex but that is not read.)
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
out=$(elixir "$here/q.exs" 2>&1); echo "$out" | grep -v "^ *\[\|^ *\]\|^ *{\|^ *\]}"; fail=0
echo "$out" | grep -q 'typespec -5..5 *accepted' || fail=1
echo "$out" | grep -q 'typespec (0 - 5)..5 *refused' || fail=1
echo "$out" | grep -q 'typespec (1 + 1)..(2 \* 3) *refused' || fail=1
echo "$out" | grep -q '{:neg, :y, :z, :n}' || fail=1
exit $fail
