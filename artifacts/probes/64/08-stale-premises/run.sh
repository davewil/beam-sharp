#!/usr/bin/env bash
# Probe 08 -- two premises the ticket (and 15 §1) lean on, checked against HEAD.
#  (a) 15 §1 rejected tagging option<T> because it would tax `as T` yielding `T | :nothing`. Is `as T` built?
#  (b) ticket 64 says PRELUDE.md records ToExistingAtom as OWED. Does PRELUDE.md exist; what does the built ToExistingAtom return?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../lib/env.sh"
REPO="$(cd "$HERE/../../../.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; cd "$W"
echo "=== (a) \`d as int\` ==="
mkdir -p "$W/A"; printf 'module A\npublic int F(term d)\nF(d) -> (d as int) switch { :nothing => 0, n => n }\n' > "$W/A/A.bs"
"$BSC" "$W/A" </dev/null 2>&1 | sed "s#$W/##" | head -3
echo "grep for an 'as' token in the lexer/parser:"; grep -n "'as'\|^as " "$REPO/compiler/src/bs_lexer.xrl" "$REPO/compiler/src/bs_parser.yrl" || echo "(no match)"
echo "=== (b) PRELUDE.md ==="; find "$REPO" -name PRELUDE.md -not -path '*/node_modules/*' | grep . || echo "(no PRELUDE.md anywhere in the tree)"
echo "=== (b) what ToExistingAtom returns: ask for an int and read the diagnostic ==="
mkdir -p "$W/T"; printf 'module T\npublic int F(binary b)\nF(b) -> ToExistingAtom(b)\n' > "$W/T/T.bs"
"$BSC" "$W/T" </dev/null 2>&1 | sed "s#$W/##" | head -3
echo "compiler source: the failure member is a tagged tuple:"; grep -n "the failure is" "$REPO/compiler/src/bs_diag.erl" | head -2
