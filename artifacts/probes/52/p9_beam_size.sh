#!/usr/bin/env bash
# p9 — BEAM size and compile-time cost of recording provenance.
# Claims:
#   Z1  an application list as a module ATTRIBUTE costs a few bytes per name (measured, N=3 compiles each, deterministic)
#   Z2  the same list as an exported FUNCTION costs more than the attribute (the precedent, `bs@type_atoms/0`, is a function)
#   Z3  a VERSION string per app costs more again -- the number is the price of the version, which the ticket proposes to refuse anyway
#   Z4  per-`using`-block provenance costs the repetition
#   Z5  the attribute is readable without loading the module (beam_lib:chunks)  [control: reading a name that is NOT there gives undefined]
#   Z6  compile time: the code:lib_dir check adds no measurable time (min and median of N=15, stock vs patched, same VM boot excluded)
source "$(dirname "$0")/common.sh"
req=wayfinder/prototypes/51a-code-path/Req/req.bs
mkdir -p "$WORK/src/Req"; cp $req "$WORK/src/Req/req.bs"
$BSC --src-root "$WORK/src" -o "$WORK/out" "$WORK/src/Req" >/dev/null 2>&1; ls -la "$WORK/out"
echo "stock .beam: $(stat -c %s "$WORK/out/Req.beam") bytes (as bsc writes it)"
z=$(escript "$PROBES/p9_beam_size.escript" "$WORK/out/Req.abstr"); echo "$z"
expect "Z1 baseline measured" "baseline" "$z"; expect "Z5 attribute readable" "bs_needs = [req,jason]" "$z"; expect "Z1 stable" "stable" "$z"
echo "-- Z5 control: an attribute that is not there"
EVC='{ok,{_,[{attributes,A}]}}=beam_lib:chunks("'$WORK'/out/Req.beam",[attributes]), io:format("bs_needs in stock beam: ~p~n",[proplists:get_value(bs_needs,A)]),halt().'
c=$(erl -noshell -eval "$EVC"); echo "$c"; expect "Z5 control: stock beam has no bs_needs" "undefined" "$c"
echo "== Z6 compile time, in one VM, N=15 per compiler"
for v in attr; do :; done
if [ -x "$PROBES/.built-attr" ]; then :; fi
python3 "$PROBES/patch_compiler.py" attr "$WORK/bsc-attr" | sed 's/^/   /'
cat > "$WORK/timeit.erl" <<'EOT'
-module(timeit).
-export([main/1]).
main([Src, Out]) ->
    Run = fun() -> {T, R} = timer:tc(fun() -> bsc:file(Src, Out) end), {T, R} end,
    _ = Run(),
    Ts = [element(1, Run()) || _ <- lists:seq(1, 15)],
    S = lists:sort(Ts),
    io:format("min=~p us  median=~p us  (N=~p)~n", [hd(S), lists:nth(8, S), length(S)]), halt().
EOT
erlc -o "$WORK" "$WORK/timeit.erl"
echo "stock  : $(erl -noshell -pa /tmp/claude-0/-home-user-beam-sharp/5c54aeca-205c-5959-b98d-85886863a86f/scratchpad/bsc/ebin -pa "$WORK" -eval 'timeit:main(init:get_plain_arguments())' -extra "$WORK/src/Req" "$WORK/t1" 2>&1 | tail -1)"
mkdir -p "$WORK/srcn/Req"; sed "s|^using :'Elixir.Req' {|[app: req]\nusing :'Elixir.Req' {|" $req > "$WORK/srcn/Req/req.bs"
echo "patched (module declares [app: req] on one block; ERL_LIBS has no req, so we point at fakelib instead):"
mk_fakelib; sed -i "s|\[app: req\]|[app: fakelib]|" "$WORK/srcn/Req/req.bs"
echo "patched: $(ERL_LIBS="$WORK/libs" erl -noshell -pa "$WORK/bsc-attr/ebin" -pa "$WORK" -eval 'timeit:main(init:get_plain_arguments())' -extra "$WORK/srcn/Req" "$WORK/t2" 2>&1 | tail -1)"
finish
