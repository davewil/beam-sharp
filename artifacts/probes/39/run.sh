#!/usr/bin/env bash
# Reruns every probe for ticket 39 from a clean scratch dir. Output: output.txt (see header).
# Needs: source /tmp/claude-0/env.sh (erl/erlc/elixirc/gleam on PATH), a built bsc in the repo.
# Takes ~10 min. ROUNDS (default 101) is the number of timed calls per variant per VM; VMS (default 3).
set -u
P="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$P/../../.." && pwd)"
BSC="$REPO/compiler/_build/default/bin/bsc"
ROUNDS="${ROUNDS:-101}"; VMS="${VMS:-3}"
S="$(mktemp -d /tmp/claude-0/work-39/run.XXXXXX)"; INPUT="$REPO/aoc/2025/Day01/input.txt"
export TMPDIR="$S"
hdr() { printf '\n######## %s\n' "$*"; }

hdr "tool versions"
erl -noshell -eval 'io:format("OTP ~s erts ~s ~s~n",[erlang:system_info(otp_release),erlang:system_info(version),erlang:system_info(emu_flavor)]),halt().'
elixir --short-version 2>/dev/null | tail -1; gleam --version; uname -m; grep -m1 'model name' /proc/cpuinfo; nproc
cd "$REPO" && git rev-parse --short HEAD && cd "$S"

hdr "1. build the four implementations (aoc/bench/build.sh, minus its Gleam stdlib dependency, which this machine cannot fetch and the source does not use)"
cp -r "$REPO/aoc/bench" "$S/bench"; E="$S/ebin"; mkdir -p "$E" "$S/dbg"
sed -i '/gleam_stdlib/d' "$S/bench/gleam/gleam.toml"
erlc -o "$E" "$S/bench/bench_erl.erl"
elixirc -o "$E" "$S/bench/bench_ex.ex" >/dev/null 2>&1
(cd "$S/bench/gleam" && gleam build 2>&1 | tail -1); cp "$S"/bench/gleam/build/dev/erlang/bench_gleam/ebin/bench_gleam.beam "$E/"
"$BSC" -o "$E" "$S/bench/Day01" && erlc -o "$E" "$S/bench/bench.erl"
erlc +debug_info -o "$S/dbg" "$S/bench/bench_erl.erl"; cp "$E/Day01.beam" "$E/bench_gleam.beam" "$S/dbg/"

hdr "2. the ticket's own harness (aoc/bench/bench.erl), 3 runs: the four answers must agree before any time means anything"
for i in 1 2 3; do erl -noshell -pa "$E" -s bench main "$INPUT" | sed -n '3,9p'; done

hdr "3. is the instruction sequence identical, and does bsc's loop carry {tr,...}? (Spin/Wrap/Hit vs spin/wrap/hit)"
cp "$P/disasm.escript" "$S/"
for f in spin wrap hit; do
  F=$(echo "$f" | sed 's/./\U&/')
  escript "$S/disasm.escript" "$E/bench_erl.beam" $f | grep -v -e '^{label' -e '^{line' | sed -E 's/bench_erl/M/g;s/\b(spin|wrap|hit)\b/F/g;s/\{f,[0-9]+\}/{f,N}/g' > "$S/e.$f"
  escript "$S/disasm.escript" "$E/Day01.beam" $F | grep -v -e '^{label' -e '^{line' | sed -E "s/'Day01'/M/g;s/'(Spin|Wrap|Hit)'/F/g;s/\{f,[0-9]+\}/{f,N}/g" > "$S/b.$f"
  if diff -q "$S/e.$f" "$S/b.$f" >/dev/null; then r=IDENTICAL; else r=DIFFERENT; fi
  echo "$f: erlang vs bsc disassembly (label/line pseudo-instructions dropped, names and jump targets normalised): $r; instructions=$(grep -vc '^ ' "$S/e.$f"); {tr,..} operands: erlang=$(grep -c '{tr,' "$S/e.$f") bsc=$(grep -c '{tr,' "$S/b.$f")"
done
echo "-- bsc's Spin, in full (note the {tr,..} operands the ticket said were missing):"; escript "$S/disasm.escript" "$E/Day01.beam" Spin
echo "-- whole-module line counts (Sign/Size differ in clause order, they run 4,732 times not 673,364):"
escript "$S/disasm.escript" "$E/bench_erl.beam" all | wc -l; escript "$S/disasm.escript" "$E/Day01.beam" all | wc -l
echo "-- why bsc's Wrap is bigger than Erlang's wrap before optimisation (abstract code, erl_pp):"
for pair in "bench_erl.beam wrap" "Day01.beam Wrap"; do set -- $pair; erl -noshell -eval '{ok,{_,[{abstract_code,{_,AC}}]}}=beam_lib:chunks("'"$S"'/dbg/'$1'",[abstract_code]),[io:format("~s",[erl_pp:form(F)])||F={function,_,N,1,_}<-AC, atom_to_list(N)=:="'$2'"],halt().'; done
echo "-- compile options recorded in each beam (Elixir/Gleam sources are not installed; this probes their binaries):"
erl -noshell -eval '[begin {ok,{_,[{compile_info,CI}]}}=beam_lib:chunks("'"$E"'/"++M++".beam",[compile_info]), io:format("~-16s ~p~n",[M,proplists:get_value(options,CI)]) end || M <- ["bench_erl","Elixir.BenchEx","bench_gleam","Day01"]], halt().'
echo "-- Gleam's emitted source carries:"; erl -noshell -eval '{ok,{_,[{abstract_code,{_,AC}}]}}=beam_lib:chunks("'"$E"'/bench_gleam.beam",[abstract_code]),[io:format("~s",[erl_pp:form(F)])||F={attribute,_,compile,_}<-AC],halt().'

