#!/usr/bin/env bash
# Ticket 39 probe: why is instruction-identical code ~20% slower, and what is the ceiling?
# Reruns everything from scratch: builds every variant, compares the hot-loop disassembly,
# times them round-robin, and exits non-zero if an expected observation does not hold.
#   RUNS=40 bash artifacts/probes/39/run.sh        (default 40 rounds)
# Toolchain: OTP 25 erlc/erl, Elixir 1.14 (elixirc), Gleam (GLEAM=path, else PATH; if absent the
# Gleam rows are skipped with a warning).  NOT OTP 28, and `bsc` cannot run here: the `*_bsc`
# variants replay bsc's BUILD PATH (bsc.erl:833-846) on hand-written forms, not bsc's output.
set -u
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W="${TMPDIR:-/tmp}/probe39"; rm -rf "$W"; mkdir -p "$W/asm"
RUNS="${RUNS:-40}"
GLEAM="${GLEAM:-$(command -v gleam || echo /tmp/claude-0/-home-user-beam-sharp/a3310f8a-c503-5acc-8cf0-37e76fb5554b/scratchpad/tc/gleam)}"
fail=0; ok(){ echo "PASS  $*"; }; bad(){ echo "FAIL  $*"; fail=1; }
cd "$D"
echo "== toolchain"; erl -noshell -eval 'io:format("OTP ~s erts-~s flavor=~p arch=~s~n",[erlang:system_info(otp_release),erlang:system_info(version),erlang:system_info(emu_flavor),erlang:system_info(system_architecture)]),halt().'
elixirc --version | tail -1
erlc -o "$W" bench.erl || exit 2
# hand-written Erlang variants: erlc path (+ asm) ...
VARS="v_erl v_remote v_retguard v_spec v_narrowspec v_inline v_rginline v_guard v_noanno v_noanno_inline"
for v in $VARS; do erlc -o "$W" $v.erl || exit 2; erlc +to_asm -o "$W/asm" $v.erl || exit 2; done
# ... and bsc's build path (forms with every annotation 0, ~p-printed .abstr, compile:file from_abstr+debug_info)
for v in v_erl v_retguard v_spec v_inline v_rginline v_rgexplicit; do escript pipe.escript $v.erl "$W" >/dev/null 2>&1 || { echo "pipe failed $v"; exit 2; }; mv "$W/${v}_bsc.S" "$W/asm/${v}_bsc.S"; done
elixirc -o "$W" bench_ex.ex >/dev/null 2>&1 || exit 2
HAVE_GLEAM=0
if [ -x "$GLEAM" ] && (cd gleam && "$GLEAM" build >/dev/null 2>&1); then
  cp gleam/build/dev/erlang/bench_gleam/ebin/bench_gleam.beam "$W/"; HAVE_GLEAM=1
else echo "WARN  gleam not available: Gleam rows skipped"; fi

# extract one function's asm, module name and {line,..} stripped
fn(){ sed "s/v_[a-z_]*/M/g" "$W/asm/$1.S" | awk -v f="$2" '$0 ~ "^\\{function, "f", "{p=1} /^\{function, /&&$0 !~ "^\\{function, "f", "{p=0} p' | grep -v '{line\|^ *\.$'; }
echo; echo "== 1. disassembly of the hot loop"
for f in wrap hit spin; do [ -n "$(fn v_erl $f)" ] || bad "empty extraction for $f"
  for v in v_remote v_retguard v_spec v_narrowspec v_erl_bsc v_retguard_bsc v_spec_bsc; do
    [ "$v" = v_erl_bsc ] || [ "$v" = v_retguard_bsc ] || [ "$v" = v_spec_bsc ] || [ "$v" = v_remote ] || true
    if [ "$(fn v_erl $f | md5sum)" = "$(fn $v $f | md5sum)" ]; then :; else bad "$f/$(echo $v) differs from plain Erlang"; fi
  done
