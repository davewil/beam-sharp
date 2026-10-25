#!/usr/bin/env bash
# P6b: control for P6 (which crashed at boot because lists.beam was on the path). A PascalCase atom 'Map' beside stdlib `maps`: no collision.
export PATH=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/beam/bin:$PATH LANG=C.UTF-8
D=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/65/p6b; rm -rf $D; mkdir -p $D; cd $D
cat > 'Map.erl' <<'X'
-module('Map').
-export([size/1]).
size(_) -> user_map_size.
X
erlc 'Map.erl'
erl -noshell -pa . -eval 'io:format("which(Map)=~p~nMap:size -> ~p~nmaps:size -> ~p~nlists:map -> ~p~n",[code:which(list_to_atom("Map")), (list_to_atom("Map")):size(x), maps:size(#{a=>1}), lists:map(fun(X)->X end,[1])]),halt().'
echo "--- what the real B# programs of P3 (opt3 build) load: App.beam imports"; 
