#!/usr/bin/env bash
# p9 — BEAM size and compile-time cost of recording provenance.
# Claims:
#   Z1  an application list as a module ATTRIBUTE costs a few bytes per name (measured, N=3 compiles each, deterministic)
#   Z2  the same list as an exported FUNCTION costs more than the attribute (the precedent, `bs@type_atoms/0`, is a function)
#   Z3  a VERSION string per app costs more again -- the number is the price of the version, which the ticket proposes to refuse anyway
#   Z4  per-`using`-block provenance costs the repetition
#   Z5  the attribute is readable without loading the module (beam_lib:chunks)  [control: reading a name that is NOT there gives undefined]
#   Z6  compile time: min and median of N=15 in one VM, stock-rebuilt vs patched; the box was loaded, so only large effects are believable
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
echo "== Z6 compile time, one VM, warm-up 1 + N=15, stock-rebuilt vs patched (both built by patch_compiler.py, same erlc flags)"
python3 "$PROBES/patch_compiler.py" stock "$WORK/bsc-stock" | sed 's/^/   /'
python3 "$PROBES/patch_compiler.py" inline "$WORK/bsc-inline" | sed 's/^/   /'
cat > "$WORK/timeit.erl" <<'EOT'
-module(timeit).
-export([main/1]).
main([Src, Out]) ->
    Run = fun() -> {T, R} = timer:tc(fun() -> bsc:file_to_dir(Src, Out) end), {T, R} end,
    {_, R0} = Run(),
    Ts = [element(1, Run()) || _ <- lists:seq(1, 15)],
    S = lists:sort(Ts),
    io:format("result=~p min=~p us  median=~p us  (N=~p)~n", [element(1, R0), hd(S), lists:nth(8, S), length(S)]), halt().
EOT
erlc -o "$WORK" "$WORK/timeit.erl"
mk_fakelib
mkdir -p "$WORK/t_stock/Req" "$WORK/t_new/Req"; cp $req "$WORK/t_stock/Req/req.bs"
# the same module with one `in :fakelib` added to its first block, so the patched compiler performs ONE lib_dir lookup
sed "s|^using :'Elixir.Req' {|using :'Elixir.Req' in :fakelib {|" $req > "$WORK/t_new/Req/req.bs"
uptime | sed 's/^/   load: /'
a=$(cd /tmp && erl -noshell -pa "$WORK/bsc-stock/ebin" -pa "$WORK" -eval 'timeit:main(init:get_plain_arguments())' -extra "$WORK/t_stock/Req" "$WORK/o_ts" 2>&1 | tail -1); echo "stock   : $a"
b=$(cd /tmp && ERL_LIBS="$WORK/libs" erl -noshell -pa "$WORK/bsc-inline/ebin" -pa "$WORK" -eval 'timeit:main(init:get_plain_arguments())' -extra "$WORK/t_new/Req" "$WORK/o_tn" 2>&1 | tail -1); echo "patched : $b"
expect "Z6 stock timing ran" "min=" "$a"; expect "Z6 patched timing ran" "min=" "$b"
expect "Z6 patched build succeeded (so the lib_dir lookup happened)" "result=ok" "$b"
echo "   (the box is shared and loaded: read min, not median; difference below ~1 ms is noise)"
echo "== Z7 the check itself: code:lib_dir/1, 2000 calls, hit and miss (ERL_LIBS with 1 app)"
EV7='H=fun(A)->{T,_}=timer:tc(fun()->[code:lib_dir(A)||_<-lists:seq(1,2000)] end),T/2000 end, io:format("hit  (fakelib): ~.1f us/call~nmiss (nope)   : ~.1f us/call~n",[H(fakelib),H(nope)]), halt().'
z7=$(ERL_LIBS="$WORK/libs" erl -noshell -eval "$EV7"); echo "$z7"; expect "Z7 measured" "us/call" "$z7"
finish
