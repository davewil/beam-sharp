#!/usr/bin/env bash
# Probe 64/08 - how Erlang and Elixir handle "absent" vs "present but the default-looking value".
# Cites the installed sources by grep -n, then RUNS the behaviour. Needs only env.sh.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ERL=/nix/store/qlclzl3234h2jwjpvy2gs72vzq2g6wkw-erlang-28.5.0.7/lib/erlang/lib/stdlib-7.3.0.3/src
EX=/nix/store/pp8kbll8n2778kdm3b3bihjj3nnrrvh3-elixir-1.18.5/lib/elixir/lib/elixir/lib
echo "=== SOURCES (grep -n against the installed trees) ==="
echo "-- maps.erl: find is tagged, get/3 is a default"
grep -n "^-spec find(Key, Map) -> {ok, Value} | error when\|^-spec get(Key, Map, Default) -> Value | Default when" $ERL/maps.erl
echo "-- proplists.erl: get_value/2 defaults to 'undefined'"
grep -n "equiv => get_value(Key, List, undefined)\|^    get_value(Key, List, undefined)\." $ERL/proplists.erl
echo "-- proplists.erl: the only tagged lookup is lookup/2 -> none | tuple"
grep -n "^-spec lookup(Key, List) ->" $ERL/proplists.erl
echo "-- lists.erl: keyfind -> Tuple | false"
grep -n "^-spec keyfind(Key, N, TupleList) -> Tuple | false when" $ERL/lists.erl
echo "-- Elixir map.ex"
grep -n "@spec fetch(map, key) :: {:ok, value} | :error\|def fetch(map, key), do: :maps.find(key, map)\|@spec get(map, key, value) :: value\|def get(map, key, default \\\\\\\\ nil) do\|@spec fetch!(map, key) :: value" $EX/map.ex
echo "-- Elixir keyword.ex"
grep -n "@spec get(t, key, default) :: value | default\|@spec fetch(t, key) :: {:ok, value} | :error" $EX/keyword.ex
echo
echo "=== ERLANG RUN ==="
erl -noshell -eval '
io:format("proplists:get_value(a, [{a, undefined}])  = ~p~n", [proplists:get_value(a, [{a, undefined}])]),
io:format("proplists:get_value(a, [])               = ~p~n", [proplists:get_value(a, [])]),
io:format("proplists:lookup(a, [{a, undefined}])    = ~p~n", [proplists:lookup(a, [{a, undefined}])]),
io:format("proplists:lookup(a, [])                  = ~p~n", [proplists:lookup(a, [])]),
io:format("maps:find(a, #{a => undefined})          = ~p~n", [maps:find(a, #{a => undefined})]),
io:format("maps:find(a, #{})                        = ~p~n", [maps:find(a, #{})]),
io:format("maps:get(a, #{a => undefined}, undefined)= ~p~n", [maps:get(a, #{a => undefined}, undefined)]),
io:format("maps:get(a, #{}, undefined)              = ~p~n", [maps:get(a, #{}, undefined)]),
io:format("lists:keyfind(a,1,[{a,false}])           = ~p~n", [lists:keyfind(a,1,[{a,false}])]),
io:format("lists:keyfind(a,1,[])                    = ~p~n", [lists:keyfind(a,1,[])]),
halt().'
echo
echo "=== ELIXIR RUN ==="
elixir "$HERE/ambiguity.exs"
