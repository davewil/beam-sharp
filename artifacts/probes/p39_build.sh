#!/usr/bin/env bash
# Ticket 39: rebuild aoc/bench's four implementations on THIS machine's toolchain into $PROBE_HOME/b39/ebin.
# (bench/build.sh needs rebar3's escript; this uses the variant compiler the other probes use.)
. "$(cd "$(dirname "$0")" && pwd)/env.sh"
B=$root/aoc/bench; O=$PROBE_HOME/b39; rm -rf $O; mkdir -p $O/ebin $O/g/src
erlc -o $O/ebin $B/bench_erl.erl
elixirc -o $O/ebin $B/bench_ex.ex >/dev/null 2>&1
cp $B/gleam/src/*.gleam $O/g/src/ && printf 'name = "bench_gleam"\nversion = "1.0.0"\ntarget = "erlang"\n' > $O/g/gleam.toml
( cd $O/g && gleam build >/dev/null 2>&1 ) && cp $O/g/build/dev/erlang/bench_gleam/ebin/bench_gleam.beam $O/ebin/
mkdir -p $O/Day01 && cp $B/Day01/bench_bs.bs $O/Day01/
cat > $O/b.escript <<X
#!/usr/bin/env escript
main(_) ->
    true = code:add_patha("${BSC_EBIN:-$PROBE_HOME/variants/base/ebin}"),
    {ok,_} = bsc:file_to_dir("$O/Day01", "$O/ebin"), ok.
X
escript $O/b.escript
sed 's/A =\/= 6770/A =\/= 6770/' $B/bench.erl > $O/bench.erl && erlc -o $O/ebin $O/bench.erl
ls $O/ebin
