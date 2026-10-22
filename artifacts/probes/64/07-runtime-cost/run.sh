#!/usr/bin/env bash
# Probe 07 -- what a tagged success costs on the BEAM, measured on code bsc actually emits.
# GetBare = option<int> (untagged, today's shape); GetTagged = (:some, int) | :nothing (a user-land alias
# that compiles TODAY, so Options 1 and 3 are not hypothetical at the type level).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../lib/env.sh"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cp -r "$HERE/Cost" "$W/Cost"
"$BSC" -o "$W/out" "$W/Cost" </dev/null 2>&1 | head -5
echo "--- bsc --api"; "$BSC" --api "$W/Cost" </dev/null
echo "--- bytes: Cost.beam=$(stat -c %s "$W/out/Cost.beam")  Cost.abstr=$(stat -c %s "$W/out/Cost.abstr")"
echo "--- emitted Erlang for the two lookups (erl_pp of the abstract code chunk):"
erl -noshell -eval '
{ok,{_,[{abstract_code,{_,F}}]}} = beam_lib:chunks(hd(filelib:wildcard("'"$W"'/out/Cost.beam")),[abstract_code]),
[io:format("~s~n",[erl_pp:form(X)]) || X <- F, element(1,X)==function, element(3,X) =:= '"'"'GetTagged'"'"'],
halt().' | tail -12
echo "--- heap words: erts_debug:flat_size of what each lookup returns on a hit (7), a binary hit, a miss"
erl -noshell -eval '
P = fun(L,T) -> io:format("~-34s flat_size=~p~n",[L, erts_debug:flat_size(T)]) end,
P("bare   7", 7), P("tagged {some,7}", {some,7}),
Bin = binary:copy(<<"x">>, 100), P("bare   100-byte binary", Bin), P("tagged {some,<<100 bytes>>}", {some,Bin}),
P("bare   :nothing (miss)", nothing), P("tagged :nothing (miss)", nothing),
halt().'
echo "--- 5,000,000 hit lookups, best of 5 (timer:tc, microseconds)"
erl -noshell -pa "$W/out" -eval '
M = #{<<"k">> => 7}, N = 5000000,
Best = fun(F) -> lists:min([element(1, timer:tc(fun() -> F() end)) || _ <- lists:seq(1,5)]) end,
Bare = Best(fun() -> '"'"'Cost'"'"':'"'"'LoopBare'"'"'(M, N, 0) end),
Tag  = Best(fun() -> '"'"'Cost'"'"':'"'"'LoopTagged'"'"'(M, N, 0) end),
io:format("LoopBare   ~p us   result ~p~n", [Bare, '"'"'Cost'"'"':'"'"'LoopBare'"'"'(M,10,0)]),
io:format("LoopTagged ~p us   result ~p~n", [Tag, '"'"'Cost'"'"':'"'"'LoopTagged'"'"'(M,10,0)]),
io:format("tagged/bare = ~.2f~n", [Tag/Bare]),
halt().'
