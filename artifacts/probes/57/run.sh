#!/usr/bin/env bash
# run.sh -- reproduce every measurement behind artifacts/57-negative-literals-in-refinements.md
# from scratch.  Nothing outside artifacts/ and /tmp is written; compiler/ is only read.
#   ./run.sh          everything except the slow unit suite
#   EUNIT=1 ./run.sh  also runs the in-VM unit modules against each build (~6 min, 4 in parallel)
# Toolchain: OTP 29 at /tmp/otp (see ENV.md); rebar3 is broken, so builds are by hand.
set -u
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8 ELIXIR_ERL_OPTIONS="+fnu"
here=$(cd "$(dirname "$0")" && pwd); cd "$here"
SRC=/home/user/beam-sharp/compiler/src
out=$here/out; rm -rf "$out"; mkdir -p "$out"
W=/tmp/p57; rm -rf $W; mkdir -p $W

echo "[1/9] build baseline + 3 PROTOTYPES (proto/A proto/B proto/C are copies of compiler/src, patched)"
for p in base A B C; do
  s=$SRC; [ $p != base ] && s=$here/proto/$p
  ./build.sh "$s" /tmp/b57_$p > "$out/build_$p.log" 2>&1 || { echo "build $p failed"; exit 1; }
done
for p in A B C; do diff -u $SRC/bs_parser.yrl proto/$p/bs_parser.yrl > "$out/proto_$p.diff"; diff -u $SRC/bs_check.erl proto/$p/bs_check.erl >> "$out/proto_$p.diff"; done

echo "[2/9] yecc conflicts (total 'conflicts: N shift/reduce' + the precedence-resolved blocks)"
for p in base A B C; do
  ( cd /tmp/b57_$p/src && erl -noshell -eval 'yecc:file("bs_parser.yrl",[verbose,{report,true}]), halt().' 2>&1 ) > "$out/yecc_$p.txt"
  printf '%-5s %s | precedence-resolved blocks: %s\n' $p "$(grep -o 'conflicts: .*' $out/yecc_$p.txt)" \
     "$(awk '/Conflicts resolved by operator/{f=1} f&&/Parse action conflict/{n++} END{print n+0}' $out/yecc_$p.txt)"
done | tee "$out/conflicts.out"

echo "[3/9] parse trees"
for p in base A C; do echo "######## $p"; ./ast.escript /tmp/b57_$p/ebin; done > "$out/ast.out" 2>&1; echo "  -> out/ast.out"

echo "[4/9] the table (ticket rows + extras), guard agreement"
{ ./table.sh /tmp/b57_base/ebin BASELINE; for p in A B C; do ./table.sh /tmp/b57_$p/ebin "PROTOTYPE $p"; done; } 2>&1 | sed 's#/tmp/tmp\.[A-Za-z0-9]*/##g' > "$out/table.out"; echo "  -> out/table.out"

echo "[4b] can a program USE a negative literal once the type is writable?"
{ for p in base A B C; do ./literal_use.sh /tmp/b57_$p/ebin "$([ $p = base ] && echo BASELINE || echo "PROTOTYPE $p")"; done; } > "$out/literal_use.out" 2>&1; echo "  -> out/literal_use.out"

echo "[5/9] residual round trip"
{ for p in base A B C; do ./roundtrip.sh /tmp/b57_$p/ebin $p; done; } > "$out/roundtrip.out" 2>&1; echo "  -> out/roundtrip.out"

echo "[6/9] ticket 38's own probe: as shipped (needs rebar3) and with only the compiler lookup swapped"
mkdir -p $W/orig/wayfinder/prototypes; cp /home/user/beam-sharp/wayfinder/prototypes/38b_divisor_expressiveness.sh $W/orig/wayfinder/prototypes/
( cd $W/orig && bash wayfinder/prototypes/38b_divisor_expressiveness.sh ) > "$out/38b_as_is.out" 2>&1; echo "as-is exit status: $?" >> "$out/38b_as_is.out"
./shim38b.sh /tmp/b57_base/ebin > "$out/38b_shim_base.out" 2>&1
for p in A B C; do ./shim38b.sh /tmp/b57_$p/ebin > "$out/38b_shim_$p.out" 2>&1; done
tail -3 "$out/38b_as_is.out"; tail -1 "$out/38b_shim_base.out"

echo "[7/9] neighbours"
neighbours/erlang.escript > "$out/n_erlang.out" 2>&1
elixir neighbours/elixir.exs > "$out/n_elixir.out" 2>&1; escript neighbours/elixir_unary.escript >> "$out/n_elixir.out" 2>&1
neighbours/gleam.sh > "$out/n_gleam.out" 2>&1
neighbours/elm.sh > "$out/n_elm.out" 2>&1; echo "  -> out/n_*.out"

echo "[8/9] compile-time: 80 types + 80 functions, 30 runs in-VM (2 rounds), no other load"
./gen_heavy.sh $W/HeavyPos pos 80; sed -i 's/^module .*/module HeavyPos/' $W/HeavyPos/a.bs
./gen_heavy.sh $W/HeavyNeg neg 80; sed -i 's/^module .*/module HeavyNeg/' $W/HeavyNeg/a.bs
{ for r in 1 2; do for p in base A B C; do echo "== $p HeavyPos (round $r)"; ./bench.escript /tmp/b57_$p/ebin $W/HeavyPos 30; done; done
  for p in base A B C; do echo "== $p HeavyNeg (diagnostics suppressed)"; ./bsc.sh /tmp/b57_$p/ebin $W/HeavyNeg >/dev/null 2>&1; rc=$?; echo "  CLI exit status: $rc"
    [ $rc = 0 ] && ./bench.escript /tmp/b57_$p/ebin $W/HeavyNeg 30; done; } > "$out/bench.out" 2>&1; echo "  -> out/bench.out"

if [ "${EUNIT:-0}" = 1 ]; then
  echo "[9/9] unit modules (in parallel)"
  for p in base A B C; do ./eunit.sh /tmp/b57_$p/ebin $p > "$out/eunit_$p.out" 2>&1 & done; wait
  for p in A B C; do echo "== failures in $p not in base:"; diff <(grep 'failed\*' $out/eunit_base.out | sed 's/^\[base\] //' | sort) <(grep 'failed\*' $out/eunit_$p.out | sed "s/^\[$p\] //" | sort) | grep '^>' ; done | tee "$out/eunit_delta.out"
else echo "[9/9] unit modules skipped (EUNIT=1 to run); last captured run is in out_eunit/"; fi