done
[ $fail = 0 ] && ok "wrap/hit/spin asm (incl. {tr,..} annotations) IDENTICAL for: remote rem, bs_emit return-guard, widened spec, narrowed spec, bsc build path (OTP 25)"
fn v_erl spin | grep -q "{tr,{x,0},{t_integer,{-99,99}}}" && ok "plain Erlang spin carries {tr,{x,0},{t_integer,{-99,99}}} on OTP 25 (OTP 28 prints {0,99}; cited)" || bad "no tr on plain spin"
fn v_noanno spin | grep -q "gc_bif,'+',{f,0},4,\[{x,0},{x,1}\],{x,0}" && ok "v_noanno (spin exported): bare {x,0},{x,1} operands, as in beam-sharp's reported disassembly" || bad "v_noanno did not strip tr"
fn v_guard spin | grep -q "{tr,{y,2},{t_integer,any}}" && ok "range guards on Left/Zeros did NOT narrow the type (still any) on OTP 25" || bad "guards narrowed (claim falsified)"
[ "$(fn v_guard spin | grep -c is_ge)" -ge 6 ] && ok "range guards cost >=6 runtime is_ge tests per iteration" || bad "guard tests missing"
grep -q "^-compile(\[.*inline" gleam/build/dev/erlang/bench_gleam/_gleam_artefacts/bench_gleam.erl 2>/dev/null && ok "Gleam emits -compile([..., inline])  (generated bench_gleam.erl line 2)" || echo "WARN  Gleam inline attribute not found"
fn v_rginline_bsc spin | grep -q "% wrap/1" && ok "bs_emit return guard + default -compile(inline): wrap/1 is NOT inlined (guard grows it past inline_size)" || bad "wrap was inlined despite return guard"
fn v_inline_bsc spin | grep -q "% wrap/1" && bad "plain inline did not inline wrap" || ok "plain -compile(inline): wrap/1 and hit/1 inlined into spin"
fn v_rgexplicit_bsc spin | grep -q "% wrap/1" && bad "explicit {inline,[{wrap,1}]} did not inline guarded wrap" || ok "explicit -compile({inline,[{wrap,1},{hit,1}]}) inlines the guarded wrap"
echo; echo "== 2. compile options recorded in each beam"
erl -noshell -pa "$W" -eval '[io:format("~-18s ~p~n",[M,proplists:get_value(options,M:module_info(compile))]) || M <- [v_erl,v_erl_bsc,v_inline_bsc,bench_gleam,'"'"'Elixir.BenchEx'"'"'], code:ensure_loaded(M)=={module,M}], halt().'
echo; echo "== 3. timing ($RUNS rounds, round-robin, rotated order)"
MODS="v_erl,v_erl_bsc,v_retguard_bsc,v_spec_bsc,v_narrowspec,v_guard,v_noanno,v_inline,v_inline_bsc,v_rginline_bsc,v_rgexplicit_bsc,v_noanno_inline,'Elixir.BenchEx'"
[ $HAVE_GLEAM = 1 ] && MODS="$MODS,bench_gleam"
erl -noshell -pa "$W" -eval "bench:main(\"$D/input.txt\", $RUNS, [$MODS]), halt()." | tee "$W/timing.txt"
# min-over-rounds, full-run column 2, relative cols printed at the end of each row
rel(){ awk -v v="$1" '$1==v{print $2}' "$W/timing.txt"; }
cmp(){ awk -v a="$(rel $1)" -v b="$(rel $2)" 'BEGIN{printf "%.3f", a/b}'; }
echo
r=$(cmp v_erl v_inline);        awk -v r=$r 'BEGIN{exit !(r>1.05)}' && ok "plain Erlang / -compile(inline) Erlang = $r (>1.05: a real gap)"   || bad "no >5% gap between plain and inlined Erlang ($r)"
r=$(cmp v_rgexplicit_bsc v_inline_bsc); awk -v r=$r 'BEGIN{exit !(r<1.03 && r>0.97)}' && ok "guarded wrap + explicit inline list vs plain inline: $r" || bad "explicit inline list not at parity ($r)"
echo "INFO  guarded wrap + default inline vs plain inline: $(cmp v_rginline_bsc v_inline_bsc)  (borderline: see README of brief; not asserted)"
r=$(cmp v_noanno v_erl);        awk -v r=$r 'BEGIN{exit !(r<1.03 && r>0.97)}' && ok "stripping {tr,..} from spin: $r (within 3% noise => annotations do not cause the gap on OTP 25)" || bad "stripping annotations moved time by $r (claim falsified)"
r=$(cmp v_noanno_inline v_inline); awk -v r=$r 'BEGIN{exit !(r<1.03 && r>0.97)}' && ok "stripping {tr,..} with inlining: $r" || bad "noanno_inline moved ($r)"
r=$(cmp v_retguard_bsc v_erl);  awk -v r=$r 'BEGIN{exit !(r<1.03 && r>0.97)}' && ok "bs_emit return guard on rem (no inline): $r" || bad "return guard moved time ($r)"
r=$(cmp v_narrowspec v_erl);    awk -v r=$r 'BEGIN{exit !(r<1.03 && r>0.97)}' && ok "narrow vs no spec: $r" || bad "spec moved time ($r)"
r=$(cmp v_guard v_erl);         awk -v r=$r 'BEGIN{exit !(r>=0.99)}' && ok "range guards are not faster than plain: $r" || bad "range guards faster ($r)"
r=$(cmp 'Elixir.BenchEx' v_erl); awk -v r=$r 'BEGIN{exit !(r<1.03 && r>0.97)}' && ok "Elixir/Erlang: $r" || bad "Elixir differs from Erlang ($r)"
[ $HAVE_GLEAM = 1 ] && { r=$(cmp bench_gleam v_inline); awk -v r=$r 'BEGIN{exit !(r<1.03 && r>0.97)}' && ok "Gleam/Erlang+inline: $r" || bad "Gleam differs from Erlang+inline ($r)"; }
echo; echo "== 4. what inlining costs the author: stack frames"
erlc -o "$W" st_plain.erl st_inline.erl || exit 2
for m in st_plain st_inline; do erl -noshell -pa "$W" -eval "try $m:f(a) catch _:_:S -> io:format(\"~-10s frames: ~w~n\",[$m,[F||{_,F,_,_}<-lists:sublist(S,3)]]) end, halt()." ; done | tee "$W/st.txt"
grep -q "st_plain.*h" "$W/st.txt" && ! grep -q "st_inline.*\bh\b" "$W/st.txt" && ok "inlined helper h/1 and g/1 vanish from the stack trace" || bad "stack trace claim failed"
timeout 60 erlc -o "$W" rec_inline.erl && ok "explicit inline list naming a self-recursive function still compiles and terminates" || bad "recursive inline hung/failed"
echo; [ $fail = 0 ] && echo "ALL OBSERVATIONS HOLD" || echo "SOME OBSERVATION FAILED"; exit $fail
