#!/usr/bin/env bash
# P5: what do the neighbours do when code names a module/app that is not there?
set -u; . "$(dirname "$0")/common.sh"
cd $WORK
echo "=== Elixir 1.14: elixirc on a call to an absent module"
cat > a.ex <<'EOF'
defmodule A do
  def f, do: Req.new(url: "x")
end
EOF
elixirc a.ex 2>&1 | head -8; echo "(elixirc exit=${PIPESTATUS[0]})"

echo; echo "=== Elixir 1.14: mix, a module of an app the project does not depend on (Logger without :logger in extra_applications)"
mkdir -p mixp/lib && cd mixp
cat > mix.exs <<'EOF'
defmodule P.MixProject do
  use Mix.Project
  def project, do: [app: :p, version: "0.1.0", deps: []]
  def application, do: [extra_applications: []]
end
EOF
cat > lib/p.ex <<'EOF'
defmodule P do
  require Logger
  def f, do: Logger.info("x")
end
EOF
MIX_ENV=dev HEX_OFFLINE=1 mix compile 2>&1 | grep -v "^Compiling\|^Generated" | head -8
cd ..

echo; echo "=== Erlang: erlc, absent module (no check) then xref (the check lives in a separate tool)"
cat > b.erl <<'EOF'
-module(b).
-export([f/0]).
f() -> nosuch:call(1).
EOF
erlc +debug_info b.erl 2>&1; echo "(erlc exit=$? -> compiled without complaint)"
erl -noshell -eval '
  {ok,_}=xref:start(s), xref:set_default(s,[{warnings,false}]), {ok,_}=xref:add_module(s,"b.beam"),
  io:format("xref undefined_function_calls = ~p~n",[xref:analyze(s,undefined_function_calls)]), halt().'

echo; echo "=== Erlang release: .app \`applications\` is enforced by systools, not by the compiler"
mkdir -p rel && cd rel
cat > r.rel <<'EOF'
{release,{"r","1"},{erts,"13.2"},[{kernel,"8.5"},{stdlib,"4.3"},{fakereq,"1.2.3"}]}.
EOF
erl -noshell -eval 'R=systools:make_script("r",[silent,{path,["'$PWD'"]}]), io:format("~p~n",[R]), halt().' 2>&1 | grep -m1 "fakereq"
