#!/bin/bash
# Ticket 60 (ENG-242) probes. Prints PASS/FAIL per probe against the expectation stated in the
# comment above that probe, written BEFORE the probe was first run. Re-runnable from a clean checkout.
# Needs: the reference compiler wrapper $SP/bsc.sh, its generated lexer/parser in $SP/bsc/gen,
# erl/erlc/escript (OTP 25), elixir/mix 1.14, gleam 1.12 ($GLEAM), elm 0.19.2 ($ELM).
SP=${SP:-/tmp/claude-0/-home-user-beam-sharp/40070274-2489-5304-8393-d8d915b713dc/scratchpad}
GLEAM=${GLEAM:-/tmp/claude-0/tools/gleam}
ELM=${ELM:-/tmp/claude-0/tools/node_modules/.bin/elm}
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../.." && pwd)
T=${T:-/tmp/claude-0/p60run}
rm -rf "$T"; mkdir -p "$T"
FAILS=0
ok()   { echo "PASS $1"; }
bad()  { echo "FAIL $1  ($2)"; FAILS=$((FAILS+1)); }
# check ID "description" EXIT_WANTED "grep-pattern-or-empty" OUTPUT EXIT_GOT
check() { # id want_exit pattern out got_exit
  if [ "$5" = "$2" ] && { [ -z "$3" ] || printf '%s' "$4" | grep -Fq -- "$3"; }; then ok "$1"
  else bad "$1" "want exit $2 + '$3'; got exit $5: $(printf '%s' "$4" | head -3 | tr '\n' '|')"; fi; }
BSC() { "$SP/bsc.sh" "$@"; }

