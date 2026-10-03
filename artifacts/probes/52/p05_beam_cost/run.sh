#!/bin/sh
# p05: byte cost of provenance in the emitted .beam, and whether it survives bsc's own path
# (.abstr text -> compile:file from_abstr). PROTOTYPE compiler for the attribute (proto/build.sh).
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8
HERE=$(cd "$(dirname "$0")" && pwd)
"$HERE/../proto/build.sh" /tmp/bs52_proto >/dev/null 2>&1 || { echo "proto build failed"; exit 1; }
B="$HERE/../proto/bsc52.sh"; EL=/tmp/otp/lib/elixir/lib
W=$(mktemp -d); cd "$W"
echo "#### A. attribute survives bsc's real path (.abstr -> compile:file from_abstr -> .beam)?"
for v in plain annotated; do
  mkdir -p $v/Probe; cp "$HERE/src/$v.bs" $v/Probe/probe.bs
  ( cd $v; BS52=attr ERL_LIBS=$EL "$B" Probe >/dev/null 2>&1; echo "-- $v: files: $(ls)"; echo "   .abstr bs_needs line: $(grep -h bs_needs Probe.abstr || echo '<none>')" )
done
cat > chunks.escript <<'X'
#!/usr/bin/env escript
main([F]) ->
    {ok,{M,[{attributes,A},{compile_info,CI}]}} = beam_lib:chunks(F,[attributes,compile_info]),
    io:format("   beam_lib attributes of ~p: ~p~n",[M,[X || X={K,_} <- A, K =/= vsn]]),
    {ok,{M,[{abstract_code,{_,AC}}]}} = beam_lib:chunks(F,[abstract_code]),
    io:format("   Dbgi abstract_code carries bs_needs: ~p~n",[[V || {attribute,_,bs_needs,V} <- AC]]),
    io:format("   module_info(attributes) at run time (module loaded): "),
    code:add_patha(filename:dirname(F)), M:module_info(), io:format("~p~n",[[X || X={bs_needs,_} <- M:module_info(attributes)]]),
    _ = CI, ok.
X
echo "-- annotated .beam read back with beam_lib (no VM load needed for the first two):"
escript chunks.escript annotated/Probe.beam
echo "-- plain .beam (no annotation, BS52=attr):"; escript chunks.escript plain/Probe.beam
echo; echo "#### B. what the same source costs in bytes (real .beam from bsc, debug_info as bsc builds it)"
for v in plain annotated; do ( cd $v; env -u BS52 ERL_LIBS=$EL "$B" Probe >/dev/null 2>&1; echo "baseline $v (no BS52): $(wc -c < Probe.beam) bytes"; rm -f Probe.beam; BS52=attr ERL_LIBS=$EL "$B" Probe >/dev/null 2>&1; echo "BS52=attr   $v: $(wc -c < Probe.beam) bytes" ); done
echo; echo "#### C. variants built from the SAME .abstr (compile:forms, debug_info; second figure without)"
escript "$HERE/sizes.escript" plain/Probe.abstr
echo; echo "#### D. on_load variant: failure text with lib missing (module load, not call site)"
cat > onload.escript <<'X'
#!/usr/bin/env escript
main([Abstr]) ->
    {ok,Forms}=file:consult(Abstr),
    [M0|Rest]=Forms, {attribute,_,module,Mod}=M0,
    F = {function,0,'bs@needs',0,[{clause,0,[],[],[{'case',0,{call,0,{remote,0,{atom,0,code},{atom,0,which}},[{atom,0,'Elixir.String'}]},
        [{clause,0,[{atom,0,non_existing}],[],[{call,0,{remote,0,{atom,0,erlang},{atom,0,error}},[{tuple,0,[{atom,0,bs_missing_dependency},{atom,0,elixir},{atom,0,'Elixir.String'}]}]}]},
         {clause,0,[{var,0,'_'}],[],[{atom,0,ok}]}]}]}]},
    {ok,Mod,Bin}=compile:forms([M0,{attribute,0,on_load,{'bs@needs',0}}|Rest]++[F],[debug_info]),
    io:format("load result: ~p~n",[code:load_binary(Mod,"x.beam",Bin)]),
    io:format("call result: ~p~n",[catch Mod:'Shout'(<<"hi">>)]).
X
env -u ERL_LIBS escript onload.escript plain/Probe.abstr 2>&1
