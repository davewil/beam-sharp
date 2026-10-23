#!/usr/bin/env bash
# PROBE 60d — PROTOTYPE DELTA: what does a caller-side "who may name this" rule cost, and can it be bypassed?
# The rule prototyped (cheapest spelling, no syntax): a module whose dotted path has an `Internal`
# segment may be named only from modules under the path BEFORE that segment.
# Delta = proto_internal_segment.patch, applied to a COPY of compiler/ (the repo is not touched).
# Every case below has an EXPECTED result for the prototype and for the pristine compiler; the script
# exits non-zero if any case differs, so a bypass shows up as a red row, not as prose.
# Needs: source env.sh first (rebar3, erl).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cp -r "$REPO/compiler" "$W/proto"; rm -rf "$W/proto/_build" "$W/proto/src/bs_parser.erl" "$W/proto/src/bs_lexer.erl"   # generated, gitignored: force regeneration
( cd "$W/proto" && patch -p2 -s < "$HERE/proto_internal_segment.patch" && rebar3 escriptize >/dev/null 2>&1 ) || { echo "BUILD FAILED"; exit 1; }
PROTO="$W/proto/_build/default/bin/bsc"
PRISTINE="$REPO/compiler/_build/default/bin/bsc"; [ -x "$PRISTINE" ] || PRISTINE="${BSC:?set BSC or build compiler/}"
stat() { # unified-diff stat of a patch file: insertions (non-blank), deletions, files
  local f=$1; echo "$(grep -c '^+[^+]' "$f") non-blank + $(grep -c '^+$' "$f") blank insertions, $(grep -c '^-[^-]' "$f") deletions, $(grep -c '^--- ' "$f") files"; }
echo "delta (unified diff of the patch): $(stat "$HERE/proto_internal_segment.patch")"

T="$W/tree"
# mod DIR MODULE "using lines" "call expression"
mod() { mkdir -p "$T/$1"; { echo "module $2"; [ -n "$3" ] && printf '%s\n' "$3"; echo "public int Total(int n)"; echo "Total(n) -> $4"; } > "$T/$1/$(basename "$1").bs"; }
leaf() { mkdir -p "$T/$1"; printf 'module %s\npublic int Double(int n)\nDouble(n) -> n + n\n' "$2" > "$T/$1/$(basename "$1").bs"; }
leaf Shop/Internal/Calc                 Shop.Internal.Calc
leaf Acme/Orders/Internal/Totals        Acme.Orders.Internal.Totals
# --- should be ADMITTED
mod Shop/Orders                 Shop.Orders            "using Shop.Internal.Calc"          "Double(n)"
mod Shop/Internal/Deep/Leaf     Shop.Internal.Deep.Leaf "using Shop.Internal.Calc"          "Double(n)"
mod Shop/Orders/Ns3             Shop.Orders.Ns3        "using Shop.Internal"               "Calc.Double(n)"
mod Shop/Orders/Ns4             Shop.Orders.Ns4        "using Shop"                        "Internal.Calc.Double(n)"
mod Acme/Orders/Fulfil          Acme.Orders.Fulfil     "using Acme.Orders.Internal.Totals" "Double(n)"
# last-segment semantics and the root-level case
leaf Acme/Internal/Foo/Internal/Bar     Acme.Internal.Foo.Internal.Bar
leaf Internal/Root                      Internal.Root
mod Acme/Internal/Foo/User  Acme.Internal.Foo.User "using Acme.Internal.Foo.Internal.Bar" "Double(n)"
mod Acme/Other2             Acme.Other2            "using Acme.Internal.Foo.Internal.Bar" "Double(n)"
mod Outside/RootUser        Outside.RootUser       "using Internal.Root"                  "Double(n)"
# --- should be REFUSED (Billing.Direct: the pristine compiler refuses it too, by design)
mod Billing/Invoice             Billing.Invoice        "using Shop.Internal.Calc"          "Double(n)"
mod Billing/Ns                  Billing.Ns             "using Shop.Internal"               "Calc.Double(n)"
mod Billing/Ns2                 Billing.Ns2            "using Shop"                        "Internal.Calc.Double(n)"
mod Billing/Direct              Billing.Direct         ""                                  "Shop.Internal.Calc.Double(n)"
mod Acme/Billing                Acme.Billing           "using Acme.Orders.Internal.Totals" "Double(n)"
mod Acme/BillingNs              Acme.BillingNs         "using Acme.Orders.Internal"        "Totals.Double(n)"

