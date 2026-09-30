#!/usr/bin/env bash
# p08: Erlang (OTP 25).  (1) does erlc check a remote call's module?  (2) -include_lib names an APPLICATION in
# source and erlc resolves it through the code path: what happens when the app is absent / present?
cd "$(dirname "$0")/neighbours/erl"; O=$(mktemp -d)
echo '--- 1. remote call to a module that is nowhere (erlc)'
env -u ERL_LIBS erlc +debug_info -o $O calls_missing.erl; echo "exit=$?"
echo '--- 1b. same, through xref (the BEAM tool that does check)'
env -u ERL_LIBS erl -noshell -eval '
  {ok,_}=xref:start(s), xref:set_default(s,[{warnings,false}]),
  {ok,_}=xref:add_module(s, "'$O'/calls_missing.beam"),
  io:format("undefined_function_calls: ~p~n", [xref:analyze(s, undefined_function_calls)]), halt().'
echo '--- 2. -include_lib("libdep/...") with application libdep absent'
env -u ERL_LIBS erlc -o $O inc_missing_app.erl; echo "exit=$?"
echo '--- 3. -include_lib("stdlib/...") present'
env -u ERL_LIBS erlc -o $O inc_present_app.erl; echo "exit=$?"
