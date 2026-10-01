#!/usr/bin/env bash
# Ticket 52, "what does the compiler DO with it?": cost and information content of an application-presence
# check at compile time. Builds a fake ERL_LIBS holding app `req` 0.7.3 with module 'Elixir.Req', then times
# the three lookups a compiler could make, present and absent, and prints what each returns.
set -u
W=$(mktemp -d); cd "$W"
mkdir -p libs/req-0.7.3/ebin
cat > 'Elixir.Req.erl' <<'EOF'
-module('Elixir.Req').
-export([new/1]).
new(O) -> O.
EOF
erlc -o libs/req-0.7.3/ebin 'Elixir.Req.erl'
cat > libs/req-0.7.3/ebin/req.app <<'EOF'
{application, req, [{vsn, "0.7.3"}, {modules, ['Elixir.Req']}, {applications, [kernel, stdlib]}]}.
EOF
cat > t.erl <<'EOF'
-module(t).
-export([run/0]).
bench(Label, F) ->
  N = 20000,
  Us = [begin {U,_} = timer:tc(fun() -> [F() || _ <- lists:seq(1,N)] end), U*1000/N end || _ <- lists:seq(1,5)],
  io:format("  ~-44s ~p ns/lookup (median of 5)~n", [Label, round(lists:nth(3, lists:sort(Us)))]).
run() ->
  io:format("ERL_LIBS=~s~n", [os:getenv("ERL_LIBS")]),
  io:format("code:which(Elixir.Req)      = ~p~n", [code:which('Elixir.Req')]),
  io:format("code:lib_dir(req)           = ~p~n", [code:lib_dir(req)]),
  io:format("app file read               = ~p~n", [begin {ok,[{application,_,P}]} = file:consult(filename:join(code:lib_dir(req),"ebin/req.app")), proplists:get_value(vsn,P) end]),
  io:format("-- present --~n"),
  bench("code:which(Mod)", fun() -> code:which('Elixir.Req') end),
  bench("code:lib_dir(App)", fun() -> code:lib_dir(req) end),
  bench("code:ensure_loaded(Mod) (already loaded)", fun() -> code:ensure_loaded('Elixir.Req') end),
  io:format("-- absent --~n"),
  bench("code:which(Mod)", fun() -> code:which('Elixir.Nope') end),
  bench("code:lib_dir(App)", fun() -> code:lib_dir(nope) end),
  io:format("code:which(absent) = ~p, code:lib_dir(absent) = ~p~n", [code:which('Elixir.Nope'), code:lib_dir(nope)]).
EOF
erlc t.erl
echo "##### with ERL_LIBS"; ERL_LIBS=$W/libs erl -noshell -pa . -eval 't:run(), halt().'
echo "##### without ERL_LIBS"; erl -noshell -pa . -eval 'io:format("code:which=~p lib_dir=~p~n",[code:which('"'"'Elixir.Req'"'"'), code:lib_dir(req)]), halt().'
echo "##### module's app: which application OWNS a module? (needs a scan; no direct API)"
ERL_LIBS=$W/libs erl -noshell -pa . -eval 'io:format("code:which gives a PATH, app name must be parsed from it: ~s~n",[code:which('"'"'Elixir.Req'"'"')]), halt().'
