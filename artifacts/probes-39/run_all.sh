#!/usr/bin/env bash
# Re-runs every probe from the probe root. ~15 min total. Requires erl/erlc/escript, elixir, and (optional) the gleam binary at $GLEAM.
set -e
R="$(cd "$(dirname "$0")" && pwd)"
GLEAM="${GLEAM:-/tmp/claude-0/-home-user-beam-sharp/e462f18b-47b0-5059-896d-359d243949c1/scratchpad/gleam-bin/gleam}"
T() { erl -noshell -pa "$@" ; }
# --- a: strip experiment
cd $R/a; escript gen_input.escript input.txt; mkdir -p ebin
for m in erl_a erl_b; do sed "s/^-module(bench_erl)/-module($m)/" bench_erl.erl > $m.erl; erlc -o ebin $m.erl; erlc -S -o . $m.erl; done
for m in strip_a strip_b; do escript strip_types.escript erl_a.S $m.S $m; erlc -o ebin $m.S; done
escript strip_part.escript erl_a.S strip_tr.S strip_tr tr; escript strip_part.escript erl_a.S strip_vi.S strip_vi vi; erlc -o ebin strip_tr.S strip_vi.S
erlc -o ebin timeit.erl
{ for pair in "erl_a erl_b:copy control" "erl_a strip_a:strip" "strip_a strip_b:copy control" "erl_a strip_tr:only tr" "erl_a strip_vi:only var_info"; do set -- ${pair%%:*}; echo "== $1 vs $2 (${pair##*:})"; escript cmp.escript ebin/$1.beam ebin/$2.beam; done; } > cmp.out 2>&1
erl -noshell -pa ebin -eval 'timeit:main(["input.txt","301","erl_a","strip_a","erl_b","strip_b"])' > run1.out
erl -noshell -pa ebin -eval 'timeit:main(["input.txt","401","strip_a","erl_a","strip_b","erl_b"])' > run2.out
# --- a2: emitter-shape stand-ins
cd $R/a2; escript mk_shapes.escript .
for m in sh_op sh_remote sh_spec sh_guard; do echo "== erl_a vs $m"; escript cmp_fn.escript ../a/ebin/erl_a.beam $m.beam wrap hit spin clicks part_two; done > cmp_fn.out
for m in sh_remote sh_spec sh_guard; do echo "== sh_op vs $m (whole module)"; escript cmp.escript sh_op.beam $m.beam | sed -n 2,4p; done >> cmp_fn.out
erl -noshell -pa ../a/ebin -pa . -eval 'timeit:main(["../a/input.txt","301","erl_a","sh_op","sh_remote","sh_spec","sh_guard","strip_a","erl_b","strip_b"])' > time_shapes.out
# --- a3
cd $R/a3; escript via_abstr.escript
# --- b, b2
cd $R/b2; erlc -S ranges.erl; escript ann.escript ranges.S > ranges_ann.out
cd $R/b; rm -f *.S *.beam; bash mk.sh; cp ../a/ebin/timeit.beam .
for m in b_const b_unk_a b_kind_a b_guard_a b_band_a; do printf "%-10s " $m; escript ann.escript $m.S | grep "^spin"; done > ann_spin.out
erl -noshell -pa . -eval 'timeit:main(["../a/input.txt","301","b_const","b_unk_a","b_unk_b","b_kind_a","b_guard_a","b_guard_b","b_band_a","b_band_b"])' > time1.out
# --- c
cd $R/c/gl && $GLEAM build && cp build/dev/erlang/bench_gleam/ebin/bench_gleam.beam ../../d/
cd $R/c/ex && elixirc -o . bench_ex.ex && elixir ex_probe.exs > out.txt 2>&1   # must run in this dir: it opens Elixir.BenchEx.beam by relative path
cd $R/c/gl && escript tr_count.escript build/dev/erlang/bench_gleam/ebin/bench_gleam.beam > out_tr.txt
cd $R/c/gl3 && { $GLEAM build >/dev/null; erlc -S -o . build/dev/erlang/g3/_gleam_artefacts/g3.erl; { sed -n "/^-spec lit/,\$p" build/dev/erlang/g3/_gleam_artefacts/g3.erl; escript ../../b2/ann.escript g3.S; } > out.txt; }
# --- d
cd $R/d; cp ../a/ebin/timeit.beam .; cp ../a/ebin/erl_a.beam .; cp ../c/ex/Elixir.BenchEx.beam .; cp ../a2/sh_remote.beam .; erlc +inline erl_inl.erl; escript mk_inl.escript
for m in inl_a inl_b; do sed "s/-module(bench_erl)/-module($m)/" ../a/bench_erl.erl > $m.erl; erlc +inline $m.erl; erlc +inline -S $m.erl; done
for m in inls_a inls_b; do escript ../a/strip_types.escript inl_a.S $m.S $m; erlc $m.S; done
erl -noshell -pa . -eval 'timeit:main(["input.txt","201","erl_a","erl_inl","bench_gleam","Elixir.BenchEx","sh_remote","sh_remote_inl"])' > time_langs.out
erl -noshell -pa . -eval 'timeit:main(["input.txt","301","inl_a","inls_a","inl_b","inls_b","erl_a"])' > time_inline_strip.out
# --- b second ordering, a partial-strip timing
cd $R/b; erl -noshell -pa . -eval 'timeit:main(["../a/input.txt","401","b_unk_a","b_unk_b","b_const","b_band_a","b_band_b","b_kind_a","b_guard_a","b_guard_b"])' > time2.out
cd $R/a; erl -noshell -pa ebin -eval 'timeit:main(["input.txt","301","erl_a","strip_a","strip_tr","strip_vi","erl_b"])' > run_partial.out
# --- e, f
cd $R/e; bash mk.sh; erl -noshell -pa . -eval 'timeit:main(["input.txt","301","e_base_a","e_guard_a","e_base_b","e_guard_b"])' > time_guard_private.out; erl -noshell -pa . -eval 'timeit:main(["input.txt","301","e_base_a","e_left_a","e_base_b","e_left_b","e_guard_a"])' > time_guard_left.out
cd $R/f; bash run.sh > out.txt 2>&1
