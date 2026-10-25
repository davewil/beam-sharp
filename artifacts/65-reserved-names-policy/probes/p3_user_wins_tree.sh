#!/usr/bin/env bash
# P3 (v2): tree = user `module Map` (own Size), Lib (transitive dep calling std Map.Size, NO `using Map`),
# App (`using Map` + `using Lib`), AppB (`using Map`, then wants the STANDARD Map.FromList: the shadow's cost).
# Run on HEAD bsc (option 1, today) and on bsc-opt3 (PROTOTYPE patch, probes/opt3-patch/*.diff: user names win).
# v1 (p3_user_wins_tree.v1.sh) put the FromList call inside App and so could not show the Go result; kept.
S=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad
for V in bsc bsc-opt3; do
  D=$S/65/p3-$V; rm -rf $D; mkdir -p $D/src/Map $D/src/Lib $D/src/App $D/src/AppB $D/out
  printf 'module Map\n\npublic int Size(int n)\nSize(n) -> n + 1000\n' > $D/src/Map/Map.bs
  printf 'module Lib\n\npublic int Count(map<atom, int> m)\nCount(m) -> Map.Size(m)\n' > $D/src/Lib/Lib.bs
  printf 'module App\n\nusing Map\nusing Lib\n\npublic int Go(int n)\nGo(n) -> Map.Size(n)\n\npublic int Via(map<atom, int> m)\nVia(m) -> Count(m)\n' > $D/src/App/App.bs
  printf 'module AppB\n\nusing Map\n\npublic int Go(int n)\nGo(n) -> Map.Size(Map.FromList([(:a, n)]))\n' > $D/src/AppB/AppB.bs
  echo "######## $V: App.Go 5  (user Map.Size(5): 1005 if the user wins)"
  $S/$V --src-root $D/src $D/src/App Go 5 2>&1 | sed "s#$S/65/##" | head -8
  echo "######## $V: App.Via #{a=>1}  (calls Lib.Count, whose Map.Size is std: 1 if the dependency is unaffected)"
  $S/$V --src-root $D/src $D/src/App Via '#{a => 1}' 2>&1 | sed "s#$S/65/##" | head -8
  echo "######## $V: AppB.Go 5  (using Map, then std Map.FromList: the shadow's cost)"
  $S/$V --src-root $D/src $D/src/AppB Go 5 2>&1 | sed "s#$S/65/##" | head -8
  echo "######## $V: does Lib's beam still import maps (std row) and no capitalised module?"
  rm -rf $D/out; mkdir $D/out; $S/$V --src-root $D/src -o $D/out $D/src/App >/dev/null 2>&1; ls $D/out
  erl -noshell -eval '[begin {ok,{_,[{imports,I}]}}=beam_lib:chunks(F,[imports]), io:format("~s imports ~p~n",[filename:basename(F),lists:usort([M||{M,_,_}<-I])]) end || F<-filelib:wildcard(hd(init:get_plain_arguments())++"/*.beam")], halt().' -extra $D/out
done
