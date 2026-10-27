#!/bin/bash
# What can a compiler do at compile time to check "application fakereq provides module 'Elixir.Req'"?
# Hypotheses (each can fail; assertions print FAIL):
#  H1 code:which/1 finds a module on ERL_LIBS without loading it, and its path names the application dir.
#  H2 code:lib_dir(App) finds the application dir; {error,bad_name} when absent.
#  H3 application:load/1 + get_key(App, applications) reads declared deps from the .app without starting it.
#  H4 code:which on an ABSENT module returns non_existing.
#  H5 each check costs < 1 ms warm (measured, not assumed).
#  H6 a WRONG app claim (module exists but under a different app) is detectable via the path.
W=$(mktemp -d)
mkdir -p $W/libs/fakereq-0.7.3/ebin $W/libs/otherapp-1.0.0/ebin; cd $W
cat > 'Elixir.Req.erl' <<'EOF'
-module('Elixir.Req').
-export([new/1]).
new(X) -> X.
EOF
cat > 'Elixir.Other.erl' <<'EOF'
-module('Elixir.Other').
-export([f/0]).
f() -> ok.
EOF
erlc -o libs/fakereq-0.7.3/ebin 'Elixir.Req.erl'; erlc -o libs/otherapp-1.0.0/ebin 'Elixir.Other.erl'
cat > libs/fakereq-0.7.3/ebin/fakereq.app <<'EOF'
{application, fakereq, [{description,"x"},{vsn,"0.7.3"},{modules,['Elixir.Req']},{registered,[]},
  {applications,[kernel,stdlib,eex]}]}.
EOF
cat > libs/otherapp-1.0.0/ebin/otherapp.app <<'EOF'
{application, otherapp, [{description,"y"},{vsn,"1.0.0"},{modules,['Elixir.Other']},{registered,[]},{applications,[kernel]}]}.
EOF
cat > p.escript <<'EOF'
#!/usr/bin/env escript
chk(Name, true)  -> io:format("  ok   ~s~n",[Name]);
chk(Name, false) -> io:format("  FAIL ~s~n",[Name]).
time(Name, N, F) ->
  F(), {T,_} = timer:tc(fun() -> [F() || _ <- lists:seq(1,N)] end),
  io:format("  ~-44s ~8.2f us/call (N=~p, warm)~n",[Name, T/N, N]).
main(_) ->
  io:format("OTP ~s, code path entries: ~p~n",[erlang:system_info(otp_release), length(code:get_path())]),
  P = code:which('Elixir.Req'),
  io:format("code:which('Elixir.Req') = ~s~n",[P]),
  chk("H1 which finds it, not loaded", is_list(P) andalso code:is_loaded('Elixir.Req') =:= false),
  chk("H1 path names app dir", filename:basename(filename:dirname(filename:dirname(P))) =:= "fakereq-0.7.3"),
  io:format("code:lib_dir(fakereq) = ~p~n",[code:lib_dir(fakereq)]),
  chk("H2 lib_dir present", is_list(code:lib_dir(fakereq))),
  chk("H2 lib_dir absent -> bad_name", code:lib_dir(nope) =:= {error,bad_name}),
  chk("H4 which absent -> non_existing", code:which('Elixir.Absent') =:= non_existing),
  {ok,[{application,fakereq,Props}]} = {ok,element(2,file:consult(filename:join([code:lib_dir(fakereq),"ebin","fakereq.app"])))},
  io:format("consult .app applications = ~p~n",[proplists:get_value(applications,Props)]),
  chk("H3 consult sees deps incl. eex", lists:member(eex, proplists:get_value(applications,Props))),
  R = application:load(fakereq),
  io:format("application:load(fakereq) = ~p ; get_key = ~p~n",[R, application:get_key(fakereq, applications)]),
  chk("H3 load ok, not started", R =:= ok andalso lists:keymember(fakereq,1,application:which_applications()) =:= false),
  chk("H3 get_key applications", application:get_key(fakereq, applications) =:= {ok,[kernel,stdlib,eex]}),
  %% H6: module exists, claim says wrong app
  P2 = code:which('Elixir.Other'),
  AppOf = fun(Pth) -> D = filename:basename(filename:dirname(filename:dirname(Pth))), hd(string:split(D,"-")) end,
  chk("H6 claim app=fakereq for Elixir.Req ok", AppOf(P) =:= "fakereq"),
  chk("H6 claim app=fakereq for Elixir.Other REFUSED (found under otherapp)", AppOf(P2) =/= "fakereq"),
  io:format("cost:~n"),
  time("code:which present", 2000, fun() -> code:which('Elixir.Req') end),
  time("code:which absent (scans whole path)", 2000, fun() -> code:which('Elixir.Absent') end),
  time("code:lib_dir/1", 2000, fun() -> code:lib_dir(fakereq) end),
  time("file:consult of .app", 2000, fun() -> file:consult(filename:join([code:lib_dir(fakereq),"ebin","fakereq.app"])) end),
  time("application:get_key (already loaded)", 2000, fun() -> application:get_key(fakereq, applications) end),
  {TC,_} = timer:tc(fun() -> application:unload(fakereq), application:load(fakereq) end),
  io:format("  application:unload+load (one cold-ish)       ~8.2f us~n",[float(TC)]),
  {T0,_} = timer:tc(fun() -> code:which('Elixir.Req') end), io:format("  first code:which (this process)             ~8.2f us~n",[float(T0)]),
  ok.
EOF
ERL_LIBS=$W/libs escript p.escript
