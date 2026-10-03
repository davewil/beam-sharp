#!/usr/bin/env bash
# Emit the BEAM assembler (+to_asm, i.e. erlc -S) of the same program from all four front ends and
# compare the hot functions. {tr,Reg,Type} are the type annotations the JIT reads.
set -e
source "$(dirname "$0")/../common.sh"
cd "$(dirname "$0")"; rm -rf work; mkdir work; cd work
B="$PWD/../../01-rerun/build"   # built by probe 01
[ -d "$B" ] || bash ../../01-rerun/run.sh >/dev/null
erlc -S -o . "$BENCH/bench_erl.erl"                       && mv bench_erl.S erlang.S
erlc -S -o . "$B/gleam/build/dev/erlang/bench_gleam/_gleam_artefacts/bench_gleam.erl" && mv bench_gleam.S gleam.S
erlc -o . ../dumpforms.erl; erl -noshell -pa . -pa /tmp/otp/lib/elixir/lib/elixir/ebin -eval 'dumpforms:main(["'"$B"'/Elixir.BenchEx.beam","elixir.forms"])'
erl -noshell -eval '{ok,Fs}=file:consult("elixir.forms"), {ok,_,Asm}=compile:noenv_forms(Fs,[to_asm,report]), {ok,Fd}=file:open("elixir.S",[write]), beam_listing:module(Fd,Asm), file:close(Fd), halt().'
( cd "$REPO" && $BSC -o "$OLDPWD" aoc/bench/Day01 ) >/dev/null
erlc +from_abstr -S Day01.abstr
mv Day01.S beamsharp.S; ls
for f in erlang elixir gleam beamsharp; do
  echo; echo "######## $f.S: function spin/'Spin' (4 args) ########"
  awk '/^\{function, *(spin|.Spin.), *4/{p=1} p{print} /^\{function/ && p && !/(spin|.Spin.), *4/{exit}' $f.S | head -70
done
echo; echo "######## counts of {tr, annotations in Spin/Wrap per front end ########"
for f in erlang elixir gleam beamsharp; do
  n=$(awk '/^\{function, *(spin|.Spin.), *4/{p=1;next} /^\{function/{p=0} p' $f.S | grep -c '{tr,' || true)
  i=$(awk '/^\{function, *(spin|.Spin.), *4/{p=1;next} /^\{function/{p=0} p' $f.S | grep -c '^ *{\(gc_bif\|bif\|call\|test\|move\|select\|label\|jump\|get\|put\|return\|allocate\|deallocate\|line\|func_info\|call_last\|call_only\|init\|trim\|is_\)' || true)
  echo "$f: tr-annotations-in-Spin=$n  instruction-lines-in-Spin=$i"
done
echo; echo "######## functions present (shows inlining removed wrap/hit?) ########"
for f in erlang elixir gleam beamsharp; do echo "$f: $(grep -o '^{function, *[^,]*, *[0-9]*' $f.S | tr -d '{ ' | tr '\n' ' ')"; done
