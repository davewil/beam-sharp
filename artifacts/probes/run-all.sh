#!/bin/bash
# run-all.sh [WORKDIR] — rebuilds the scratch compiler from compiler/src, applies each patch in patches/
# as its own variant, and runs every probe the five decision briefs cite. Output goes to results/.
# Needs: erlang (OTP 25 here), elixir, erlang-eunit, python3. Does NOT touch compiler/src.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; REPO="$(cd "$HERE/../.." && pwd)"
W="${1:-$(mktemp -d)}"; R="${RESULTS:-$HERE/results}"; mkdir -p "$W" "$R"
sel(){ [ -z "${ONLY:-}" ] || [[ " $ONLY " == *" $1 "* ]]; }   # ONLY="57 60" runs just those sections
cp -r "$HERE"/scripts/* "$HERE"/src/* "$W"/; cd "$W"
# ---- build the baseline. DEVIATION: OTP 25 has no leex column support, so the lexer is shimmed to {Line,1}.
mkdir -p bsc && cp -r "$REPO/compiler/src" bsc/src && cd bsc
sed -i 's/TokenLoc/{TokenLine,1}/g' src/bs_lexer.xrl && echo 'adjust_col(_, _, C) -> C.' >> src/bs_lexer.xrl
erl -noshell -eval 'leex:file("src/bs_lexer.xrl",[]), yecc:file("src/bs_parser.yrl"), halt().' >/dev/null
mkdir -p ebin && erlc -o ebin src/*.erl 2>&1 | grep -i " error" ; cp src/bsc.app.src ebin/bsc.app
cat > bsc.sh <<'EOT'
#!/bin/sh
D=$(dirname "$0")
exec erl -noshell -pa "$D/ebin" -eval 'bsc:main(init:get_plain_arguments()), halt(0).' -extra "$@"
EOT
chmod +x bsc.sh; cd "$W"
variant(){ # variant NAME PATCHFILE
  rm -rf "$1"; mkdir "$1"; cp -r bsc/src bsc/ebin bsc/bsc.sh "$1"/
  (cd "$1/src" && patch -s -p1 < "$HERE/patches/$2.patch") || { echo "PATCH FAILED $2"; return; }
  (cd "$1" && erl -noshell -eval 'yecc:file("src/bs_parser.yrl"), halt().' >/dev/null; erlc -o ebin src/*.erl 2>&1 | grep -i " error")
}
variant v57a v57a-parser-folds-negative-int; variant v57b v57b-checker-folds-constants
variant v59a v59a-tag-test-exported-only;  variant v59b v59b-kind-test-on-private; variant v59c v59c-guard-what-is-reachable
variant v60a v60a-subtree-internal-rule
# ---- 57
if sel 57; then

for v in bsc v57a v57b; do echo "=== $v"; rm -rf r57_$v; mkdir r57_$v; (cd r57_$v && ../probe57.sh "$W/$v" 2>&1 | sed 's/M[0-9]*\/M[0-9]*.bs:[0-9:]* //;s/this refinement is not a predicate the checker can read/REFUSED/'); ./probe57g.sh $v; done > "$R/57-refinement-probe.txt" 2>&1
for v in bsc v57a v57b; do echo "== $v"; for a in "100" "-100" "-101"; do ./$v/bsc.sh --src-root rt57 rt57/D D $a </dev/null 2>&1 | head -1; done; ./$v/bsc.sh --src-root rt57 rt57/H </dev/null 2>&1 | head -4; done > "$R/57-runtime-and-residual.txt" 2>&1
escript survey57.escript > "$R/57-erlang-elixir-ast.txt" 2>&1; elixir -e 'IO.inspect(Code.string_to_quoted!("f(n) when n >= -5"), label: "elixir -5")' >> "$R/57-erlang-elixir-ast.txt" 2>&1
fi
# ---- 59
if sel 59; then

for v in bsc v59a v59b; do echo "######## $v"; ./emit.sh $v p59 p59/P | grep -v '^$'; done > "$R/59-emitted-code-and-bytes.txt" 2>&1
for v in bsc v59a; do ./emit.sh $v p59b p59b/Q >/dev/null 2>&1; done
{ escript bench59.escript out_bsc_Q out_v59a_Q; echo "-- null control (same beam both sides):"; escript bench59.escript out_bsc_Q out_bsc_Q; } > "$R/59-private-call-cost.txt" 2>&1
for n in A B C D F; do echo "-- $n"; ./bsc/bsc.sh --src-root p59c p59c/$n </dev/null 2>&1 | head -4; done > "$R/59-can-a-wrong-kind-reach-a-private-fn.txt" 2>&1
./escape59.sh bsc v59a v59b v59c > "$R/59-escaped-private-function.txt" 2>&1
for v in bsc v59a; do ./emit.sh $v p59 p59/P >/dev/null 2>&1; echo "$v: Kind-only forged map (no Total) into exported ViaTag -> $(erl -noshell -pa out_${v}_P -eval 'R = try '"'"'P'"'"':'"'"'ViaTag'"'"'(#{'"'"'Kind'"'"'=>'"'"'P.Order'"'"'}) catch C:E -> {C,E} end, io:format("~p~n",[R]), halt().')"; done >> "$R/59-escaped-private-function.txt" 2>&1
elixir -e 'defmodule M59 do
  def f(x), do: g(x)
  defp g(x), do: x
end
IO.inspect(M59.f(:anything_at_all), label: "Elixir defp, no guard emitted")' >> "$R/59-escaped-private-function.txt" 2>&1
fi
# ---- 60
if sel 60; then

for v in bsc v60a; do echo "######## $v"; for m in Shop/Orders Other Other2 Other3; do echo "-- $m"; ./$v/bsc.sh --src-root p60 p60/$m </dev/null 2>&1 | head -4; done; done > "$R/60-subtree-prototype.txt" 2>&1
escript m60.escript > "$R/60-predicate-cost.txt" 2>&1
elixir -e 'defmodule A do
  @moduledoc false
  def secret, do: :reachable
end
IO.inspect(A.secret(), label: "@moduledoc false callee, called from another module")
{:docs_v1, _, _, _, m, _, _} = Code.fetch_docs(Kernel.Utils); IO.inspect(m, label: "Kernel.Utils moduledoc chunk")' > "$R/60-elixir-hidden-is-callable.txt" 2>&1
mkdir -p y60 && cp bsc/src/bs_parser.yrl y60/base.yrl
python3 - <<'PY'
import re
s0=open('bsc/src/bs_parser.yrl').read()
def mk(rule, term=None):
    s=s0.replace("module_decl -> 'module' modpath : {module, line('$1'), modatom('$2')}.", "module_decl -> 'module' modpath : {module, line('$1'), modatom('$2')}.\n"+rule,1)
    s=s.replace("Nonterminals\n","Nonterminals\n  modpaths\n",1)
    i=s.index("Erlang code.")
    s=s[:i]+"modpaths -> modpath : ['$1'].\nmodpaths -> modpath ',' modpaths : ['$1' | '$3'].\n\n"+s[i:]
    if term: s=s.replace("Terminals\n","Terminals\n  '"+term+"'\n",1)
    return s
open('y60/for.yrl','w').write(mk("module_decl -> 'module' modpath 'for' modpaths : {module, line('$1'), modatom('$2'), '$4'}."))
open('y60/visible.yrl','w').write(mk("module_decl -> 'module' modpath 'visible_to' modpaths : {module, line('$1'), modatom('$2'), '$4'}.",'visible_to'))
PY
for g in base for visible; do echo "== grammar: $g"; (cd y60 && cp $g.yrl g.yrl && erl -noshell -eval 'R=yecc:file("g.yrl",[{verbose,false}]), io:format("~p~n",[R]), halt().' 2>&1 | head -3); done > "$R/60-grammar-conflicts.txt" 2>&1
fi
# ---- 52
if sel 52; then

{ for m in Use Elx; do echo "-- compile $m"; ./bsc/bsc.sh --src-root p52 p52/$m </dev/null 2>&1 | head -4; echo "compile exit=$?"; done
  echo "-- run Use"; ./bsc/bsc.sh --src-root p52 p52/Use Run 1 </dev/null 2>&1 | head -4
  printf -- '-module(e1).\n-export([f/0]).\nf() -> nosuchmod:go().\n' > e1.erl; erlc e1.erl; echo "erlc remote call to absent module: exit=$?"
  printf 'defmodule X1 do\n  def f, do: NoSuchLib.go()\nend\n' > x1.ex; elixirc x1.ex 2>&1 | head -3; } > "$R/52-no-diagnostic-today.txt" 2>&1
escript m52.escript > "$R/52-check-cost-and-attribute-size.txt" 2>&1
escript a52.escript > "$R/52-app-not-derivable-from-module.txt" 2>&1
fi
# ---- 39
if sel 39; then

B="$REPO/aoc/bench"; rm -rf b39 b39_default b39_notype b39_nossa; mkdir -p b39 b39_default b39_notype b39_nossa
erlc -o b39 $B/bench_erl.erl; elixirc -o b39 $B/bench_ex.ex >/dev/null 2>&1; ./bsc/bsc.sh --src-root $B -o b39 $B/Day01 </dev/null 2>&1 | head -2
erlc -o b39_default $B/bench_erl.erl; erlc +no_type_opt -o b39_notype $B/bench_erl.erl; erlc +no_ssa_opt -o b39_nossa $B/bench_erl.erl
sed 's/{"Gleam",      fun bench_gleam:part_two\/1},//' $B/bench.erl > b39/bench.erl && erlc -o b39 b39/bench.erl
{ for i in 1 2 3; do erl -noshell -pa b39 -eval 'bench:main(["'$REPO'/aoc/2025/Day01/input.txt"])' | tail -7; done; } > "$R/39-three-way-bench.txt" 2>&1
{ escript disasm39.escript b39; escript cmp39.escript b39; for d in b39_default b39_notype b39_nossa; do erl -noshell -eval '{beam_file,_,_,_,_,Fs}=beam_disasm:file("'$d'/bench_erl.beam"), [io:format("'$d' spin: instrs=~p tr_count=~p~n",[length(C), length(string:split(lists:flatten(io_lib:format("~p",[C])),"{tr,",all))-1])||{function,spin,4,_,C}<-Fs], halt().'; done; } > "$R/39-disassembly.txt" 2>&1
escript t39.escript > "$R/39-annotation-strip-timing.txt" 2>&1
erl -noshell -eval 'io:format("otp ~s erts ~s arch ~s emu ~p~n",[erlang:system_info(otp_release),erlang:system_info(version),erlang:system_info(system_architecture),erlang:system_info(emu_flavor)]),halt().' > "$R/00-environment.txt"
fi
# ---- regression: failing-test SET per variant vs baseline (baseline fails ~583 on OTP 25: maps:iterator/2 is OTP 26+)
if sel regression; then

for v in ${VARIANTS:-bsc v57a v57b v59a v59b v59c v60a}; do ./runeunit.sh $v >/dev/null 2>&1; T=$W/tests_$v; (cd "$REPO/compiler" && timeout 900 erl -noshell -pa $W/$v/ebin -pa $T -eval 'Ms=[list_to_atom(filename:basename(F,".beam"))||F<-filelib:wildcard("'$T'/*.beam")], eunit:test(Ms,[verbose]), halt().' > $W/eu_$v.log 2>&1); done
for v in ${VARIANTS:-bsc v57a v57b v59a v59b v59c v60a}; do [ "$v" = bsc ] && continue; echo "== $v: tests failing here and not in baseline"; diff <(grep -h '\*failed\*' eu_bsc.log | sed 's/\[[0-9.]* s\]//' | sort) <(grep -h '\*failed\*' eu_$v.log | sed 's/\[[0-9.]* s\]//' | sort) | grep '^>' ; echo "(baseline failing: $(grep -c '\*failed\*' eu_bsc.log), variant failing: $(grep -c '\*failed\*' eu_$v.log))"; done > "$R/regression-diff-vs-baseline.txt" 2>&1
fi
echo "done; work dir $W; results in $R"
