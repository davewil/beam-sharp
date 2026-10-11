#!/usr/bin/env bash
# corpus.sh SCRATCH -- compile every module under compiler/examples with each prototype compiler
# and count the boundary tests in the emitted .abstr: tag tests (map_get('Kind', V) =:= Tag),
# is_integer/is_float tests, and how many of each sit on PRIVATE functions. (kind_priv = 1 under
# `base` in Intake is a generated ValidateAs helper, not a boundary guard; the examples/exemplars
# programs do not compile by design, so they are not in the corpus.)
source /tmp/claude-0/env.sh
SCRATCH="${1:?usage: corpus.sh SCRATCH}"; HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"; EX="$REPO/compiler/examples"
cat > "$SCRATCH/count.escript" <<'EOS'
#!/usr/bin/env escript
%% count.escript FILE.abstr -> "tag_pub tag_priv kind_pub kind_priv"
main([F]) ->
    {ok, Forms} = file:consult(F),
    Exp = lists:append([E || {attribute, _, export, E} <- Forms]),
    Count = fun(Node, Pred) -> walk(Node, Pred) end,
    R = lists:foldl(fun({function, _, N, A, Cs}, {TP, TV, KP, KV}) ->
            Pub = lists:member({N, A}, Exp),
            Gs = [G || {clause, _, _, G, _} <- Cs],
            T = Count(Gs, fun tag/1), K = Count(Gs, fun kind/1),
            case Pub of true -> {TP+T, TV, KP+K, KV}; false -> {TP, TV+T, KP, KV+K} end;
          (_, Acc) -> Acc end, {0,0,0,0}, Forms),
    {A1,B1,C1,D1} = R, io:format("~p ~p ~p ~p~n", [A1,B1,C1,D1]).
tag({op, _, '=:=', {call, _, {remote, _, {atom,_,erlang}, {atom,_,map_get}}, [{atom,_,'Kind'}|_]}, {atom,_,_}}) -> true;
tag({op, _, '=:=', {call, _, {atom,_,map_get}, [{atom,_,'Kind'}|_]}, {atom,_,_}}) -> true;
tag(_) -> false.
kind({call, _, {atom,_,is_integer}, _}) -> true;
kind({call, _, {atom,_,is_float}, _}) -> true;
kind({call, _, {remote,_,{atom,_,erlang},{atom,_,is_integer}}, _}) -> true;
kind({call, _, {remote,_,{atom,_,erlang},{atom,_,is_float}}, _}) -> true;
kind(_) -> false.
walk(T, P) when is_tuple(T) -> (case P(T) of true -> 1; false -> 0 end) + walk(tuple_to_list(T), P);
walk([H|T], P) -> walk(H, P) + walk(T, P);
walk(_, _) -> 0.
EOS
printf '%-34s %s\n' "module" "tag(pub,priv) kind(pub,priv)  per compiler: base | exported-only | guard-all | field-depth"
declare -A S
vars="base exported-only guard-all field-depth"
mods=$(cd "$EX" && find . -name '*.bs' -not -path './exemplars/*' | xargs -n1 dirname | sort -u | sed 's#^\./##')
for m in $mods; do
  line=""
  for v in $vars; do
    out="$SCRATCH/corpus/$v/$m"; mkdir -p "$out"
    "$SCRATCH/bsc.$v" --src-root "$EX" -o "$out" "$EX/$m" >/dev/null 2>&1
    ab=$(ls "$out"/*.abstr 2>/dev/null | head -1)
    if [ -z "$ab" ]; then c="(no build)"; else c=$(escript "$SCRATCH/count.escript" "$ab"); fi
    line="$line | $c"
    set -- $c; if [ "$#" = 4 ]; then for i in 1 2 3 4; do S[$v,$i]=$(( ${S[$v,$i]:-0} + ${!i} )); done; fi
  done
  printf '%-34s %s\n' "$m" "$line"
done
echo
echo "TOTALS over the corpus (tag_pub tag_priv kind_pub kind_priv):"
for v in $vars; do printf '  %-14s %s %s %s %s\n' "$v" "${S[$v,1]:-0}" "${S[$v,2]:-0}" "${S[$v,3]:-0}" "${S[$v,4]:-0}"; done