hdr "4. variants (mkvariants.escript) and the timing harness: $VMS fresh VMs x $ROUNDS round-robin rounds"
escript "$P/mkvariants.escript" "$S/dbg" "$S/var" 2>&1 | grep -v -e Warning -e '^%' -e '^$'
erlc -o "$S" "$P/harness.erl"
echo "-- {tr,..} operand lines and instruction counts in spin/4 per variant"
for v in v_erl v_erl_notypeopt v_erl_nossaopt v_erl_notr v_erl_gint v_erl_grange v_bs v_bs_notr v_bs_gint v_bs_grange v_gl; do
  n=spin; case $v in v_bs*) n=Spin;; esac
  printf '%-16s tr-lines=%s instructions=%s\n' $v "$(escript "$S/disasm.escript" "$S/var/$v.beam" $n | grep -c '{tr,')" "$(escript "$S/disasm.escript" "$S/var/$v.beam" $n | grep -vc '^ ')"
done
LABELS="v_erl v_erl_notr v_erl_notypeopt v_erl_nossaopt v_erl_gint v_erl_grange v_bs v_bs_notr v_bs_gint v_bs_grange v_erl_inline v_erl_inline_list v_bs_inline v_bs_inline_size v_bs_inline_list v_erl_bswrap_inline v_bs_erlwrap_inline v_gl v_gl_noinline"
for i in $(seq "$VMS"); do hdr "VM $i of $VMS"; erl -noshell -pa "$S" -run harness main "$S/var" "$INPUT" "$ROUNDS" $LABELS; done

hdr "5. can the Abstract Format carry type facts into beam_ssa_type? (-spec vs guards)"
escript "$P/spec_probe.escript"

hdr "6. prototype: bsc emitting -compile(inline) / -compile({inline,[privates]}) (proto.patch, $(grep -c '^+[^+]' "$P/proto.patch") added lines)"
mkdir -p "$S/proto" && cp -r "$REPO/compiler" "$S/proto/compiler" && rm -rf "$S/proto/compiler/_build"
(cd "$S/proto" && git init -q . 2>/dev/null; patch -p1 < "$P/proto.patch" && cd compiler && rebar3 escriptize 2>&1 | tail -1)
PB="$S/proto/compiler/_build/default/bin/bsc"
mkdir -p "$S/pvar"
for m in none all private; do
  mkdir -p "$S/p_$m"; BSC_INLINE=$m "$PB" -o "$S/p_$m" "$S/bench/Day01"
  sed "s/'Day01'/'p_$m'/g" "$S/p_$m/Day01.abstr" > "$S/pvar/p_$m.abstr"
  erlc +from_abstr +debug_info -o "$S/pvar" "$S/pvar/p_$m.abstr"
  printf 'BSC_INLINE=%-8s .beam bytes=%s  compile attrs: ' $m "$(stat -c %s "$S/pvar/p_$m.beam")"; grep -o "{attribute,0,compile,[^.]*" "$S/p_$m/Day01.abstr" || echo none
done
for m in none inline; do
  sed "s/-module(bench_erl)/-module(pe_$m)/" "$S/bench/bench_erl.erl" > "$S/pe_$m.erl"
  erlc $([ $m = inline ] && echo +inline) +debug_info -o "$S/pvar" "$S/pe_$m.erl"
done
sed "s/-module(bench_erl)./-module(pe_list).\n-compile({inline, [{wrap,1},{hit,1}]})./" "$S/bench/bench_erl.erl" > "$S/pe_list.erl"
erlc +debug_info -o "$S/pvar" "$S/pe_list.erl"
cp "$E/bench_gleam.beam" "$S/pvar/"
for i in $(seq "$VMS"); do hdr "VM $i of $VMS (emission choices, end to end through the prototype bsc)"; erl -noshell -pa "$S" -run harness main "$S/pvar" "$INPUT" "$ROUNDS" p_none p_all p_private pe_none pe_inline pe_list bench_gleam; done

hdr "7. what B# cannot say today (checker output)"
for d in Wrap Arith Neg NegControl; do echo "== refused/$d"; "$BSC" -o "$S/rf" "$P/refused/$d" 2>&1 | head -6; echo "bsc exit status: ${PIPESTATUS[0]}"; done

hdr "8. cost side of inlining: stack frames"
mkdir -p "$S/sp"
for o in "" "+inline"; do erlc $o -o "$S/sp" "$P/stack_probe.erl"; echo "erlc opts=[$o]"; erl -noshell -pa "$S/sp" -eval 'io:format("~p~n",[stack_probe:run()]),halt().'; done

hdr "9. cost side of inlining: compile time and size on large OTP modules (median of 7)"
escript "$P/ctime.escript"
echo; echo "run.sh finished; scratch dir $S"
