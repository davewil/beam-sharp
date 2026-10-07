#!/usr/bin/env bash
# Re-runs every probe for ticket 59. One command: artifacts/probes/59/run.sh
# Needs: PATH with erl/elixir/gleam/dialyzer (export PATH=$HOME/.nix-profile/bin:$PATH),
#        compiler/_build/default/bin/bsc prebuilt. Writes <probe>.out next to each probe.
set -u
export PATH=$HOME/.nix-profile/bin:$PATH ELIXIR_ERL_OPTIONS="+fnu" LC_ALL=C.UTF-8
HERE=$(cd "$(dirname "$0")" && pwd); cd "$HERE"
ROOT=$(cd "$HERE/../../.." && pwd)
BSC=$ROOT/compiler/_build/default/bin/bsc; EX=$ROOT/compiler/examples
# 1. compile the probe module with the real bsc; print what it emits (the asymmetry)
$BSC --src-root src src/Guard > bsc-compile.out 2>&1
./pp.escript Guard.abstr > emitted-erlang.out
# 2. end-to-end through the CLI: forged nested record
{ $BSC --src-root src src/Guard Nested "{ Kind = :'Guard.Cart', Primary = { Kind = :'Guard.Invoice', Id = 1, Total = 99 }, Count = 1 }"
  $BSC --src-root src src/Guard Outer "{ Kind = :'Guard.Invoice', Id = 1, Total = 99 }"; } > bsc-forged.out 2>&1
# 3. forged values: emitted vs private-tag-stripped vs private-int-widened
for m in emitted stripped widened; do ./forge.escript Guard.abstr $m > forge-$m.out 2>&1; done
# 4. bytes and disassembly
./disasm.escript Guard.abstr Inner > disasm.out 2>&1
./sizes.escript  Guard.abstr > sizes.out 2>&1
./disasm.escript Guard.abstr InnerPub > disasm-exported.out 2>&1
# 5. corpus: private functions carrying a tag test, over every compilable example module
rm -rf corpus; mkdir corpus
for d in "$EX"/*/ "$EX"/Shop/Billing "$EX"/Shop/Rows; do n=$(basename "$d"); [ "$n" = exemplars ] && continue
  mkdir -p "corpus/$n"; (cd "corpus/$n" && $BSC --src-root "$EX" "$d" >/dev/null 2>&1); done
./measure.escript $(find corpus -name '*.abstr' | sort) > corpus.out 2>&1
# 6. call time (noise-limited; see brief)
./bench.escript Guard.abstr > bench.out 2>&1
# 7. neighbours
( cd gleam && gleam build >/dev/null 2>&1; erl -noshell -pa build/dev/erlang/probe/ebin -eval '
  R = fun(L,F) -> io:format("~s -> ~0p~n",[L,(catch F())]) end,
  R("float_through_public", fun() -> probe:float_through_public() end),
  R("forged_order_through_public", fun() -> probe:forged_order_through_public() end), halt().' ) > gleam/probe.out 2>&1
( cd gleam && erl -noshell -eval '{ok,{_,[{abstract_code,{_,AC}}]}}=beam_lib:chunks("build/dev/erlang/probe/ebin/probe.beam",[abstract_code]),[io:format("~s~n",[erl_pp:form(F)])||F<-AC,element(1,F)==function,lists:member(element(3,F),[private_inc,outer,private_total,outer_order])],halt().' ) > gleam/emitted.out 2>&1
( cd elixir && elixir probe.exs > probe.out 2>&1 )
( cd elixir && D=$(mktemp -d) && elixirc -o "$D" warn.exs > warn.out 2>&1; echo "elixirc exit $?" >> warn.out )
( cd erlang && erlc +debug_info dprobe.erl && dialyzer --build_plt --output_plt erts.plt --apps erts >/dev/null 2>&1; dialyzer --plt erts.plt dprobe.beam > dialyzer.out 2>&1 )
echo done; ls *.out
