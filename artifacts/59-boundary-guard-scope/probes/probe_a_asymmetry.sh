#!/usr/bin/env bash
# Probe (a): reproduce the asymmetry. Compiles src/Scope with the unmodified compiler and
# prints, for each function in the emitted .abstr, which guard calls its clause carries.
# Negative control: PrivInt (private, plain int) must show NO guard; the detector must also
# report a guard when one exists (PubInt -> is_integer, PubRec -> tag map_get).
cd "$(dirname "$0")"
source /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh
cat > /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/59/guards.escript <<'ES'
#!/usr/bin/env escript
main([F]) ->
    {ok, Forms} = file:consult(F),
    Exp = lists:append([L || {attribute,_,export,L} <- Forms]),
    [begin
         G = [Gs || {clause,_,_,Gs,_} <- Cs],
         Calls = lists:usort(find(G)),
         io:format("~-8s ~-8s guard=~p~n", [Name, case lists:member({Name,A},Exp) of true->exported; false->private end, Calls])
     end || {function,_,Name,A,Cs} <- Forms, Name =/= bs@type_atoms],
    ok.
find({call,_,{remote,_,{atom,_,erlang},{atom,_,N}},_}) -> [N];
find(T) when is_tuple(T) -> find(tuple_to_list(T));
find(L) when is_list(L) -> lists:append([find(X) || X <- L]);
find(_) -> [].
ES
mkdir -p /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/59
W=${W:-/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/59/variants}
for v in base notag widen; do
  echo "=== compiler variant: $v   (base = today; notag/widen = the two scratch patches, so the detector is shown able to go red/green)"
  BSC_EBIN=$W/$v/ebin ./bsc.sh --src-root src -o out_$v src/Scope || exit 1
  escript /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/59/guards.escript out_$v/Scope.abstr
  echo "   .beam bytes: $(stat -c %s out_$v/Scope.beam)"
done
