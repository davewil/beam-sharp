#!/usr/bin/env bash
# One command: ./06_runtime_hop.sh -> probes/06_runtime_hop.out
# (a) is the snake_case alias a real extra hop?  (b) does the BEAM inline the forwarder?  (c) what does the hop cost?
HERE="$(cd "$(dirname "$0")" && pwd)"; source "$HERE/lib.sh"
"$HERE/patch_emit.sh" >/dev/null || exit 1
D=$WORK; rm -rf $D/*; mkdir -p $D/fwd $D/dup $D/inl
for m in forward dup; do d=$D/${m/forward/fwd}; BS_ALIAS_MODE=$m BSC_EBIN=$S/62/csrc-ebin bsc --src-root $HERE/bs -o $d $HERE/bs/Abi >/dev/null; done
erlc -o $D $HERE/bench_hop.erl
cd $D   # compile:file with option S drops Abi.S in the cwd; keep it out of the repo
echo "=== (a) BEAM assembly (compile:file option S) of the alias; Abi.abstr is the .abstr bsc wrote"
cat > $D/asm.escript <<'EOS'
#!/usr/bin/env escript
%% usage: asm.escript ABSTR FUN [compile options as erlang term]  -> prints the {function,FUN,...} entries of the BEAM assembly
main([Abstr, Fun, Opts]) ->
    {ok, Toks, _} = erl_scan:string(Opts ++ "."), {ok, Opts1} = erl_parse:parse_term(Toks),
    {ok, _, {_, _, _, _, Fs, _}} = compile:file(Abstr, [from_abstr, debug_info, 'S', binary | Opts1]),
    [io:format("~p~n", [F]) || {function, N, _, _, _} = F <- Fs, N =:= list_to_atom(Fun)].
EOS
chmod +x $D/asm.escript
echo "--- forward, default options: alias = ?"
escript $D/asm.escript $D/fwd/Abi.abstr new_http '[]' 2>&1 
echo
echo "--- forward, with {inline,[{'NewHTTP',1}]} : is the body pulled into the alias?"
escript $D/asm.escript $D/fwd/Abi.abstr new_http "[{inline,[{'NewHTTP',1}]}]" 2>&1 
echo
echo "--- forward, with plain 'inline' (compile option: inline everything small) :"
escript $D/asm.escript $D/fwd/Abi.abstr new_http "[inline]" 2>&1 
echo
echo "--- dup mode, default options: alias holds its own copy of the body:"
escript $D/asm.escript $D/dup/Abi.abstr new_http '[]' 2>&1 
echo
echo "=== (c) timing. 1e7 and 5e7 calls, 15 interleaved reps each, microseconds, timer:tc resolution = 1 us (monotonic clock)"
erl -noshell -pa $D -pa $D/fwd -eval '
io:format("emu_flavor=~s  arch=~s~n", [erlang:system_info(emu_flavor), erlang:system_info(system_architecture)]),
Reps = 15,
Med = fun(L) -> S = lists:sort(L), lists:nth((length(L)+1) div 2, S) end,
lists:foreach(fun(N) ->
  Res = [ [ {W, element(1, bench_hop:run(W, N))} || W <- [empty, pascal, alias, via_apply] ] || _ <- lists:seq(1, Reps) ],
  Get = fun(W) -> [T || R <- Res, {W2, T} <- R, W2 =:= W] end,
  [E, P, A, X] = [Get(W) || W <- [empty, pascal, alias, via_apply]],
  io:format("N=~w calls  empty-loop median ~w us | PascalCase export median ~w us (min ~w max ~w) | alias export median ~w us (min ~w max ~w)~n",
     [N, Med(E), Med(P), lists:min(P), lists:max(P), Med(A), lists:min(A), lists:max(A)]),
  io:format("        per call above loop: Pascal ~.2f ns, alias ~.2f ns, alias-minus-Pascal ~.2f ns~n",
     [(Med(P)-Med(E))*1000/N, (Med(A)-Med(E))*1000/N, (Med(A)-Med(P))*1000/N]),
  io:format("        NEGATIVE CONTROL (the probe must see a real extra cost): the same call plus one erlang:phash2/1 BIF per iteration, median ~w us = ~.2f ns/call above loop~n", [Med(X), (Med(X)-Med(E))*1000/N])
end, [10000000, 50000000]),
halt(0).' 2>&1