status() { "$1" --src-root "$T" -o "$W/o.$$" "$T/$2" >/dev/null 2>&1; echo $?; }
say()    { "$1" --src-root "$T" -o "$W/o.$$" "$T/$2" 2>&1; }
bad=0
# Fixtures are grouped by root so that a namespace `using` (which compiles every module under it) never pulls in
# a fixture that is refused for another reason: Shop.* is all-valid; Acme.* and Billing.* hold the outsiders.
check() { # path want(admit|refuse) label [pristine-want, default 0]
  local p q wantp=${4:-0}; p=$(status "$PRISTINE" "$1"); q=$(status "$PROTO" "$1")
  local wantq=0; [ "$2" = refuse ] && wantq=1
  local verdict=OK; { [ "$p" = "$wantp" ] && [ "$q" = "$wantq" ]; } || { verdict="UNEXPECTED"; bad=1; }
  # a refusal must be refused FOR THE RIGHT FILE: the first error line must name this case's own source
  if [ "$2" = refuse ] && [ "$q" = 1 ]; then
    local first; first=$(say "$PROTO" "$1" | head -1)
    [[ $first == "$T/$1/"* ]] || { verdict="REFUSED-FOR-THE-WRONG-FILE"; bad=1; }
  fi
  printf '  %-44s want %-6s pristine=%s prototype=%s  %s\n' "$3" "$2" "$p" "$q" "$verdict"
}
echo "== cases (pristine accepts all but Billing.Direct, which it refuses by design; the prototype must match "want")"
check Shop/Orders             admit  "Shop.Orders (module using)"
check Shop/Internal/Deep/Leaf admit  "Shop.Internal.Deep.Leaf (sibling)"
check Shop/Orders/Ns3         admit  "Shop.Orders.Ns3 (using Shop.Internal)"
check Shop/Orders/Ns4         admit  "Shop.Orders.Ns4 (using Shop)"
check Acme/Orders/Fulfil      admit  "Acme.Orders.Fulfil (nested Internal)"
check Acme/Internal/Foo/User  admit  "Acme.Internal.Foo.User (last Internal's parent)"
check Outside/RootUser        admit  "Outside.RootUser (root-level Internal: unrestricted)"
check Billing/Invoice         refuse "Billing.Invoice (module using)"
check Billing/Ns              refuse "Billing.Ns (using Shop.Internal)"
check Billing/Ns2             refuse "Billing.Ns2 (using Shop)"
check Billing/Direct          refuse "Billing.Direct (no using at all)" 1
check Acme/Other2             refuse "Acme.Other2 (under Acme, not under Acme.Internal.Foo)"
check Acme/Billing            refuse "Acme.Billing (nested Internal)"
check Acme/BillingNs          refuse "Acme.BillingNs (using Acme.Orders.Internal)"
# --- a KNOWN GAP, asserted so it stays visible: a visible module's signature can carry a record type minted
# in an Internal module, and the outsider never names that module.
mkdir -p "$T/Lib/Internal/Types" "$T/Lib/Api" "$T/Out/Leak" "$T/Out/Bad"
printf 'module Lib.Internal.Types\nrecord Row { Id: int }\npublic Row Mk(int id)\nMk(id) -> Row{ Id = id }\n' > "$T/Lib/Internal/Types/Types.bs"
printf 'module Lib.Api\nusing Lib.Internal.Types\npublic Row Make(int id)\nMake(id) -> Mk(id)\n' > "$T/Lib/Api/Api.bs"
printf 'module Out.Leak\nusing Lib.Api\npublic int Id(int n)\nId(n) ->\n    var r = Make(n)\n    r.Id\n' > "$T/Out/Leak/Leak.bs"
printf 'module Out.Bad\nusing Lib.Api\npublic int Id(int n)\nId(n) -> Make(n)\n' > "$T/Out/Bad/Bad.bs"
echo "== known gap (asserted): an outsider never names Lib.Internal.Types, yet receives and projects its record"
l=$(status "$PROTO" Out/Leak); v="COMPILES: the rule does not stop type leakage"; [ "$l" = 0 ] || { v=UNEXPECTED; bad=1; }
printf '  Out.Leak  (var r = Make(n); r.Id)         prototype=%s  %s\n' "$l" "$v"
echo "  what an outsider's type error says about the hidden type (Out.Bad):"
say "$PROTO" Out/Bad | head -4 | sed "s|$T/||; s/^/    /"
# --- the LIBRARY path (bsc:file_to_dir/2, used by compile_string and the REPL :reload) skips the directory/name
# check, so Self is whatever the file DECLARES. An outsider that declares itself inside the subtree is admitted.
mkdir -p "$T/EvilDir"
printf 'module Shop.Evil\nusing Shop.Internal.Calc\npublic int Total(int n)\nTotal(n) -> Double(n)\n' > "$T/EvilDir/evil.bs"
lib() { ( cd "$T" && erl -noshell -pa "$1" -eval 'case catch bsc:file_to_dir("'"${2:-EvilDir/evil.bs}"'", "'"$W"'/olib") of {ok,_} -> halt(0); _ -> halt(1) end.' >/dev/null 2>&1; echo $? ); }
PEB="$REPO/compiler/_build/default/lib/bsc/ebin"; [ -d "$PEB" ] || PEB="$(dirname "$(dirname "$(dirname "$PRISTINE")")")/lib/bsc/ebin"
echo "== known gap (asserted): self-declared module name. EvilDir/evil.bs declares \`module Shop.Evil\`, uses Shop.Internal.Calc"
cl=$(status "$PROTO" EvilDir); ll=$(lib "$W/proto/_build/default/lib/bsc/ebin"); lp=$(lib "$PEB")
v="library path ADMITS the outsider (pristine too): enforcement is only as good as the module-name check"; { [ "$cl" = 1 ] && [ "$ll" = 0 ] && [ "$lp" = 0 ]; } || { v=UNEXPECTED; bad=1; }
mkdir -p "$T/HonestDir"; printf 'module Billing.Honest\nusing Shop.Internal.Calc\npublic int Total(int n)\nTotal(n) -> Double(n)\n' > "$T/HonestDir/honest.bs"
hl=$(lib "$W/proto/_build/default/lib/bsc/ebin" HonestDir/honest.bs); [ "$hl" = 1 ] || { echo "  CONTROL FAILED: an honestly named outsider must be refused on the library path too (got $hl)"; bad=1; }
echo "  control: honestly named outsider (module Billing.Honest) on the library path, prototype exit=$hl (refused)"
printf '  CLI prototype=%s (refused: name does not match directory)   library prototype=%s   library pristine=%s   %s\n' "$cl" "$ll" "$lp" "$v"
echo "== diagnostics from the prototype"
for c in Billing/Invoice Billing/Ns Billing/Ns2 Acme/Billing Acme/BillingNs; do say "$PROTO" $c | head -2 | sed "s|$T/||; s/^/    /"; done
echo "== (Billing.Direct is refused by the PRISTINE compiler too; that is why one site suffices:)"
say "$PRISTINE" Billing/Direct | head -2 | sed "s|$T/||; s/^/    /"

