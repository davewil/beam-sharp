#!/bin/sh
# PROBE 4 (iv) — what does a real .app say, and what does mix infer from mix.exs deps (offline; path deps only)?
# PREDICTIONS:
#  a) OTP .app files carry `applications` as NAMES ONLY (no versions) plus `vsn` of the app itself, and `modules`.
#  b) Elixir's elixir.app / logger.app likewise; elixir.app lists modules by the hundreds.
#  c) mix: a dep declared in mix.exs deps (with `path:`) is added to the generated .app `applications` AUTOMATICALLY
#     (inferred; no extra_applications needed); `only: :test` deps and `runtime: false` deps are NOT; `extra_applications: [:ssl]` adds ssl.
#     The version constraint (`~> 1.0`) lives in mix.exs / mix.lock only and does NOT appear in the .app.
cd "$(dirname "$0")"
echo "######## real .app: ssl (OTP)"; cat /usr/lib/erlang/lib/ssl-*/ebin/ssl.app | grep -v '^%' | sed -n '1,200p' | grep -n 'vsn\|applications\|{modules' -A3 | head -30
echo "######## inets applications key"; erl -noshell -eval '{ok,[{application,A,Kv}]}=file:consult(code:lib_dir(inets)++"/ebin/inets.app"), io:format("~p vsn=~p applications=~p optional=~p n_modules=~p~n",[A,proplists:get_value(vsn,Kv),proplists:get_value(applications,Kv),proplists:get_value(optional_applications,Kv),length(proplists:get_value(modules,Kv))]),halt().'
echo "######## Elixir apps"
ELXLIB=$(dirname $(dirname $(readlink -f /usr/bin/elixir)))/lib
for a in elixir logger; do erl -noshell -eval 'A=list_to_atom("'$a'"), {ok,[{application,A,Kv}]}=file:consult("'$ELXLIB'/'$a'/ebin/'$a'.app"), io:format("~p vsn=~p applications=~p optional=~p n_modules=~p~n",[A,proplists:get_value(vsn,Kv),proplists:get_value(applications,Kv),proplists:get_value(optional_applications,Kv),length(proplists:get_value(modules,Kv))]),halt().'; done
echo "######## mix inference, throwaway project (path deps, offline)"
W=work/p4; rm -rf $W; mkdir -p $W; cd $W
mklib() { mkdir -p $1/lib; printf 'defmodule %s do\n def hi, do: 1\nend\n' $2 > $1/lib/x.ex
 printf 'defmodule %s.MixProject do\n use Mix.Project\n def project, do: [app: :%s, version: "%s", deps: []]\n def application, do: []\nend\n' $2 $1 $3 > $1/mix.exs; }
mklib dep_run   DepRun   1.2.3
mklib dep_test  DepTest  1.0.0
mklib dep_norun DepNorun 1.0.0
mkdir -p proj/lib; echo 'defmodule Proj do def x, do: DepRun.hi() end' > proj/lib/proj.ex
cat > proj/mix.exs <<'EOS'
defmodule Proj.MixProject do
  use Mix.Project
  def project, do: [app: :proj, version: "0.1.0", deps: deps()]
  def application, do: [extra_applications: [:ssl]]
  defp deps, do: [
    {:dep_run, "~> 1.2", path: "../dep_run"},
    {:dep_test, path: "../dep_test", only: :test},
    {:dep_norun, path: "../dep_norun", runtime: false}
  ]
end
EOS
cd proj; export MIX_HOME=$PWD/../mixhome HEX_OFFLINE=1
mix compile 2>&1 | tail -5
echo "-- generated proj.app"; cat _build/dev/lib/proj/ebin/proj.app
echo "-- the requirement \"~> 1.2\" is in mix.exs only; does the .app contain it?"; grep -c '1\.2' _build/dev/lib/proj/ebin/proj.app || true
echo "-- mix deps (requirement is checked by mix at deps.loadpaths against the dep's own version)"; mix deps 2>&1 | head -12
echo "-- runtime_dependencies key in ssl.app (OTP's own versioned constraint list)"; sed -n '/runtime_dependencies/,/\]}/p' /usr/lib/erlang/lib/ssl-*/ebin/ssl.app
echo "-- violate the requirement: dep_run 1.2.3 -> 0.9.0, recompile"; sed -i 's/1\.2\.3/0.9.0/' ../dep_run/mix.exs; mix compile 2>&1 | head -8
