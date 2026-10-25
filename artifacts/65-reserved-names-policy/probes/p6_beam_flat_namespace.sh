#!/usr/bin/env bash
# P6: BEAM-level truth. A user module whose atom equals a stdlib module (lists / maps), vs a PascalCase atom ('Map').
export PATH=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/beam/bin:$PATH LANG=C.UTF-8
D=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/65/p6; rm -rf $D; mkdir -p $D/w; cd $D/w
cat > lists.erl <<'X'
-module(lists).
-export([map/2, mine/0]).
map(_F, _L) -> mine_not_otps.
mine() -> ok.
X
cat > 'Map.erl' <<'X'
-module('Map').
-export([size/1]).
size(_) -> user_map_size.
X
cat > run.erl <<'X'
-module(run).
-export([go/0]).
go() -> lists:map(fun(X) -> X end, [1]).
X
echo "=== A: erlc lists.erl (module named like stdlib)"; erlc lists.erl; echo "exit=$?"
echo "=== B: erlc -o with sticky stdlib: code:which, then load from cwd (-pa .) and call lists:map and lists:foldl (a stdlib fn the user module lacks)"
erlc 'Map.erl' run.erl
erl -noshell -pa . -eval 'io:format("which(lists)=~p~nsticky=~p~n",[code:which(lists), code:is_sticky(lists)]),
  R=(catch lists:map(fun(X)->X end,[1])), io:format("lists:map -> ~p~n",[R]),
  io:format("lists:foldl -> ~p~n",[catch lists:foldl(fun(X,A)->X+A end,0,[1,2])]),
  io:format("code:load_file(lists) -> ~p~n",[code:load_file(lists)]),
  io:format("which(Map)=~p; Map:size -> ~p; maps:size(#{a=>1}) -> ~p~n",[code:which(Map), Map:size(x), maps:size(#{a=>1})]),halt().'
echo "=== C: same but erl started with -pa FIRST making the user lists.beam shadow in the path (path order; stdlib sticky dirs)"
erl -noshell -pa . -eval 'io:format("which(lists)=~p~n",[code:which(lists)]), halt().'
echo "=== D: embedded mode (init -mode embedded) loads boot-script modules only; user dir via -pa"
erl -noshell -mode embedded -pa . -eval 'io:format("embedded lists:map -> ~p~n",[catch lists:map(fun(X)->X end,[1])]),halt().' 2>&1 | head -5
