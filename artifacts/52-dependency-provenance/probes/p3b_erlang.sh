#!/usr/bin/env bash
# Probe (c), Erlang: what do erlc, xref, dialyzer, application and systools say about a missing dependency?
# Run: ./p3b_erlang.sh   (dialyzer PLT build is ~1-3 min)
H="$(cd "$(dirname "$0")" && pwd)"; FX="$H/fixtures/_fx"
[ -d "$FX/libA" ] || "$H/fixtures/build-fixtures.sh" >/dev/null
source /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh
export FX; export W="$FX/p3b"; rm -rf "$W"; mkdir -p "$W/ebin"
echo "== 0. TRAP: without +debug_info xref reads nothing and answers [] silently; shown at step 3b"
echo "== 1. erlc +warn_all on a call to a module that exists nowhere"
erlc +debug_info +warn_all -o "$W/ebin" "$H/erl/caller.erl"; echo "   erlc exit=$? (0 and silent = no complaint)"
echo; echo "== 2. is there an -application attribute? erlc on '-application(some_app).'"
erlc +debug_info +warn_all -o "$W/ebin" "$H/erl/wild.erl"; echo "   erlc exit=$?"
erl -noshell -eval 'io:format("   wild:module_info(attributes) = ~p~n",[begin code:add_patha(os:getenv("W")++"/ebin"), wild:module_info(attributes) end]),halt().'
echo; echo "== 3. xref: undefined_function_calls"
erl -noshell -eval '
  {ok,_}=xref:start(s), xref:set_default(s,[{warnings,false},{verbose,false}]),
  {ok,_}=xref:add_directory(s, os:getenv("W")++"/ebin"),
  {ok,R}=xref:analyze(s, undefined_function_calls),
  io:format("   undefined_function_calls = ~p~n",[R]),
  {ok,C}=xref:analyze(s, {module_call, caller}),
  io:format("   (control: xref did read caller) module_call caller = ~p~n",[C]),
  halt().'
echo "== 3b. TRAP/NEGATIVE CONTROL: same xref run on a beam compiled WITHOUT debug_info"
mkdir -p "$W/nodbg"; erlc -o "$W/nodbg" "$H/erl/caller.erl"
erl -noshell -eval '
  {ok,_}=xref:start(s2), xref:set_default(s2,[{warnings,false},{verbose,false}]),
  R0=xref:add_directory(s2, os:getenv("W")++"/nodbg"),
  io:format("   add_directory (no debug_info) = ~p~n",[R0]),
  {ok,R}=xref:analyze(s2, undefined_function_calls),
  io:format("   undefined_function_calls = ~p~n",[R]), halt().'
echo; echo "== 4. xref NEGATIVE CONTROL: same call resolved when the module exists (erldep, compiled with debug_info, added to the xref set)"
cat > "$W/ok.erl" <<'ERL'
-module(ok).
-export([go/1]).
go(X) -> erldep:double(X).
ERL
erlc +debug_info -o "$W/ebin" "$W/ok.erl"
mkdir -p "$W/dep"; erlc +debug_info -o "$W/dep" "$H/fixtures/erldep.erl"
erl -noshell -eval '
  {ok,_}=xref:start(s), xref:set_default(s,[{warnings,false},{verbose,false}]),
  {ok,_}=xref:add_directory(s, os:getenv("W")++"/ebin"),
  {ok,_}=xref:add_directory(s, os:getenv("W")++"/dep"),
  {ok,R}=xref:analyze(s, undefined_function_calls),
  io:format("   undefined_function_calls = ~p~n",[[X||{{M,_,_},_}=X<-R, M=:=ok]]),
  halt().' 
echo; echo "== 5. dialyzer: unknown function (PLT of erts+kernel+stdlib, then the one module)"
export HOME="$W/home"; mkdir -p "$HOME"
dialyzer --build_plt --output_plt "$W/p.plt" --apps erts kernel stdlib >/dev/null 2>&1; echo "   plt built exit=$?"
dialyzer --plt "$W/p.plt" "$W/ebin/caller.beam" 2>&1 | sed 's/^/   /'
echo; echo "== 6. application:ensure_all_started on an absent app"
erl -noshell -eval 'io:format("   ~p~n",[application:ensure_all_started(missing_dep_app)]),halt().'
echo; echo "== 7. systools:make_script for a release naming an app that is absent (what rebar3/relx ends in)"
mkdir -p "$W/rel"; cat > "$W/rel/r.rel" <<'REL'
{release,{"r","1"},{erts,"17.1"},[{kernel,"11.0.4"},{stdlib,"8.1"},{missing_dep_app,"1.0"}]}.
REL
( cd "$W/rel" && erl -noshell -eval 'io:format("   ~p~n",[systools:make_script("r",[silent])]),halt().' )
echo; echo "== 8. same, NEGATIVE CONTROL: only apps that exist"
cat > "$W/rel/r2.rel" <<'REL'
{release,{"r2","1"},{erts,"17.1"},[{kernel,"11.0.4"},{stdlib,"8.1"}]}.
REL
( cd "$W/rel" && erl -noshell -eval 'io:format("   ~p~n",[systools:make_script("r2",[silent])]),halt().' )
