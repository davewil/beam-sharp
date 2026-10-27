#!/bin/bash
# H1 rebar3: the `applications` list in <app>.app.src is copied verbatim into ebin/<app>.app, and nothing else
#    (no version) records a dependency; a call into a module of an app NOT listed compiles silently.
# H2 mix: `deps` in mix.exs become `applications` in the generated .app (with extra_applications), WITHOUT versions.
# H3 xref reports an undefined remote call (the answer to "does the existing toolchain already say this?").
# H4 mix compile of Elixir code calling an absent module warns at compile time.
W=$(mktemp -d); cd $W
echo "### rebar3 $(rebar3 version 2>&1 | head -1)"
mkdir -p rb/src && cd rb
cat > rebar.config <<'EOF'
{erl_opts, [debug_info]}.
{deps, []}.
{xref_checks,[undefined_function_calls]}.
EOF
cat > src/rb.app.src <<'EOF'
{application, rb, [{description,"rb"},{vsn,"0.1.0"},{registered,[]},{applications,[kernel,stdlib]},{env,[]}]}.
EOF
cat > src/rb.erl <<'EOF'
-module(rb).
-export([go/0]).
go() -> 'Elixir.Req':new([]).
EOF
echo "--- rebar3 compile (expect no warning about Elixir.Req):"; rebar3 compile 2>&1 | grep -v '^===> \(Verifying\|Analyzing\|Compiling\)' ; echo "--- ebin/rb.app:"; cat _build/default/lib/rb/ebin/rb.app
echo "--- rebar3 xref:"; rebar3 xref 2>&1 | grep -v 'Verifying\|Analyzing\|Compiling'
cd ..
echo; echo "### mix $(mix --version | tail -1)"
mkdir -p dep1/lib && cat > dep1/mix.exs <<'EOF'
defmodule Dep1.MixProject do
  use Mix.Project
  def project, do: [app: :dep1, version: "1.2.3", deps: []]
  def application, do: [extra_applications: []]
end
EOF
echo 'defmodule Dep1 do def hi, do: :hi end' > dep1/lib/dep1.ex
mkdir -p mx/lib && cat > mx/mix.exs <<'EOF'
defmodule Mx.MixProject do
  use Mix.Project
  def project, do: [app: :mx, version: "0.1.0", deps: [{:dep1, path: "../dep1", override: true}]]
  def application, do: [extra_applications: [:logger, :eex]]
end
EOF
cat > mx/lib/mx.ex <<'EOF'
defmodule Mx do
  def go, do: Absent.Thing.run(1)
  def ok, do: Dep1.hi()
end
EOF
cd mx; echo "--- mix compile:"; MIX_ENV=dev mix compile 2>&1 | grep -v '^$'; echo "--- _build mx.app:"; cat _build/dev/lib/mx/ebin/mx.app
cd ..
echo; echo "### xref API directly (OTP $(erl -noshell -eval 'io:format("~s",[erlang:system_info(otp_release)]),halt().'))"
cat > x.escript <<'EOF'
#!/usr/bin/env escript
main(_) ->
  {ok,_}=xref:start(s), xref:set_default(s,[{warnings,false}]),
  {ok,_}=xref:add_directory(s,"rb/_build/default/lib/rb/ebin"),
  {ok,U}=xref:analyze(s,undefined_function_calls), io:format("undefined_function_calls: ~p~n",[U]),
  case U of [{{rb,go,0},{'Elixir.Req',new,1}}] -> io:format("H3 HOLDS~n"); _ -> io:format("H3 FALSIFIED~n") end.
EOF
escript x.escript
