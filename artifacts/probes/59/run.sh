#!/bin/sh
# Reproduces every probe for ticket 59 from scratch.  Usage: ./run.sh [ROUNDS]   (default 15; the e/ benchmark takes ~3 min)
# Needs: OTP 29 + Elixir 1.20.4 + Gleam 1.18.1 under /tmp/otp/bin; python3; taskset.  Writes NN.out beside this script.
# compiler/ is READ-ONLY: the two PROTOTYPE compilers are built from patched COPIES of compiler/src in $W.
set -e
cd "$(dirname "$0")"; HERE=$(pwd)
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8 ELIXIR_ERL_OPTIONS="+fnu"
W=${WORK:-/tmp/bs59-work}; ROUNDS=${1:-15}
quiet() { grep -v '^%\|^$\|^ ' || true; }
{ erl -noshell -eval 'io:format("OTP ~s~n",[erlang:system_info(otp_release)]),halt().'; elixir --version | tail -1; gleam --version
  echo "arch: $(uname -m), cores: $(nproc), jit: $(erl -noshell -eval 'io:format("~p",[erlang:system_info(emu_flavor)]),halt().')"
  git -C /home/user/beam-sharp rev-parse --short HEAD; } > 00-env.out 2>&1
./build-bsc.sh $W/base > /dev/null 2>&1; ./build-bsc.sh $W/proto prototype-tag-exported-only.patch >/dev/null 2>&1
./build-bsc.sh $W/wide prototype-kind-everywhere.patch >/dev/null 2>&1
echo "base=shipped compiler/src  proto=PROTOTYPE tag test exported-only  wide=PROTOTYPE int/float kind test on private too" >> 00-env.out
ls $W/*/ebin/bs_emit.beam >> 00-env.out

# ---- a: is the tag test emitted on a private function; absent/present for exported (BASE, shipped compiler)
( cd a; rm -rf out; ../bsc-run.sh $W/base/ebin -o out Shop Mk
  ../dump.escript out/Shop.beam abstr PubAmount PrivAmount PubInt PrivInt ViaCart
  echo '--- BEAM asm (post-optimisation) PubAmount / PrivAmount / PubInt / PrivInt'
  ../dump.escript out/Shop.beam asm PubAmount PrivAmount PubInt PrivInt | grep -v 'line\|func_info\|^$' ) > 01-a-emitted.out 2>&1

# ---- b: forged record through an exported function into a private one, with and without the private guard
( cd b; for v in base proto; do rm -rf out-$v; ../bsc-run.sh $W/$v/ebin -o out-$v Forge 2>&1 | quiet
    echo "=================== compiler: $v  $( [ $v = proto ] && echo '(PROTOTYPE: no tag test on private fns)' || echo '(shipped)')"
    ../dump.escript out-$v/Forge.beam abstr Amount Classify
    echo "--- foreign Erlang caller"; ./forge.escript out-$v
    echo "--- foreign Elixir caller"; elixir forge.exs out-$v; done
  rm -rf out-wide; ../bsc-run.sh $W/wide/ebin -o out-wide Forge 2>&1 | quiet
  echo "=================== compiler: wide (PROTOTYPE: kind test also on private fns)"; ../dump.escript out-wide/Forge.beam abstr Classify
  ./forge.escript out-wide | grep -i 'ViaOctets' ) > 02-b-forged.out 2>&1

# ---- c: .beam byte delta, N private functions per module
( cd c; rm -rf w1 w20; for n in 1 20; do ./gen.py w$n $n
    for v in base proto wide; do for m in CostRec CostInt; do ../bsc-run.sh $W/$v/ebin -o w$n/o-$v w$n/$m 2>&1 | quiet; done
      echo "N=$n $v  CostRec[file stripped Code] $(./sizes.escript w$n/o-$v/CostRec.beam)   CostInt[file stripped Code] $(./sizes.escript w$n/o-$v/CostInt.beam)"; done; done ) > 03-c-bytes.out 2>&1

# ---- d: does the BEAM compiler / JIT elide the guard?   (d/run_d.sh, so it can be re-run alone: ./d/run_d.sh $W)
d/run_d.sh $W > 04-d-elision.out 2>&1

# ---- f/g: neighbours
( cd f; elixir elixir_defp.exs; echo; ./run_erlang.sh ) > 06-f-elixir-erlang.out 2>&1
( cd g; rm -rf build; gleam build 2>&1 | tail -2; cat build/dev/erlang/probe/_gleam_artefacts/probe.erl | grep -v '^-file'; echo '--- foreign Erlang caller'; ./forge.escript build/dev/erlang/probe/ebin ) > 07-g-gleam.out 2>&1

# ---- h: how many modules of the corpus change under each prototype
h/corpus.sh $W > 08-h-corpus.out 2>&1; rm -rf h/o

# ---- e: call-time (slowest; last).  SKIP_E=1 skips it.
[ -n "$SKIP_E" ] || ( cd e; for v in base proto wide; do rm -rf out-$v; ../bsc-run.sh $W/$v/ebin -o out-$v Bench 2>&1 | quiet; done
  rm -rf out-base2; cp -r out-base out-base2
  echo "LoopRec/LoopCtl asm identical base vs proto (excl. labels/lines):"
  for v in base proto; do ../dump.escript out-$v/Bench.beam asm LoopRec | grep -v 'line\|label' | md5sum; ../dump.escript out-$v/Bench.beam asm LoopCtl | grep -v 'line\|label' | md5sum; done
  ROUNDS=$ROUNDS ITERS=50000000 python3 bench.py ) > 05-e-calltime.out 2>&1
echo done
