#!/usr/bin/env bash
# Ticket 39 (cost of -compile(inline)): does a failing private-function guard still name the private function?
# Uses the 59w build (kind test on private functions) with and without the inline option.
. "$(cd "$(dirname "$0")" && pwd)/env.sh"
cat > $PROBE_HOME/st.escript <<'X'
#!/usr/bin/env escript
main([Ebin, Src]) ->
    true = code:add_patha(Ebin),
    Tmp = os:cmd("mktemp -d") -- "\n", ok = filelib:ensure_dir(Tmp ++ "/Bn/x"),
    {ok,_} = file:copy(Src, Tmp ++ "/Bn/a.bs"),
    {ok,_} = bsc:file_to_dir(Tmp ++ "/Bn/a.bs", Tmp), true = code:add_patha(Tmp),
    {module,'Bn'} = code:load_abs(Tmp ++ "/Bn"),
    try 'Bn':'Run'([1, 100.5]) catch C:E:St -> io:format("~p:~p~n  ~p~n", [C, E, [{M,F,A} || {M,F,A,_} <- lists:sublist(St, 3)]]) end.
X
for v in v59w v39w; do echo "== $v"; escript $PROBE_HOME/st.escript $PROBE_HOME/variants/$v/ebin $root/artifacts/probes/src59/bench.bs; done