echo "### Build the experimental compiler copy (never touches $REPO/compiler)"
mkdir -p "$T/base-src" "$T/int-src" "$T/ebin-base" "$T/ebin-int" "$T/ebin-x"
cp -r "$REPO/compiler/src/." "$T/base-src/"; cp -r "$REPO/compiler/src/." "$T/int-src/"
( cd "$T/int-src" && patch -s -p1 < "$HERE/p3/internal.patch" ) || { echo "FAIL patch"; exit 1; }
erlc -o "$T/ebin-base" "$T"/base-src/*.erl "$SP"/bsc/gen/*.erl >/dev/null 2>&1
erlc -o "$T/ebin-int"  "$T"/int-src/*.erl  "$SP"/bsc/gen/*.erl >/dev/null 2>&1
erlc +export_all +nowarn_export_all -o "$T/ebin-x" "$T/int-src/bs_check.erl" >/dev/null 2>&1
BSCX() { local eb=$1; shift; erl -noshell -pa "$eb" -eval 'bsc:main(init:get_plain_arguments()),halt().' -extra "$@"; }

echo "### P1 (real compiler): private refused, public accepted, nothing in between"
# EXPECTED before run: UsesPub exit 0 prints 7 (Pub(3)=Priv(3)+1=7); UsesPrivQ (Lib.Priv) exit 1 naming `private`;
# UsesPrivU (unqualified Priv with `using Lib`) exit 1 naming `private`; a third marker word `internal`
# is a syntax error; a private helper in a SIBLING FILE of the same directory-module is fine (Apply(2)=2*3+1=7).
cd "$HERE/p1"
o=$(BSC --src-root src -o $T/p1 src/UsesPub Go 3 2>&1); check P1a 0 "7" "$o" $?
o=$(BSC --src-root src -o $T/p1 src/UsesPrivQ Go 3 2>&1); check P1b 1 'declares `private`' "$o" $?
o=$(BSC --src-root src -o $T/p1 src/UsesPrivU Go 3 2>&1); check P1c 1 'declares `private`' "$o" $?
o=$(BSC --src-root src -o $T/p1 src/UsesInternalKw Go 3 2>&1); check P1d 1 "syntax error before: int" "$o" $?
o=$(BSC --src-root src -o $T/p1 src/Orders Apply 2 2>&1); check P1e 0 "7" "$o" $?

echo "### P2 (real compiler, unpatched): under the F15 layout any module can name any other"
# EXPECTED before run: modules Shop.Orders, Shop.Reports (namespace using), Vendor.Tool, Tests.LedgerTest,
# Vendor.NsTool and Vendor.NsAll all compile and print 101 although Ledger sits under Shop/Internal/;
# but a call with NO `using` (Bypass, Bypass2) is refused "called but never imported": `using` is the only gate.
cd "$HERE/p2"
for pair in "Shop/Orders Place" "Shop/Reports Total" "Vendor/Tool Sneak" "Tests/LedgerTest Go" "Vendor/NsTool Go" "Vendor/NsAll Go"; do set -- $pair
  o=$(BSC --src-root src -o $T/p2 src/$1 $2 1 2>&1); check "P2-$1" 0 101 "$o" $?; done
for m in Vendor/Bypass Vendor/Bypass2; do
  o=$(BSC --src-root src -o $T/p2 src/$m Go 1 2>&1); check "P2-$m" 1 "is called but never imported" "$o" $?; done

echo "### P3 (patched COPY of the compiler): Owner.Internal.X nameable only from Owner and Owner.*"
# EXPECTED before run: Shop.Orders and Shop.Reports (under Shop.) still print 101; Vendor.Tool, Tests.LedgerTest and
# Vendor.NsTool (using the namespace Shop.Internal) are refused with "is internal to Shop"; Vendor.NsAll (using Shop,
# then Internal.Ledger.Post) is refused too; moving the same module out of Internal (p2m) makes Vendor.Tool compile.
cd "$HERE/p2"
for pair in "Shop/Orders Place" "Shop/Reports Total"; do set -- $pair
  o=$(BSCX $T/ebin-int --src-root src -o $T/p3 src/$1 $2 1 2>&1); check "P3-$1" 0 101 "$o" $?; done
for m in Vendor/Tool Tests/LedgerTest Vendor/NsTool; do
  o=$(BSCX $T/ebin-int --src-root src -o $T/p3 src/$m $( [ $m = Tests/LedgerTest ] && echo Go || ([ $m = Vendor/Tool ] && echo Sneak || echo Go)) 1 2>&1)
  check "P3-$m" 1 "is internal to Shop" "$o" $?; done
o=$(BSCX $T/ebin-int --src-root src -o $T/p3 src/Vendor/NsAll Go 1 2>&1); check "P3-Vendor/NsAll" 1 "called but never imported" "$o" $?
echo "   (diagnostic wart, recorded: NsAll's message tells the author to add \`using Internal.Ledger\`, which is not a fix)"
cd "$HERE/p2m"; o=$(BSCX $T/ebin-int --src-root src -o $T/p3 src/Vendor/Tool Sneak 1 2>&1); check "P3-moved-out-of-Internal" 0 101 "$o" $?

echo "### P3b delta size: lines changed in the copy (measured from the patch)"
add=$(grep -c '^+[^+]' "$HERE/p3/internal.patch"); del=$(grep -c '^-[^-]' "$HERE/p3/internal.patch")
echo "   +$add -$del lines across $(grep -c '^+++' "$HERE/p3/internal.patch") files (bs_check.erl, bs_diag.erl)"
# EXPECTED before run: fewer than 40 lines added, both in add_import's neighbourhood and the diagnostic table.
[ "$add" -lt 40 ] && ok P3b-delta || bad P3b-delta "added $add"

echo "### P3c checker cost: per-import guard (bs_check:internal_ok/2, ebin built with +export_all), and 51-module compile"
# EXPECTED before run: guard < 10 microseconds per call; whole-tree compile median within 20% of the unpatched compiler.
ns=$(erl -noshell -pa $T/ebin-int -pa $T/ebin-x -eval 'N=1000000,{T1,_}=timer:tc(fun()->[bs_check:internal_ok(list_to_atom("Shop.Internal.M07"),list_to_atom("Shop.A12"))||_<-lists:seq(1,N)] end),{T0,_}=timer:tc(fun()->[ok||_<-lists:seq(1,N)] end),io:format("~p",[round((T1-T0)*1000/N)]).' -s init stop)
echo "   guard: $ns ns/call (net of loop), 1,000,000 calls"; [ "$ns" -lt 10000 ] && ok P3c-guard || bad P3c-guard "$ns ns"
cd "$HERE/p3"; rm -rf tree; python3 gen50.py tree; echo "   tree modules: $(find tree -name '*.bs' | wc -l); using lines: $(grep -rh '^using ' tree | wc -l)"
erlc -o $T "$HERE/p3/time.erl" >/dev/null 2>&1
declare -A MED
for round in 1 2; do for eb in base int; do
  line=$(erl -noshell -pa $T/ebin-$eb -pa $T -eval 'time:run("tree","tree/Shop/All",15)' -s init stop 2>&1 | tail -1)
  echo "   round $round $eb: $line"; MED[$eb$round]=$(echo "$line" | sed 's/.*median_ms=\([0-9.]*\).*/\1/'); done; done
