#!/usr/bin/env bash
# run_suite.sh VARIANT : run the repo's eunit suite (compiler/test/*.erl) against a locally built variant
# without rebar3. VARIANT = base | A2 | B1 | B2 ; needs build_bsc.sh run for it first
#   base:  B=/tmp/bsc57      SRC=compiler/src
#   other: B=/tmp/bsc57-V    SRC=/tmp/src57-V
# Tests that need the bsc ESCRIPT skip themselves (no rebar3 here), identically for every variant.
set -uo pipefail
v=$1; root=/home/user/beam-sharp
if [ "$v" = base ]; then ebin=/tmp/bsc57/ebin; src=$root/compiler/src; else ebin=/tmp/bsc57-$v/ebin; src=/tmp/src57-$v; fi
r=/tmp/run57-$v; rm -rf "$r"; mkdir -p "$r/compiler/_build/x"
for f in examples bin test rebar.config; do ln -s $root/compiler/$f "$r/compiler/$f"; done
ln -s "$src" "$r/compiler/src"; ln -s $root/aoc "$r/aoc"
[ -d /tmp/tests57 ] || { mkdir -p /tmp/tests57; erlc -o /tmp/tests57 +debug_info $root/compiler/test/*.erl; }
# stand-in for `rebar3 escriptize`: an escript archive of the variant's ebin (several tests drive `bsc` as a subprocess)
mkdir -p "$r/compiler/_build/default/bin"
erl -noshell -eval "
  Fs = [{\"bsc/ebin/\"++filename:basename(F), element(2,file:read_file(F))} || F <- filelib:wildcard(\"$ebin/*\")],
  ok = escript:create(\"$r/compiler/_build/default/bin/bsc\", [shebang, {emu_args, \"+pc unicode -escript main bsc\"}, {archive, Fs, []}]), halt()."
chmod +x "$r/compiler/_build/default/bin/bsc"
cd "$r/compiler/_build/x"
mods=$(ls /tmp/tests57/*_tests.beam | xargs -n1 basename | sed 's/\.beam//' | tr '\n' ',' | sed 's/,$//')
LANG=C.UTF-8 LC_ALL=C.UTF-8 erl +pc unicode -noshell -pa $ebin -pa /tmp/tests57 -eval "R = eunit:test([$mods], [{report,{eunit_surefire,[{dir,\".\"}]}}]), io:format(\"RESULT ~p~n\",[R]), halt()." 2>&1 | tail -5
python3 - <<'PY'
import glob,re
t=f=e=s=0; bad=[]
for p in glob.glob('TEST-*.xml'):
    x=open(p,errors='replace').read()
    m=re.search(r'<testsuite[^>]*>',x).group(0)
    g=lambda k:int(re.search(k+r'="(\d+)"',m).group(1))
    t+=g('tests');f+=g('failures');e+=g('errors');s+=g('skipped')
    for c in re.finditer(r'<testcase[^>]*name="([^"]*)"[^>]*>\s*<(failure|error)',x): bad.append(p+':'+c.group(1))
print("tests",t,"failures",f,"errors",e,"skipped",s)
for b in sorted(bad): print("FAIL",b)
PY