echo "== compile wall time, 15 interleaved rounds (ms; median [min..max]) -- the corpus has no Internal segment,"
echo "   so this shows no regression in the accept path, not the cost of a refusal"
EX="$REPO/compiler/examples"
tm() { local s e; s=$(date +%s%N); "$1" --src-root "$EX" -o "$W/t" "$EX/$2" >/dev/null 2>&1; e=$(date +%s%N); echo $(( (e-s)/1000000 )); }
for mod in Shop/Reports Shop; do
  a=(); b=(); tm "$PRISTINE" "$mod" >/dev/null; tm "$PROTO" "$mod" >/dev/null
  for i in $(seq 15); do a+=("$(tm "$PRISTINE" "$mod")"); b+=("$(tm "$PROTO" "$mod")"); done
  sa=($(printf '%s\n' "${a[@]}" | sort -n)); sb=($(printf '%s\n' "${b[@]}" | sort -n))
  printf '  %-14s pristine %s [%s..%s]   prototype %s [%s..%s]   (overlapping ranges: no difference resolved)\n' "$mod" "${sa[7]}" "${sa[0]}" "${sa[14]}" "${sb[7]}" "${sb[0]}" "${sb[14]}"
done
echo "== the rule's own cost, isolated (1e6 calls of visible/2, compiled loop)"
mkdir -p "$W/mv" && erlc +export_all -o "$W/mv" "$W/proto/src/bs_check.erl" 2>/dev/null
cat > "$W/mv/mvbench.erl" <<'E2'
-module(mvbench).
-export([run/0]).
run() ->
    Self = list_to_atom("Shop.Orders"), M = list_to_atom("Shop.Internal.Calc"),
    Rs = lists:sort([begin {U, _} = timer:tc(fun() -> spin(Self, M, 1000000) end), U * 1000 / 1000000 end || _ <- lists:seq(1, 7)]),
    io:format("  ~.1f ns per check (median of 7 x 1e6; min ~.1f max ~.1f)~n", [lists:nth(4, Rs), hd(Rs), lists:last(Rs)]).
spin(_, _, 0) -> ok;
spin(S, M, N) -> bs_check:visible(S, M), spin(S, M, N - 1).
E2
erlc -o "$W/mv" "$W/mv/mvbench.erl" && ( cd "$W" && erl -noshell -pa "$W/mv" -eval 'mvbench:run(), halt().' )
[ "$bad" = 0 ] && echo "ALL CASES AS EXPECTED" || { echo "SOME CASE DID NOT BEHAVE AS EXPECTED"; exit 1; }