python3 - "${MED[base1]}" "${MED[int1]}" "${MED[base2]}" "${MED[int2]}" <<'PY' && ok P3c-compile-time || bad P3c-compile-time "median differs >20%"
import sys; b1,i1,b2,i2=map(float,sys.argv[1:]); sys.exit(0 if abs(i1-b1)/b1<.2 and abs(i2-b2)/b2<.2 else 1)
PY

echo "### P4 runtime emission unaffected: .beam chunks (except CInf) identical with and without the rule"
# EXPECTED before run: 51 beams, 0 differing between unpatched and patched compilers on the 51-module tree;
# control 1: unpatched vs unpatched also 0 (CInf excluded because it carries the compile time);
# control 2 (must report a difference to be a valid comparator): one edited body (Shop.Internal.M03) differs in M03 and
# in nothing else that does not depend on it: expected 1 differing beam.
cd "$HERE/p3"
BSCX $T/ebin-base --src-root tree -o $T/b1 tree/Shop/All Go 1 >/dev/null 2>&1
BSCX $T/ebin-base --src-root tree -o $T/b2 tree/Shop/All Go 1 >/dev/null 2>&1
BSCX $T/ebin-int  --src-root tree -o $T/i1 tree/Shop/All Go 1 >/dev/null 2>&1
o=$(./cmp_beams.escript $T/b1 $T/i1); check P4-patched-vs-base 0 "files=51 differing_excluding_CInf=0" "$o" $?
o=$(./cmp_beams.escript $T/b1 $T/b2); check P4-control-same-compiler 0 "differing_excluding_CInf=0" "$o" $?
# (same relative paths matter: the Line/Attr chunks embed the source path, so the control compiles from an identical relative layout)
mkdir -p $T/alt; cp -r tree $T/alt/tree; sed -i 's/n + 3/n + 4/' $T/alt/tree/Shop/Internal/M03/M03.bs
( cd $T/alt && BSCX $T/ebin-base --src-root tree -o $T/b3 tree/Shop/All Go 1 >/dev/null 2>&1 )
o=$(./cmp_beams.escript $T/b1 $T/b3); check P4-control-edited-body-must-differ 1 "differing_excluding_CInf=" "$o" $?
echo "   ($o)"

echo "### P5 the rule is compile-time only: an Erlang caller names the internal module freely"
# EXPECTED before run: with the PATCHED compiler having compiled Shop.Orders (which legitimately reaches
# Shop.Internal.Ledger), erl calls 'Shop.Internal.Ledger':'Post'(1) and gets 101.
cd "$HERE/p2"; BSCX $T/ebin-int --src-root src -o $T/p5 src/Shop/Orders Place 1 >/dev/null 2>&1
o=$(erl -noshell -pa $T/p5 -eval "io:format(\"~p\",['Shop.Internal.Ledger':'Post'(1)])" -s init stop 2>&1); check P5-erlang-bypass 0 101 "$o" $?

echo "### N1-N3 Erlang/OTP 25 toy: unexported call unchecked at compile time, undef at run time, xref reports it"
o=$("$HERE/n_erlang/probe.escript" 2>&1); rc=$?; echo "$o" | sed 's/^/   /'; [ $rc = 0 ] && ok N1-N3-erlang || bad N1-N3-erlang "rc=$rc"

