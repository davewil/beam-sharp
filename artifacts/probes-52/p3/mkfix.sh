#!/bin/bash
# builds fixtures: dup module in two apps, orphan beam with no .app, beam not listed in .app, escript embedding a module
set -e
cd "$(dirname "$0")"; rm -rf libs es; mkdir -p libs/appa/ebin libs/appb/ebin libs/orphan/ebin libs/liar/ebin es
echo '-module(dup). -export([who/0]). who() -> ok.' > dup.erl
echo '-module(orph). -export([f/0]). f() -> ok.' > orph.erl
echo '-module(unlisted). -export([f/0]). f() -> ok.' > unlisted.erl
erlc -o libs/appa/ebin dup.erl; erlc -o libs/appb/ebin dup.erl
erlc -o libs/orphan/ebin orph.erl
erlc -o libs/liar/ebin unlisted.erl
echo '{application,appa,[{vsn,"1"},{modules,[dup]},{registered,[]},{applications,[kernel,stdlib]}]}.' > libs/appa/ebin/appa.app
echo '{application,appb,[{vsn,"2"},{modules,[dup]},{registered,[]},{applications,[kernel,stdlib]}]}.' > libs/appb/ebin/appb.app
echo '{application,liar,[{vsn,"1"},{modules,[]},{registered,[]},{applications,[kernel,stdlib]}]}.' > libs/liar/ebin/liar.app
# escript with embedded module
cat > es/emb.erl <<'EOE'
-module(emb). -export([f/0]). f() -> ok.
EOE
cat > es/main.erl <<'EOE'
-module(main). -export([main/1]).
main(_) ->
  io:format("embedded emb: which=~p~n", [code:which(emb)]),
  io:format("get_application(emb)=~p~n", [application:get_application(emb)]),
  io:format("lib_dir by name emb: ~p~n", [code:lib_dir(emb)]),
  io:format("code:get_path has escript entry: ~p~n", [[P || P <- code:get_path(), string:find(P,"emb.es") =/= nomatch]]),
  io:format("is_loaded: ~p ensure_loaded: ~p~n", [code:is_loaded(emb), code:ensure_loaded(emb)]),
  io:format("escript:script_name ~p~n", [escript:script_name()]).
EOE
erlc -o es es/emb.erl es/main.erl
cat > es/mk.escript <<'EOE'
#!/usr/bin/env escript
main([Out]) ->
  {ok,{_,Z}} = zip:create("mem", [{"emb.beam", element(2,file:read_file("es/emb.beam"))},{"main.beam", element(2,file:read_file("es/main.beam"))}], [memory]),
  ok = escript:create(Out, [shebang, {emu_args,"-escript main main"}, {archive, Z}]).
EOE
escript es/mk.escript es/emb.es
# p3d: two roots each holding one app that contains `dup` (self-building; previously hand-made)
rm -rf rootA rootB; mkdir -p rootA/appa/ebin rootB/appb/ebin
erlc -o rootA/appa/ebin dup.erl; erlc -o rootB/appb/ebin dup.erl
cp libs/appa/ebin/appa.app rootA/appa/ebin/; cp libs/appb/ebin/appb.app rootB/appb/ebin/
# p3e: dir name != app name
rm -rf renamed; mkdir -p renamed/dirname/ebin
echo '{application,realname,[{description,"d"},{vsn,"1"},{modules,[]},{registered,[]},{applications,[kernel,stdlib]}]}.' > renamed/dirname/ebin/realname.app
