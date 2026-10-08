#!/usr/bin/env bash
# P13: today, is bsc's OUTPUT a function of the source alone (independent of ERL_LIBS and of which apps are installed)?
# Stock compiler, same source, three environments -> compare md5 of .abstr and .beam (expect identical).
# Control (must DIFFER, else the probe is vacuous): a one-character source change.
# Then the prototype's *verdict* under the same two environments (expect it to differ: P8).
STOCK=/tmp/bsbuild/ebin; PROTO=/tmp/bsb_52_x/ebin
W=$(mktemp -d); cd "$W"; mkdir A B
SRC="module A\nusing :'Elixir.Enum' {\n    int count(list<term> xs)\n}\npublic int Go(list<term> xs)\nGo(xs) -> :'Elixir.Enum'.count(xs)\n"
printf "$SRC" > A/a.bs; printf "${SRC//Go(xs) -> :/Go(xs) -> 1 + :}" | sed 's/module A/module B/' > B/a.bs
c() { env ERL_LIBS="$2" erl -noshell -pa $1 -eval 'bsc:main(init:get_plain_arguments()), halt(0).' -extra -o "$3" "$4" >/dev/null 2>&1; }
c $STOCK ""                       o1 A/a.bs
c $STOCK /usr/lib/elixir/lib      o2 A/a.bs
c $STOCK /nonexistent:/also/none  o3 A/a.bs
c $STOCK ""                       o4 B/a.bs
# whole-file md5 of .beam differs across out dirs because CInf embeds the output path (SURPRISE, see P3: `source`);
# beam_lib:md5/1 hashes the code-bearing chunks only, which is the fair comparison.
bm() { erl -noshell -eval '{ok,{_,M}}=beam_lib:md5("'$1'"), io:format("~s",[binary:part(binary:encode_hex(M),0,12)]), halt().'; }
for o in o1 o2 o3; do echo "$o  abstr=$(md5sum $o/A.abstr | cut -c1-12)  beam(whole)=$(md5sum $o/A.beam | cut -c1-12)  beam(code chunks)=$(bm $o/A.beam)"; done
echo "CONTROL (changed source, expect different) o4 abstr=$(md5sum o4/B.abstr | cut -c1-12) beam(code chunks)=$(bm o4/B.beam)"
echo "--- prototype VERDICT, ERL_LIBS unset vs set, same source"
for L in "" /usr/lib/elixir/lib; do
  r=$(env ERL_LIBS=$L erl -noshell -pa $PROTO -eval 'bsc:main(init:get_plain_arguments()), halt(0).' -extra -o op A/a.bs 2>&1 | head -1)
  echo "ERL_LIBS='$L' -> ${r:-accepted}"
done