echo "### N4 Elixir 1.14: @moduledoc false / private across two path-dependent mix apps"
# EXPECTED before run: AppB compiles with exit 0; the ONLY message is a WARNING that AppA.Hidden.really_private/1
# is undefined or private (the defp); calling AppA.Hidden.secret/1 (@moduledoc false, @doc false) gives no message;
# `mix run` prints 84.
rm -rf $T/ex; cp -r "$HERE/n_elixir" $T/ex; cd $T/ex/app_b
export HEX_OFFLINE=1 MIX_BUILD_PATH=$T/mixbuild
o=$(mix compile 2>&1); rc=$?
echo "$o" | sed 's/^/   /'
{ [ $rc = 0 ] && echo "$o" | grep -q "warning: AppA.Hidden.really_private/1 is undefined or private" && ! echo "$o" | grep -q "secret" && ! echo "$o" | grep -qi "error"; } && ok N4-elixir-compile || bad N4-elixir-compile "rc=$rc"
o=$(mix run -e 'IO.inspect(AppB.Caller.go())' 2>&1 | tail -1); [ "$o" = 84 ] && ok N4-elixir-run || bad N4-elixir-run "$o"
unset MIX_BUILD_PATH
o=$(elixir "$HERE/n_elixir/docs.exs" 2>&1); echo "$o" | sed 's/^/   /'
{ echo "$o" | grep -q "invisible to documentation extraction" || echo "$o" | grep -q "Module doc line"; } && echo "$o" | grep -q "xref modes: callers, trace, graph" && echo "$o" | grep -q "forbid/restrict/boundary: false" && ok N5-elixir-docs || bad N5-elixir-docs ""

echo "### N6 Gleam 1.12: internal modules and @internal across a PATH dependency"
# EXPECTED before run (stated first, from my prior belief about Gleam): the compiler REFUSES `import lib/internal/secret`
# and the @internal function lib.marked_internal from package `app` (a path dependency).
# RESULT: that expectation was FALSIFIED (see the FALSIFIED line); the observed behaviour is then asserted:
# build exit 0 with no warning, and lib's package-interface.json lists neither the internal module nor marked_internal.
rm -rf $T/gl; cp -r "$HERE/n_gleam" $T/gl; cd $T/gl/app
o=$($GLEAM build 2>&1); rc=$?; echo "$o" | sed 's/^/   /'
if [ $rc != 0 ]; then ok N6-gleam-refuses-as-first-expected
else echo "FALSIFIED N6: expected the compiler to refuse cross-package use of internal items; observed exit 0, no warning"; fi
{ [ $rc = 0 ] && ! echo "$o" | grep -qi "warning\|error\|internal"; } && ok N6-gleam-build-accepts || bad N6-gleam-build-accepts "rc=$rc"
cd ../lib; $GLEAM docs build >/dev/null 2>&1
o=$(python3 -c "
import json; d=json.load(open('build/dev/docs/lib/package-interface.json'))
print(sorted(d['modules']), {m:sorted(v['functions']) for m,v in d['modules'].items()})"); echo "   interface: $o"
[ "$o" = "['lib'] {'lib': ['public_api']}" ] && ok N6-gleam-docs-hide || bad N6-gleam-docs-hide "$o"

echo "### N7 Elm 0.19.2: NOT MEASURED — expected to fail offline at the package list"
cd "$HERE/n_elm"; o=$(timeout 60 $ELM make src/Main.elm --output=/dev/null 2>&1); rc=$?
echo "$o" | head -4 | sed 's/^/   /'
[ $rc != 0 ] && echo "$o" | grep -q "PROBLEM LOADING PACKAGE LIST" && ok N7-elm-cannot-run-so-not-measured || bad N7-elm "elm ran or failed differently; rc=$rc"
rm -rf "$HERE/n_elm/elm-stuff" 2>/dev/null

echo; [ $FAILS = 0 ] && echo "ALL PROBES PASS" || echo "$FAILS PROBE(S) FAILED"
exit $FAILS
