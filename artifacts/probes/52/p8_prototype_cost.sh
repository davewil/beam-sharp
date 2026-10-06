#!/usr/bin/env bash
# p8 — what does it COST the compiler to let an FFI declaration carry an application name?
# Method: build PATCHED COPIES of compiler/src (never the repo) with patch_compiler.py, three spellings, each doing three things with the name:
#   parse it, refuse at compile time if code:lib_dir(App) says it is not on the code path, emit it as a beam attribute -bs_needs([...]).
# Claims:
#   P1  the stock compiler REFUSES all three spellings (so the grammar delta is real)
#   P2  each patched compiler accepts its spelling; with the app on ERL_LIBS the program runs (42)  [control: the program is valid]
#   P3  each patched compiler REFUSES at compile time, with a diagnostic, when the app is absent  [the whole feature]
#   P4  yecc reports the same conflict count as stock for all three: no new ambiguity
#   P5  REGRESSION CONTROL: every program under compiler/examples compiles to byte-identical beams (beam_lib:cmp) under stock and each patched compiler
#   P6  the source and compiler delta in lines (diff vs stock, per file)
source "$(dirname "$0")/common.sh"; mk_fakelib
PY=$(command -v python3)
for v in attr inline module; do
  echo "== building variant: $v"; $PY "$PROBES/patch_compiler.py" $v "$WORK/bsc-$v" 2>&1 | sed 's/^/   /'
  printf '#!/usr/bin/env bash\nexec erl -noshell -pa %s/bsc-%s/ebin -eval '"'"'bsc:main(init:get_plain_arguments())'"'"' -extra "$@"\n' "$WORK" $v > "$WORK/bsc-$v.sh"; chmod +x "$WORK/bsc-$v.sh"
done
body='{
    int hello()
}
public int Go()
Go() -> :fakelib_mod.hello()'
declare -A SRC=(
 [attr]="[app: fakelib]
using :fakelib_mod $body"
 [inline]="using :fakelib_mod in :fakelib $body"
 [module]="needs :fakelib

using :fakelib_mod $body" )
for v in attr inline module; do
  echo; echo "=================== spelling: $v"; echo "${SRC[$v]}" | head -3 | sed 's/^/   | /'
  bs_module "V$v" "${SRC[$v]}"
  s=$($BSC --src-root "$WORK/src" -o "$WORK/s_$v" "$WORK/src/V$v" 2>&1 | head -1 | sed "s|$WORK/||"); echo "P1 stock compiler : $s"
  expect "P1 stock refuses $v" "error" "$s"
  r=$(ERL_LIBS="$WORK/libs" "$WORK/bsc-$v.sh" --src-root "$WORK/src" -o "$WORK/o_$v" "$WORK/src/V$v" Go 2>&1); echo "P2 patched, app present: $r"
  expect "P2 $v runs with the app present" "42" "$r"
  q=$(env -u ERL_LIBS "$WORK/bsc-$v.sh" --src-root "$WORK/src" -o "$WORK/q_$v" "$WORK/src/V$v" Go 2>&1 | sed "s|$WORK/||"); echo "P3 patched, app absent : $q"
  expect "P3 $v refused at compile time" "is not on the code path" "$q"
  expect_not "P3 ... not a run-time crash" "crashed" "$q"
done
echo; echo "=================== P5 regression control: compiler/examples, stock vs patched"
mods=$(cd compiler/examples && find . -name '*.bs' -printf '%h\n' | sort -u | sed 's|^\./||')
n=0; same=0; bad=0; refused=0
for m in $mods; do
  n=$((n+1)); $BSC --src-root compiler/examples -o "$WORK/r_stock/$m" "compiler/examples/$m" >/dev/null 2>&1; sst=$?
  ok=1
  for v in attr inline module; do
    "$WORK/bsc-$v.sh" --src-root compiler/examples -o "$WORK/r_$v/$m" "compiler/examples/$m" >/dev/null 2>&1; pst=$?
    [ "$pst" = "$sst" ] || ok=0
    for b in "$WORK/r_stock/$m"/*.beam; do
      [ -f "$b" ] || continue
      [ "$(beams_equal "$b" "$WORK/r_$v/$m/$(basename "$b")")" = "ok" ] || ok=0
    done
  done
  [ "$sst" = 0 ] || refused=$((refused+1))
  if [ $ok = 1 ]; then same=$((same+1)); else bad=$((bad+1)); echo "   DIFFERS: $m"; fi
done
echo "module dirs: $n   identical under stock and all three patched compilers: $same   differing: $bad   (of which stock itself exits non-zero: $refused)"
expect "P5 no regression" "differing: 0" "module dirs: $n   identical: $same   differing: $bad"
echo; echo "=================== P4/P6 compiler delta"
for v in attr inline module; do
  echo "--- $v:"
  tot=0
  for f in bs_parser.yrl bs_check.erl bs_emit.erl bs_diag.erl bs_lexer.xrl; do
    d=$(diff compiler/src/$f "$WORK/bsc-$v/src/$f" | grep -c '^[<>]'); [ "$d" = 0 ] || printf '   %-14s %3d changed lines\n' $f $d; tot=$((tot+d))
  done; echo "   total $tot changed lines (diff '<' + '>' ; includes the shared check/emit/diag part)"
done
echo "--- the part that is NOT shared between spellings (parser only):"
for v in attr inline module; do printf '   %-7s %s changed lines in bs_parser.yrl\n' $v "$(diff compiler/src/bs_parser.yrl "$WORK/bsc-$v/src/bs_parser.yrl" | grep -c '^[<>]')"; done
(cd "$WORK"; cp "$ROOT/compiler/src/bs_parser.yrl" base.yrl; erl -noshell -eval 'yecc:file("base.yrl",[verbose]),halt().' > base.log 2>&1; echo "stock yecc conflicts: $(grep -c 'Parse action conflict' base.log)")
for v in attr inline module; do (cd "$WORK/bsc-$v/src"; erl -noshell -eval 'yecc:file("bs_parser.yrl",[verbose,{parserfile,"/dev/null"}]),halt().' > "$WORK/$v.log" 2>&1; echo "$v yecc conflicts: $(grep -c 'Parse action conflict' "$WORK/$v.log")"); done
sb=$(grep -c 'Parse action conflict' "$WORK/base.log"); for v in attr inline module; do expect "P4 $v same conflict count as stock" "$sb" "$(grep -c 'Parse action conflict' "$WORK/$v.log")"; done
finish
