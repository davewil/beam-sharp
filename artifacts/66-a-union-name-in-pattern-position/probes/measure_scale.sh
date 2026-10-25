#!/usr/bin/env bash
# For N in 2 5 10 20: generate dup/union/sig modules, compile with the right compiler,
# report abstract-form size of Handle, .beam bytes, export-table size and in-VM compile time (15 runs).
S=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad
export PATH=$S/beam/bin:$PATH LANG=C.UTF-8
HERE="$(cd "$(dirname "$0")" && pwd)"
W=$S/66/scale; rm -rf $W; mkdir -p $W
for N in 2 5 10 20; do "$HERE/gen_union_n.sh" $N $W; done
cat > $W/m.escript <<'E'
#!/usr/bin/env escript
main([Ebin, Root, Dir, Out]) ->
    code:add_patha(Ebin),
    Args = ["--src-root", Root, "-o", Out, Dir],
    ok = filelib:ensure_dir(Out ++ "/x"),
    Times = [element(1, timer:tc(fun() -> bsc:status(Args, batch) end)) || _ <- lists:seq(1, 15)],
    S = lists:sort(Times),
    Mod = list_to_atom(filename:basename(Dir)),
    Abstr = filename:join(Out, atom_to_list(Mod) ++ ".abstr"),
    {ok, Forms} = file:consult(Abstr),
    [H] = [F || F = {function, _, 'Handle', _, _} <- Forms],
    Beam = filename:join(Out, atom_to_list(Mod) ++ ".beam"),
    {ok, Bin} = file:read_file(Beam),
    io:format("~-10s clauses=~2w handle_flat_words=~6w all_forms_flat_words=~6w beam_bytes=~6w  compile_us min/med/max=~w/~w/~w~n",
      [filename:basename(Dir), length(element(5, H)), erts_debug:flat_size(H),
       erts_debug:flat_size(Forms), byte_size(Bin),
       hd(S), lists:nth(8, S), lists:last(S)]).
E
for N in 2 5 10 20; do
  for v in dup union sig; do
    c=$S/bsc; [ $v = union ] && c=$S/66/bsc_proto
    ebin=$S/bsc-build/ebin; [ $v = union ] && ebin=$S/66/proto/ebin
    escript $W/m.escript $ebin $W $W/N$N$v $W/out/N$N$v 2>&1 | tail -1
  done
done
