#!/usr/bin/env bash
# PROBE 60f — PROTOTYPE DELTA for Option B: a `visible Some.Path` line in the callee's source.
# Delta = proto_visible_line.patch (lexer keyword, parser rule, world-entry field, same check as 60d),
# applied to a COPY of compiler/. Spelled as its own line, beside `behaviour`/`using`, NOT inside the
# `module` line: the `{module, L, Name}` tuple is matched in many places, a separate declaration is not.
# Measures: (1) the cases behave, incl. namespace imports; (2) lines changed; (3) yecc conflict count
# before/after; (4) what the new keyword takes away: identifiers named `visible` in the repo's .bs files.
# Exits non-zero if any case differs from its stated expectation.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cp -r "$REPO/compiler" "$W/proto"; rm -rf "$W/proto/_build" "$W/proto/src/bs_parser.erl" "$W/proto/src/bs_lexer.erl"   # generated, gitignored: force regeneration
( cd "$W/proto" && patch -p2 -s < "$HERE/proto_visible_line.patch" && rebar3 escriptize >/dev/null 2>&1 ) || { echo "BUILD FAILED"; exit 1; }
PROTO="$W/proto/_build/default/bin/bsc"
PRISTINE="$REPO/compiler/_build/default/bin/bsc"; [ -x "$PRISTINE" ] || PRISTINE="${BSC:?set BSC or build compiler/}"
echo "delta (unified diff): $(grep -c '^+[^+]' "$HERE/proto_visible_line.patch") lines added, $(grep -c '^-[^-]' "$HERE/proto_visible_line.patch") removed, in $(grep -c '^--- ' "$HERE/proto_visible_line.patch") files (lexer, parser, check, diag, bsc)"

echo "== (3) yecc conflicts, pristine grammar vs prototype grammar"
for tag in pristine proto; do
  src="$REPO/compiler/src/bs_parser.yrl"; [ $tag = proto ] && src="$W/proto/src/bs_parser.yrl"
  mkdir -p "$W/y.$tag"; cp "$src" "$W/y.$tag/p.yrl"
  ( cd "$W/y.$tag" && erl -noshell -eval 'yecc:file("p.yrl", [{parserfile, "p.erl"}]), halt().' 2>&1 | grep -i conflicts | sed "s/^/   $tag: /" )
done

T="$W/tree"
mod() { mkdir -p "$T/$1"; { echo "module $2"; [ -n "$3" ] && printf '%s\n' "$3"; echo "public int Total(int n)"; echo "Total(n) -> $4"; } > "$T/$1/$(basename "$1").bs"; }
mkdir -p "$T/Acme/Orders/Totals"
printf 'module Acme.Orders.Totals\nvisible Acme.Orders\nvisible Acme.Audit\npublic int Double(int n)\nDouble(n) -> n + n\n' > "$T/Acme/Orders/Totals/Totals.bs"
mkdir -p "$T/Acme/Open"; printf 'module Acme.Open\npublic int Triple(int n)\nTriple(n) -> n + n + n\n' > "$T/Acme/Open/Open.bs"
mod Acme/Orders/Fulfil   Acme.Orders.Fulfil  "using Acme.Orders.Totals" "Double(n)"
mod Acme/Audit           Acme.Audit          "using Acme.Orders.Totals" "Double(n)"
mod Acme/Billing         Acme.Billing        "using Acme.Orders.Totals" "Double(n)"
mod Acme/BillingNs       Acme.BillingNs      "using Acme.Orders"        "Totals.Double(n)"
mod Acme/BillingOpen     Acme.BillingOpen    "using Acme.Open"          "Triple(n)"
status() { "$1" --src-root "$T" -o "$W/o.$$" "$T/$2" >/dev/null 2>&1; echo $?; }
say()    { "$1" --src-root "$T" -o "$W/o.$$" "$T/$2" 2>&1; }
bad=0
check() { # path want label ; pristine cannot parse `visible`, so its exit is reported, not judged
  local q wantq=0; q=$(status "$PROTO" "$1"); [ "$2" = refuse ] && wantq=1
  local v=OK; [ "$q" = "$wantq" ] || { v=UNEXPECTED; bad=1; }
  if [ "$2" = refuse ] && [ "$q" = 1 ]; then local f; f=$(say "$PROTO" "$1" | head -1); [[ $f == "$T/$1/"* ]] || { v=REFUSED-FOR-THE-WRONG-FILE; bad=1; }; fi
  printf '  %-44s want %-6s prototype=%s  %s\n' "$3" "$2" "$q" "$v"
}
echo "== (1) cases (Totals says: visible Acme.Orders, visible Acme.Audit)"
check Acme/Orders/Fulfil admit  "Acme.Orders.Fulfil (under first path)"
check Acme/Audit         admit  "Acme.Audit (second path, outside Acme.Orders)"
check Acme/Billing       refuse "Acme.Billing (module using)"
check Acme/BillingNs     refuse "Acme.BillingNs (using Acme.Orders, Totals.Double)"
check Acme/BillingOpen   admit  "Acme.BillingOpen (callee has no visible line)"
echo "== the pristine compiler on the callee itself (it has no such keyword): exit $(status "$PRISTINE" Acme/Orders/Totals)"
say "$PRISTINE" Acme/Orders/Totals | head -1 | sed "s|$T/||; s/^/   /"
echo "== diagnostics from the prototype"
for c in Acme/Billing Acme/BillingNs; do say "$PROTO" $c | head -2 | sed "s|$T/||; s/^/    /"; done

echo "== (4) what the keyword takes: whole-word 'visible' in the repo's .bs files"
n=$(grep -rwn 'visible' --include=*.bs "$REPO" 2>/dev/null | grep -v '^\s*//' | grep -vE '^[^:]*:[0-9]+:\s*//' | wc -l)
echo "   $n occurrences outside comment-only lines (comment lines excluded by a regex; code uses not hand-read)"
grep -rwn 'visible' --include=*.bs "$REPO" 2>/dev/null | grep -vE '^[^:]*:[0-9]+:\s*//' | head -5 | sed 's|^'"$REPO"'/|   |'
[ "$bad" = 0 ] && echo "ALL CASES AS EXPECTED" || { echo "SOME CASE DID NOT BEHAVE AS EXPECTED"; exit 1; }
