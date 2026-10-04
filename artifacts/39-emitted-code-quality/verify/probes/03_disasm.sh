#!/usr/bin/env bash
# Claims (§1): Wrap/1 and Spin/4 disassemble to identical instruction lists (26 each); Erlang carries {tr,{x,0},{t_integer,{0,99}}} where bsc has bare {x,0}.
. "$(dirname "$0")/env.sh"
cat > $W/dis.erl <<'EOS'
-module(dis).
-export([main/1]).
main([F]) ->
    {beam_file, M, _Ex, _Attr, _CI, Fs} = beam_disasm:file(F),
    io:format("MODULE ~p~n", [M]),
    [begin io:format("~n--- ~p/~p (~p instrs)~n", [N, A, length(Is)]), [io:format("  ~p~n",[I]) || I <- Is] end
     || {function, N, A, _, Is} <- Fs],
    halt().
EOS
erlc -o $W $W/dis.erl
for m in bench_erl bench_gleam Day01 Elixir.BenchEx; do erl -noshell -pa $W -eval 'dis:main(["'$W'/ebin/'$m'.beam"])' > $W/$m.dis; echo "$m: $(grep -c . $W/$m.dis) lines"; done
echo; echo "=== bench_erl spin/4 ==="; sed -n '/--- spin\/4/,/^--- [a-z_]*\/[0-9]* /p' $W/bench_erl.dis | head -60
echo; echo "=== Day01 Spin/4 ==="; sed -n "/--- 'Spin'\/4/,/^--- /p" $W/Day01.dis | head -60
echo; echo "=== tr annotations count per module ==="
for m in bench_erl bench_gleam Day01 Elixir.BenchEx; do echo "$m tr=$(grep -c '{tr,' $W/$m.dis)"; done
echo; echo "=== Wrap vs wrap ==="
sed -n '/--- wrap\/1/,/^--- /p' $W/bench_erl.dis | head -40; sed -n "/--- 'Wrap'\/1/,/^--- /p" $W/Day01.dis | head -40
